#!/usr/bin/env python3
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
from collections import Counter


NAME = "local-dev-tools"
VERSION = "0.2.0"
DEFAULT_STATE = os.path.expanduser(
    "~/Library/Application Support/ai.opencode.desktop/opencode.global.dat"
)
SKIP_DIRS = {
    ".git",
    ".gradle",
    ".idea",
    ".next",
    ".swiftpm",
    ".venv",
    ".vscode",
    "__pycache__",
    "DerivedData",
    "Pods",
    "build",
    "dist",
    "node_modules",
    "out",
    "target",
}
MARKER_FILES = [
    "package.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "package-lock.json",
    "pyproject.toml",
    "requirements.txt",
    "Package.swift",
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts",
    "Cargo.toml",
    "go.mod",
    "Gemfile",
    "Podfile",
    "Makefile",
    "README.md",
]
LANG_EXTENSIONS = {
    ".swift": "Swift",
    ".kt": "Kotlin",
    ".kts": "Kotlin",
    ".java": "Java",
    ".js": "JavaScript",
    ".jsx": "JavaScript",
    ".mjs": "JavaScript",
    ".cjs": "JavaScript",
    ".ts": "TypeScript",
    ".tsx": "TypeScript",
    ".py": "Python",
    ".rb": "Ruby",
    ".go": "Go",
    ".rs": "Rust",
    ".c": "C/C++",
    ".cc": "C/C++",
    ".cpp": "C/C++",
    ".h": "C/C++",
    ".hpp": "C/C++",
    ".m": "Objective-C",
    ".mm": "Objective-C++",
    ".sh": "Shell",
    ".sql": "SQL",
}
DESTRUCTIVE_PATTERNS = [
    r"(^|\s)sudo(\s|$)",
    r"rm\s+(-[^\s]*[rf][^\s]*|-[^\s]*[fr][^\s]*)",
    r"git\s+reset\s+--hard",
    r"git\s+clean\s+.*-[^\s]*[fdx]",
    r"git\s+push\s+.*--force",
    r"diskutil\s+",
    r"\bdd\s+.*\bof=/dev/",
    r"\bmkfs(\.|\\s)",
    r"\breboot\b",
    r"\bshutdown\b",
    r"curl\b.*\|\s*(sh|bash|zsh)",
    r"wget\b.*\|\s*(sh|bash|zsh)",
]
FAILURE_SIGNALS = [
    ("traceback", re.compile(r"Traceback \(most recent call last\):", re.I)),
    ("js_stack", re.compile(r"\b(TypeError|ReferenceError|SyntaxError|RangeError):", re.I)),
    ("test_failure", re.compile(r"\b(fail(ed|ure)?|assertion|expected .* received|xctest|pytest)\b", re.I)),
    ("timeout", re.compile(r"\b(timeout|timed out)\b", re.I)),
    ("missing_dependency", re.compile(r"\b(module not found|cannot find module|no module named|command not found|not found:)\b", re.I)),
    ("permission_error", re.compile(r"\b(permission denied|operation not permitted|EACCES)\b", re.I)),
]


def log(message):
    print(f"[{NAME}] {message}", file=sys.stderr, flush=True)


def env_int(name, default):
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


MAX_OUTPUT = env_int("LOCAL_DEV_MAX_OUTPUT_CHARS", 24000)
DEFAULT_TIMEOUT = env_int("LOCAL_DEV_COMMAND_TIMEOUT", 120)
MAX_TIMEOUT = env_int("LOCAL_DEV_MAX_TIMEOUT", 600)
MAX_TREE_ENTRIES = env_int("LOCAL_DEV_MAX_TREE_ENTRIES", 400)


def state_path():
    return os.path.expanduser(os.environ.get("OPENCODE_DESKTOP_STATE", DEFAULT_STATE))


def read_state():
    try:
        text = pathlib.Path(state_path()).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    for line in text.splitlines():
        stripped = line.strip().rstrip(",")
        if not stripped.startswith('"server"'):
            continue
        try:
            outer = json.loads("{" + stripped + "}")
            return json.loads(outer.get("server", "{}"))
        except json.JSONDecodeError:
            return {}
    return {}


def normalize_roots(candidates):
    roots = []
    seen = set()
    for value in candidates:
        if not value:
            continue
        try:
            path = pathlib.Path(os.path.expanduser(str(value))).resolve()
        except OSError:
            continue
        if path.exists() and path.is_dir() and str(path) not in seen:
            seen.add(str(path))
            roots.append(path)
    return roots


def project_roots():
    explicit = os.environ.get("OPENCODE_DEV_ROOTS", "").strip()
    candidates = []
    if explicit and explicit.lower() != "auto":
        candidates.extend(explicit.split(os.pathsep))
    else:
        state = read_state()
        projects = state.get("projects", {})
        if isinstance(projects, dict):
            for group in projects.values():
                if not isinstance(group, list):
                    continue
                for item in group:
                    if isinstance(item, dict):
                        candidates.append(item.get("worktree") or item.get("directory") or item.get("path"))
                    elif isinstance(item, str):
                        candidates.append(item)
        last = state.get("lastProject", {})
        if isinstance(last, dict):
            candidates.extend(value for value in last.values() if isinstance(value, str))
        elif isinstance(last, str):
            candidates.append(last)
    return normalize_roots(candidates or [os.getcwd()])


def resolve_root(cwd=None):
    if cwd:
        path = pathlib.Path(os.path.expanduser(str(cwd))).resolve()
        if path.exists() and path.is_dir():
            return path
    roots = project_roots()
    return roots[0] if roots else pathlib.Path.cwd()


def run_list(command, cwd, timeout=30):
    try:
        proc = subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout or ""
    except FileNotFoundError as exc:
        return 127, f"missing command: {exc.filename}"
    except subprocess.TimeoutExpired as exc:
        return 124, (exc.stdout or "") + f"\ntimeout after {timeout}s"


def git_root(path):
    code, out = run_list(["git", "rev-parse", "--show-toplevel"], path, 10)
    if code == 0 and out.strip():
        return pathlib.Path(out.strip())
    return None


def truncate(text, limit=MAX_OUTPUT):
    if len(text) <= limit:
        return text
    return text[:limit] + "\n... truncated ..."


def marker_files(path):
    found = []
    for current, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_depth = pathlib.Path(current).relative_to(path).parts
        if len(rel_depth) > 3:
            dirs[:] = []
            continue
        for name in MARKER_FILES:
            if name in files:
                found.append(str((pathlib.Path(current) / name).relative_to(path)))
    return sorted(found)


def language_counts(path):
    counts = Counter()
    for current, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_depth = pathlib.Path(current).relative_to(path).parts
        if len(rel_depth) > 5:
            dirs[:] = []
            continue
        for name in files:
            language = LANG_EXTENSIONS.get(pathlib.Path(name).suffix.lower())
            if language:
                counts[language] += 1
    return counts


def likely_commands(markers):
    marker_set = set(pathlib.Path(item).name for item in markers)
    commands = []
    if "package.json" in marker_set:
        commands.extend(["npm test", "npm run lint", "npm run build"])
    if "pnpm-lock.yaml" in marker_set:
        commands.extend(["pnpm test", "pnpm run lint", "pnpm run build"])
    if "pyproject.toml" in marker_set or "requirements.txt" in marker_set:
        commands.extend(["python -m pytest", "pytest"])
    if "Package.swift" in marker_set:
        commands.extend(["swift test", "swift build"])
    if {"settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts"} & marker_set:
        commands.extend(["./gradlew test", "./gradlew build"])
    if "go.mod" in marker_set:
        commands.append("go test ./...")
    if "Cargo.toml" in marker_set:
        commands.append("cargo test")
    if "Makefile" in marker_set:
        commands.append("make test")
    deduped = []
    for command in commands:
        if command not in deduped:
            deduped.append(command)
    return deduped


def project_overview(args):
    path = resolve_root(args.get("cwd"))
    git = git_root(path)
    markers = marker_files(path)
    languages = language_counts(path)
    lines = [
        f"project_root: {path}",
        f"git_root: {git or 'none'}",
        f"opencode_desktop_state: {state_path()}",
        "",
        "marker_files:",
    ]
    lines.extend(f"- {item}" for item in markers[:80])
    if not markers:
        lines.append("- none")
    lines.extend(["", "languages:"])
    for language, count in languages.most_common():
        lines.append(f"- {language}: {count}")
    if not languages:
        lines.append("- none")
    lines.extend(["", "likely_commands:"])
    for command in likely_commands(markers):
        lines.append(f"- {command}")
    if not likely_commands(markers):
        lines.append("- none")
    return "\n".join(lines)


def git_status(args):
    path = resolve_root(args.get("cwd"))
    root = git_root(path) or path
    commands = [
        ("branch", ["git", "branch", "--show-current"]),
        ("status", ["git", "status", "--short"]),
        ("diff_stat", ["git", "diff", "--stat"]),
        ("staged_diff_stat", ["git", "diff", "--cached", "--stat"]),
        ("recent_commits", ["git", "log", "--oneline", "-5"]),
    ]
    chunks = [f"git_root: {root}"]
    for label, command in commands:
        code, out = run_list(command, root, 30)
        chunks.append("")
        chunks.append(f"{label} (exit={code}):")
        chunks.append(out.strip() or "none")
    return truncate("\n".join(chunks))


def command_is_blocked(command):
    normalized = command.strip()
    for pattern in DESTRUCTIVE_PATTERNS:
        if re.search(pattern, normalized, re.I):
            return pattern
    return None


def run_command(args):
    command = str(args.get("command", "")).strip()
    if not command:
        return "missing required argument: command", True
    blocked = command_is_blocked(command)
    if blocked:
        return f"blocked by local safety pattern: {blocked}\ncommand: {command}", True
    cwd = resolve_root(args.get("cwd"))
    timeout = min(max(1, int(args.get("timeout_seconds", DEFAULT_TIMEOUT))), MAX_TIMEOUT)
    try:
        proc = subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            shell=True,
            executable="/bin/zsh",
            check=False,
        )
        output = truncate(proc.stdout or "")
        return f"$ {command}\nexit={proc.returncode}\ncwd={cwd}\n\n{output}".rstrip(), proc.returncode != 0
    except subprocess.TimeoutExpired as exc:
        output = truncate(exc.stdout or "")
        return f"$ {command}\nexit=124\ncwd={cwd}\ntimeout={timeout}s\n\n{output}".rstrip(), True


def debug_command(args):
    text, is_error = run_command(args)
    signals = [label for label, pattern in FAILURE_SIGNALS if pattern.search(text)]
    prefix = "failure_signals: " + (", ".join(signals) if signals else "none")
    return prefix + "\n\n" + text, is_error


def file_tree(args):
    path = resolve_root(args.get("cwd"))
    max_depth = max(1, min(int(args.get("max_depth", 3)), 8))
    max_entries = max(1, min(int(args.get("max_entries", MAX_TREE_ENTRIES)), 2000))
    lines = [f"{path}/"]
    count = 0
    for current, dirs, files in os.walk(path):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        files = sorted(files)
        rel = pathlib.Path(current).relative_to(path)
        depth = len(rel.parts)
        if depth >= max_depth:
            dirs[:] = []
        indent = "  " * depth
        for dirname in dirs:
            if count >= max_entries:
                lines.append("... truncated ...")
                return "\n".join(lines)
            lines.append(f"{indent}- {dirname}/")
            count += 1
        for filename in files:
            if count >= max_entries:
                lines.append("... truncated ...")
                return "\n".join(lines)
            lines.append(f"{indent}- {filename}")
            count += 1
    return "\n".join(lines)


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return None


def dependency_summary(args):
    path = resolve_root(args.get("cwd"))
    markers = marker_files(path)
    lines = [f"project_root: {path}", "", "dependency_manifests:"]
    if not markers:
        lines.append("- none")
    for marker in markers:
        if pathlib.Path(marker).name not in MARKER_FILES:
            continue
        lines.append(f"- {marker}")
        full = path / marker
        if full.name == "package.json":
            data = read_json(full) or {}
            scripts = data.get("scripts", {})
            deps = list((data.get("dependencies") or {}).keys())[:30]
            dev_deps = list((data.get("devDependencies") or {}).keys())[:30]
            if scripts:
                lines.append("  scripts: " + ", ".join(sorted(scripts.keys())[:30]))
            if deps:
                lines.append("  dependencies: " + ", ".join(deps))
            if dev_deps:
                lines.append("  devDependencies: " + ", ".join(dev_deps))
        elif full.name in {"pyproject.toml", "requirements.txt", "Package.swift", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "Cargo.toml", "go.mod", "Gemfile", "Podfile"}:
            try:
                snippet = full.read_text(encoding="utf-8", errors="replace")[:1200].strip()
            except OSError:
                snippet = ""
            if snippet:
                lines.append("  snippet:")
                lines.extend("  " + line for line in snippet.splitlines()[:30])
    commands = likely_commands(markers)
    lines.extend(["", "likely_commands:"])
    lines.extend(f"- {command}" for command in commands)
    if not commands:
        lines.append("- none")
    return truncate("\n".join(lines))


def tool_result(text, is_error=False):
    return {"content": [{"type": "text", "text": text}], "isError": bool(is_error)}


TOOLS = [
    {
        "name": "project_overview",
        "description": "Summarize project root, git root, marker files, detected languages, and likely test/build commands.",
        "inputSchema": {"type": "object", "properties": {"cwd": {"type": "string"}}},
    },
    {
        "name": "git_status",
        "description": "Return branch/status, diff stats, staged diff stats, and recent commits.",
        "inputSchema": {"type": "object", "properties": {"cwd": {"type": "string"}}},
    },
    {
        "name": "run_command",
        "description": "Run a bounded shell command for local build/test/debug work. Blocks destructive commands.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {"type": "string"},
                "cwd": {"type": "string"},
                "timeout_seconds": {"type": "integer"},
            },
            "required": ["command"],
        },
    },
    {
        "name": "debug_command",
        "description": "Run a bounded command and tag common failure signals.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {"type": "string"},
                "cwd": {"type": "string"},
                "timeout_seconds": {"type": "integer"},
            },
            "required": ["command"],
        },
    },
    {
        "name": "file_tree",
        "description": "Return a shallow project tree while ignoring dependency/build/cache folders.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "cwd": {"type": "string"},
                "max_depth": {"type": "integer"},
                "max_entries": {"type": "integer"},
            },
        },
    },
    {
        "name": "dependency_summary",
        "description": "Summarize common build and dependency metadata.",
        "inputSchema": {"type": "object", "properties": {"cwd": {"type": "string"}}},
    },
    {
        "name": "dev_status",
        "description": "Legacy alias for project_overview.",
        "inputSchema": {"type": "object", "properties": {"cwd": {"type": "string"}}},
    },
]


def send(message):
    print(json.dumps(message, separators=(",", ":")), flush=True)


def handle(name, args):
    args = args or {}
    if name in {"project_overview", "dev_status"}:
        return tool_result(project_overview(args))
    if name == "git_status":
        return tool_result(git_status(args))
    if name == "run_command":
        text, is_error = run_command(args)
        return tool_result(text, is_error)
    if name == "debug_command":
        text, is_error = debug_command(args)
        return tool_result(text, is_error)
    if name == "file_tree":
        return tool_result(file_tree(args))
    if name == "dependency_summary":
        return tool_result(dependency_summary(args))
    return tool_result(f"unknown tool: {name}", True)


def loop():
    log(f"starting for roots: {', '.join(str(p) for p in project_roots()) or 'none'}")
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            req = json.loads(line)
            method = req.get("method")
            req_id = req.get("id")
            if method == "initialize":
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {
                            "protocolVersion": req.get("params", {}).get("protocolVersion", "2024-11-05"),
                            "capabilities": {"tools": {}},
                            "serverInfo": {"name": NAME, "version": VERSION},
                        },
                    }
                )
            elif method == "notifications/initialized":
                continue
            elif method == "tools/list":
                send({"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}})
            elif method == "tools/call":
                params = req.get("params", {})
                send({"jsonrpc": "2.0", "id": req_id, "result": handle(params.get("name"), params.get("arguments"))})
            elif req_id is not None:
                send({"jsonrpc": "2.0", "id": req_id, "error": {"code": -32601, "message": f"method not found: {method}"}})
        except Exception as exc:
            log(f"error: {exc}")


if __name__ == "__main__":
    loop()
