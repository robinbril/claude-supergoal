#!/usr/bin/env python3
"""Scope map and preflight for /superaudit (stack-neutral).

Determines the diff range, groups changed files by directory, picks the test
targets that belong to them, and counts a handful of hard signals per file,
split between the changed hunks (``diff``) and the whole file (``file``). Plus a
preflight: which toolchains are present, so you know before reading in which
mode you run. Read-only; the script changes nothing.

Usage:
    python3 scope.py            # auto range (merge-base with the default branch)
    python3 scope.py main..HEAD # explicit range
    python3 scope.py --json     # machine-readable (fastcheck.sh uses this)

Optional project config: ``$SUPERAUDIT_ROOT/config.json`` (default
``.claude/superaudit/config.json``), see references/project-map-template.md.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import signal
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


def git(*args: str) -> str:
    out = subprocess.run(["git", *args], capture_output=True, text=True, check=False)
    return out.stdout.strip()


ROOT = Path(git("rev-parse", "--show-toplevel") or ".").resolve()
CONFIG_PATH = (
    ROOT / os.environ.get("SUPERAUDIT_ROOT", ".claude/superaudit") / "config.json"
)

TEXT_SUFFIXES = {
    ".py",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".vue",
    ".svelte",
    ".go",
    ".rs",
    ".rb",
    ".php",
    ".java",
    ".kt",
    ".swift",
    ".html",
    ".md",
    ".sh",
    ".toml",
    ".yml",
    ".yaml",
    ".css",
    ".sql",
}
CODE_SUFFIXES = {
    ".py",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".vue",
    ".svelte",
    ".go",
    ".rs",
    ".rb",
    ".php",
    ".java",
    ".kt",
    ".swift",
}

PY_SIGNALS: dict[str, re.Pattern[str]] = {
    "bare_except": re.compile(r"^\s*except\s*(Exception\s*)?:\s*(#.*)?$"),
    "print": re.compile(r"^\s*print\("),
    "todo_hack": re.compile(r"\b(TODO|FIXME|HACK|XXX)\b"),
    "float_geld": re.compile(r"\bfloat\(|FloatField\(|round\([^,)]*,\s*2\)"),
    "naive_now": re.compile(r"\bdatetime\.now\(\)|\bdate\.today\(\)"),
    "raw_sql": re.compile(r"\.raw\(|cursor\(\)|RawSQL\(|\.extra\("),
    "objects_all_iter": re.compile(r"\.objects\.all\(\)\s*:|for .* in .*\.objects\."),
    "suppress": re.compile(r"#\s*type:\s*ignore|#\s*noqa"),
    "atomic": re.compile(r"transaction\.atomic|select_for_update"),
    "mark_safe": re.compile(r"mark_safe\(|\|\s*safe\b"),
}
JS_SIGNALS: dict[str, re.Pattern[str]] = {
    "v_html": re.compile(r"v-html|innerHTML|dangerouslySetInnerHTML"),
    "storage": re.compile(r"localStorage|sessionStorage"),
    "as_any": re.compile(r"\bas any\b|: any\b"),
    "non_null": re.compile(r"\w!\.|\w!\)"),
    "lege_catch": re.compile(r"catch\s*(\([^)]*\))?\s*\{\s*\}"),
    "todo_hack": re.compile(r"\b(TODO|FIXME|HACK|XXX)\b"),
    "console": re.compile(r"console\.(log|debug)\("),
    "suppress": re.compile(r"eslint-disable|@ts-ignore|@ts-expect-error"),
}
GENERIC_SIGNALS: dict[str, re.Pattern[str]] = {
    "todo_hack": re.compile(r"\b(TODO|FIXME|HACK|XXX)\b"),
    "raw_sql": re.compile(
        r"(?i)\b(select|update|delete|insert)\b.*\+\s*\w|f\"\s*(SELECT|UPDATE|DELETE|INSERT)"
    ),
}
MIGRATION_RISK = re.compile(
    r"RemoveField|DeleteModel|AlterField|RenameField|RenameModel|RunPython|RunSQL|AddConstraint|"
    r"unique=True|null=False|DROP (COLUMN|TABLE)|ALTER COLUMN|SET NOT NULL|ADD CONSTRAINT|dropColumn|dropTable|"
    r"renameColumn|changeColumn"
)
MIGRATION_PATH = re.compile(
    r"(^|/)(migrations?|migrate|db/migrate|alembic/versions|prisma/migrations)/"
)


def load_config() -> dict:
    if CONFIG_PATH.is_file():
        try:
            return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"config.json invalid: {exc}", file=sys.stderr)
    return {}


def default_branch() -> str | None:
    head = git("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if head:
        return head
    for cand in ("origin/main", "origin/master", "main", "master"):
        if git("rev-parse", "--verify", "--quiet", cand):
            return cand
    return None


def resolve_range(explicit: str | None) -> tuple[str, str]:
    if explicit:
        return explicit, "explicitly given"
    base = default_branch()
    if base:
        mb = git("merge-base", base, "HEAD")
        if mb and mb != git("rev-parse", "HEAD"):
            return f"{mb}..HEAD", f"merge-base with {base}"
    return "HEAD~1..HEAD", "branch tip equals the default branch; last commit"


def changed_files(rng: str) -> list[str]:
    files = set(git("diff", "--name-only", rng).splitlines())
    files |= set(git("diff", "--name-only", "HEAD").splitlines())
    files |= set(git("ls-files", "--others", "--exclude-standard").splitlines())
    return sorted(f for f in files if f)


def added_lines(rng: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = defaultdict(list)
    for spec in ([rng], ["HEAD"]):
        current = None
        for line in git("diff", "-U0", "--no-color", *spec).splitlines():
            if line.startswith("+++ b/"):
                current = line[6:]
            elif line.startswith("+") and not line.startswith("+++") and current:
                out[current].append(line[1:])
    for f in git("ls-files", "--others", "--exclude-standard").splitlines():
        full = ROOT / f
        if full.is_file() and full.suffix in TEXT_SUFFIXES:
            out[f] = full.read_text(encoding="utf-8", errors="replace").splitlines()
    return out


def group_of(path: str, cfg: dict) -> str:
    """Group by app/directory: via config ``app_for`` or the first two path segments."""
    rule = cfg.get("app_for")
    if rule:
        m = re.match(rule["pattern"], path)
        if m:
            return rule["template"].format(*([m.group(0)] + list(m.groups())))
    parts = Path(path).parts
    return "/".join(parts[:2]) if len(parts) > 2 else (parts[0] if parts else path)


def test_modules_for(files: list[str], cfg: dict) -> list[str]:
    """Backend test targets: via config ``test_module_for`` or a heuristic."""
    mods: set[str] = set(cfg.get("always_test", []))
    rule = cfg.get("test_module_for")
    for f in files:
        if Path(f).suffix != ".py" or MIGRATION_PATH.search(f):
            continue
        if rule:
            m = re.match(rule["pattern"], f)
            if m:
                mod = rule["template"].format(*([m.group(0)] + list(m.groups())))
                # ``dotted``: paths to dotted module names (Django test runner).
                if rule.get("dotted"):
                    mod = mod.replace("/", ".")
                mods.add(mod)
            continue
        # Heuristic: pytest style -> the file's directory; tests_*.py next to the file.
        p = ROOT / f
        for cand in sorted(p.parent.glob("test*")):
            if cand.is_dir() or cand.suffix == ".py":
                mods.add(str(cand.relative_to(ROOT)))
    return sorted(mods)


def frontend_tests_for(files: list[str]) -> list[str]:
    tests: set[str] = set()
    for f in files:
        if Path(f).suffix not in {".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte"}:
            continue
        if re.search(r"\.(test|spec)\.[jt]sx?$", f):
            tests.add(f)
            continue
        p = ROOT / f
        stem = p.name.rsplit(".", 1)[0]
        for cand in list(p.parent.glob(f"{stem}.test.*")) + list(
            p.parent.glob(f"{stem}.spec.*")
        ):
            tests.add(str(cand.relative_to(ROOT)))
    return sorted(tests)


def signals_for(path: str) -> dict[str, re.Pattern[str]]:
    suffix = Path(path).suffix
    if suffix == ".py":
        return PY_SIGNALS
    if suffix in {".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte"}:
        return JS_SIGNALS
    if suffix in CODE_SUFFIXES:
        return GENERIC_SIGNALS
    return {}


def count_signals(
    lines: list[str], signals: dict[str, re.Pattern[str]]
) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for line in lines:
        for name, rx in signals.items():
            if rx.search(line):
                counts[name] += 1
    return dict(counts)


def scan_file(path: str, diff_lines: list[str]) -> dict[str, object]:
    full = ROOT / path
    if not full.is_file() or full.suffix not in TEXT_SUFFIXES:
        return {}
    text = full.read_text(encoding="utf-8", errors="replace")
    sig = signals_for(path)
    return {
        "lines": text.count("\n") + 1,
        "diff": count_signals(diff_lines, sig),
        "file": count_signals(text.splitlines(), sig),
    }


def migration_notes(files: list[str]) -> list[dict[str, object]]:
    notes = []
    for f in files:
        if not MIGRATION_PATH.search(f):
            continue
        full = ROOT / f
        text = (
            full.read_text(encoding="utf-8", errors="replace") if full.is_file() else ""
        )
        notes.append(
            {
                "file": f,
                "risk_operations": sorted(set(MIGRATION_RISK.findall(text)) - {""}),
            }
        )
    return notes


def preflight(cfg: dict) -> dict[str, object]:
    def ok(cmd: list[str]) -> bool:
        try:
            return subprocess.run(cmd, capture_output=True, check=False).returncode == 0
        except OSError:
            return False

    prefix = cfg.get("runner_prefix", "").split()
    container_ok = ok([*prefix, "true"]) if prefix else False
    return {
        "config": CONFIG_PATH.is_file(),
        "runner_prefix_works": container_ok if prefix else None,
        "python_django": ok([sys.executable, "-c", "import django"]),
        "python_pytest": ok([sys.executable, "-c", "import pytest"]),
        "node_modules": (ROOT / "node_modules").is_dir()
        or any(
            (d / "node_modules").is_dir()
            for d in ROOT.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        ),
        "ruff": shutil.which("ruff") is not None,
        "eslint": shutil.which("eslint") is not None
        or (ROOT / "node_modules" / ".bin" / "eslint").exists(),
        "docker": shutil.which("docker") is not None,
        "go": shutil.which("go") is not None,
        "cargo": shutil.which("cargo") is not None,
    }


def mode(pf: dict[str, object], files: list[str]) -> str:
    suffixes = {Path(f).suffix for f in files}
    missing = []
    if pf.get("runner_prefix_works") is False:
        missing.append(
            "runner_prefix from config.json does not work (container unreachable)"
        )
    if ".py" in suffixes and not (
        pf["python_django"] or pf["python_pytest"] or pf.get("runner_prefix_works")
    ):
        missing.append("no Python test toolchain: tests and migrations cannot be run")
    if (
        suffixes & {".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte"}
        and not pf["node_modules"]
    ):
        missing.append("no node_modules: typecheck and unit tests cannot be run")
    if ".go" in suffixes and not pf["go"]:
        missing.append("no go toolchain")
    if ".rs" in suffixes and not pf["cargo"]:
        missing.append("no cargo")
    return "full" if not missing else "degraded (" + "; ".join(missing) + ")"


def main() -> int:
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    as_json = "--json" in sys.argv
    cfg = load_config()
    rng, why = resolve_range(argv[0] if argv else None)
    files = changed_files(rng)
    diff = added_lines(rng)
    per_group: dict[str, list[str]] = defaultdict(list)
    for f in files:
        per_group[group_of(f, cfg)].append(f)
    pf = preflight(cfg)
    report = {
        "range": rng,
        "range_note": why,
        "shortstat": git("diff", "--shortstat", rng),
        "config": str(CONFIG_PATH.relative_to(ROOT)) if CONFIG_PATH.is_file() else None,
        "preflight": pf,
        "mode": mode(pf, files),
        "files": files,
        "per_group": dict(per_group),
        "test_targets": test_modules_for(files, cfg),
        "frontend_tests": frontend_tests_for(files),
        "migrations": migration_notes(files),
        "signals": {f: s for f in files if (s := scan_file(f, diff.get(f, [])))},
        "apps": sorted({group_of(f, cfg) for f in files}),
    }
    if as_json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0

    print(f"range      : {rng}  ({why})")
    print(f"shortstat  : {report['shortstat'] or '-'}")
    print(f"config     : {report['config'] or 'none (heuristic)'}")
    print(f"mode       : {report['mode']}")
    print(f"files      : {len(files)}")
    for group, fs in sorted(per_group.items()):
        print(f"  {group}")
        for f in fs:
            sig = report["signals"].get(f, {})
            in_diff, in_file = sig.get("diff", {}), sig.get("file", {})
            parts = []
            for k in sorted(set(in_diff) | set(in_file)):
                d, b = in_diff.get(k, 0), in_file.get(k, 0)
                if d:
                    parts.append(
                        f"{k}={d} IN DIFF" + (f" ({b} in file)" if b > d else "")
                    )
                elif b:
                    parts.append(f"{k}={b} existing")
            flags = ", ".join(parts)
            print(
                f"    {f}  [{sig.get('lines', '?')} lines]{'  ' + flags if flags else ''}"
            )
    if report["migrations"]:
        print("migrations :")
        for m in report["migrations"]:
            ops = ", ".join(m["risk_operations"]) or "no risk operations found"
            print(f"  {m['file']}: {ops}")
    print("test targets:", " ".join(report["test_targets"]) or "-")
    print("frontend   :", " ".join(report["frontend_tests"]) or "-")
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    raise SystemExit(main())
