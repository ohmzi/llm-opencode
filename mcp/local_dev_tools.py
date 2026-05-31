#!/usr/bin/env python3
import json
import os
import pathlib
import subprocess
import sys


NAME = "local-dev-tools"
VERSION = "0.1.0"
DEFAULT_STATE = os.path.expanduser(
    "~/Library/Application Support/ai.opencode.desktop/opencode.global.dat"
)
MAX_OUTPUT = 12000


def log(message):
    print(f"[{NAME}] {message}", file=sys.stderr, flush=True)


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
        last = state.get("lastProject", {})
        if isinstance(last, dict):
            candidates.extend(value for value in last.values() if isinstance(value, str))
        elif isinstance(last, str):
            candidates.append(last)
    roots = []
    seen = set()
    for value in candidates or [os.getcwd()]:
        if not value:
            continue
        try:
            path = pathlib.Path(os.path.expanduser(value)).resolve()
        except OSError:
            continue
        if path.exists() and path.is_dir() and str(path) not in seen:
            seen.add(str(path))
            roots.append(path)
    return roots


def root():
    roots = project_roots()
    return roots[0] if roots else pathlib.Path.cwd()


def run(command, cwd=None, timeout=120):
    cwd = str(cwd or root())
    try:
        proc = subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        output = proc.stdout or ""
        if len(output) > MAX_OUTPUT:
            output = output[:MAX_OUTPUT] + "\n... truncated ..."
        return f"$ {' '.join(command)}\nexit={proc.returncode}\ncwd={cwd}\n\n{output}".rstrip()
    except FileNotFoundError as exc:
        return f"missing command: {exc.filename}"
    except subprocess.TimeoutExpired:
        return f"timeout after {timeout}s: {' '.join(command)}"


def manifests(path):
    names = [
        "package.json",
        "Package.swift",
        "settings.gradle",
        "settings.gradle.kts",
        "build.gradle",
        "build.gradle.kts",
        "project.yml",
    ]
    found = []
    for current, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in {".git", "node_modules", "build", ".gradle", "DerivedData", "Pods"}]
        depth = pathlib.Path(current).relative_to(path).parts
        if len(depth) > 3:
            dirs[:] = []
            continue
        for name in names:
            if name in files:
                found.append(str((pathlib.Path(current) / name).relative_to(path)))
    return sorted(found)


def dev_status():
    path = root()
    lines = [f"root: {path}", "", "manifests:"]
    for item in manifests(path)[:40]:
        lines.append(f"- {item}")
    lines.extend(["", "git:"])
    lines.append(run(["git", "status", "--short"], path, 30))
    return "\n".join(lines).rstrip()


def dev_run(target):
    path = root()
    web = path / "tday-web"
    ios = path / "ios-swiftUI"
    targets = {
        "git_status": (["git", "status", "--short"], path, 30),
        "git_diff_stat": (["git", "diff", "--stat"], path, 30),
        "gradle_tasks": (["./gradlew", "tasks", "--all"], path, 120),
        "web_lint": (["npm", "run", "lint"], web, 180),
        "web_test": (["npm", "run", "test"], web, 180),
        "swift_build": (["swift", "build"], ios, 180),
    }
    if target not in targets:
        return "unknown target. use: " + ", ".join(sorted(targets))
    command, cwd, timeout = targets[target]
    return run(command, cwd, timeout)


def tool_result(text, is_error=False):
    return {"content": [{"type": "text", "text": text}], "isError": is_error}


TOOLS = [
    {
        "name": "dev_status",
        "description": "Project manifests and git status.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "dev_run",
        "description": "Run a safe project check by name.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {
                    "type": "string",
                    "enum": ["git_status", "git_diff_stat", "gradle_tasks", "web_lint", "web_test", "swift_build"],
                }
            },
            "required": ["target"],
        },
    },
]


def send(message):
    print(json.dumps(message, separators=(",", ":")), flush=True)


def handle(name, args):
    args = args or {}
    if name == "dev_status":
        return tool_result(dev_status())
    if name == "dev_run":
        return tool_result(dev_run(str(args.get("target", ""))))
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
