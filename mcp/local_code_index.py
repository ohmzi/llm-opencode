#!/usr/bin/env python3
import array
import hashlib
import json
import math
import os
import pathlib
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request


SERVER_NAME = "local-code-index"
SERVER_VERSION = "0.1.0"
DEFAULT_DB = os.path.expanduser("~/.cache/opencode/local-code-index.sqlite3")
DEFAULT_EMBED_URL = "http://127.0.0.1:1234/v1/embeddings"
DEFAULT_EMBED_MODEL = "text-embedding-nomic-embed-text-v1.5"
DEFAULT_LMSTUDIO_ENSURE_SCRIPT = "~/.config/opencode/ensure-lmstudio-models-linux.sh"
DEFAULT_DESKTOP_STATE = os.path.expanduser(
    "~/Library/Application Support/ai.opencode.desktop/opencode.global.dat"
)
MAX_FILE_BYTES = 512 * 1024
MAX_CHARS_PER_CHUNK = 3600
MAX_LINES_PER_CHUNK = 120
CHUNK_OVERLAP_LINES = 18
EMBED_BATCH_SIZE = 24
AUTO_SYNC_SECONDS = 300
BACKGROUND_SYNC_SECONDS = 300
SYNC_LOCK = threading.Lock()
BACKGROUND_STARTED = False

SKIP_DIRS = {
    ".git",
    ".gradle",
    ".idea",
    ".vscode",
    ".cache",
    ".dart_tool",
    ".next",
    ".swiftpm",
    "DerivedData",
    "Pods",
    "build",
    "dist",
    "node_modules",
    "out",
    "target",
    "__pycache__",
}

TEXT_EXTENSIONS = {
    ".c",
    ".cc",
    ".cpp",
    ".cs",
    ".css",
    ".gradle",
    ".graphql",
    ".h",
    ".hpp",
    ".html",
    ".java",
    ".js",
    ".json",
    ".jsonc",
    ".kt",
    ".kts",
    ".md",
    ".mjs",
    ".mm",
    ".plist",
    ".properties",
    ".py",
    ".rb",
    ".sh",
    ".sql",
    ".swift",
    ".toml",
    ".ts",
    ".tsx",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}

TEXT_NAMES = {
    ".gitignore",
    "AGENTS.md",
    "Dockerfile",
    "Gemfile",
    "Makefile",
    "Package.swift",
    "README",
    "README.md",
    "settings.gradle",
}


def log(message):
    print(f"[{SERVER_NAME}] {message}", file=sys.stderr, flush=True)


def truthy(name, default=False):
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() not in {"", "0", "false", "no", "off"}


def desktop_state_path():
    return os.path.expanduser(os.environ.get("OPENCODE_DESKTOP_STATE", DEFAULT_DESKTOP_STATE))


def root_mode():
    return os.environ.get("OPENCODE_INDEX_ROOTS", "").strip()


def auto_discovery_enabled():
    raw = root_mode().lower()
    return raw in {"auto", "opencode", "discover", "desktop"} or truthy(
        "OPENCODE_INDEX_AUTODISCOVER", False
    )


def allow_broad_roots():
    return truthy("OPENCODE_INDEX_ALLOW_BROAD_ROOTS", False)


def broad_auto_root(path):
    home = pathlib.Path.home().resolve()
    resolved = pathlib.Path(path).resolve()
    dangerous = {
        pathlib.Path("/"),
        pathlib.Path("/Applications"),
        pathlib.Path("/Library"),
        pathlib.Path("/System"),
        pathlib.Path("/Users"),
        pathlib.Path("/private"),
        home,
        home.parent,
    }
    return resolved in dangerous


def normalize_roots(values, skip_broad=False):
    result = []
    seen = set()
    for value in values:
        if not value:
            continue
        try:
            path = pathlib.Path(os.path.expanduser(str(value))).resolve()
        except OSError:
            continue
        if skip_broad and not allow_broad_roots() and broad_auto_root(path):
            log(f"skipping broad auto-discovered root: {path}")
            continue
        if path.exists() and path.is_dir() and str(path) not in seen:
            seen.add(str(path))
            result.append(str(path))
    return result


def explicit_roots():
    raw = root_mode()
    if not raw or raw.lower() in {"auto", "opencode", "discover", "desktop"}:
        return []
    return normalize_roots(part for part in raw.split(os.pathsep) if part)


def read_opencode_desktop_server_state():
    path = pathlib.Path(desktop_state_path())
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    for line in text.splitlines():
        stripped = line.strip().rstrip(",")
        if not stripped.startswith('"server"'):
            continue
        try:
            outer = json.loads("{" + stripped + "}")
            encoded = outer.get("server", "{}")
            return json.loads(encoded)
        except json.JSONDecodeError as exc:
            log(f"could not parse OpenCode Desktop project state: {exc}")
            return {}
    return {}


def discover_opencode_project_roots():
    if not auto_discovery_enabled():
        return []
    server = read_opencode_desktop_server_state()
    candidates = []
    projects = server.get("projects", {})
    if isinstance(projects, dict):
        for group in projects.values():
            if not isinstance(group, list):
                continue
            for item in group:
                if isinstance(item, dict):
                    candidates.append(item.get("worktree") or item.get("directory") or item.get("path"))
                elif isinstance(item, str):
                    candidates.append(item)
    last_project = server.get("lastProject", {})
    if isinstance(last_project, dict):
        candidates.extend(value for value in last_project.values() if isinstance(value, str))
    elif isinstance(last_project, str):
        candidates.append(last_project)
    return normalize_roots(candidates, skip_broad=True)


def roots():
    values = explicit_roots() + discover_opencode_project_roots()
    if values:
        return normalize_roots(values)
    if auto_discovery_enabled():
        return []
    return normalize_roots([os.getcwd()])


def roots_text():
    values = roots()
    return "\n".join(f"- {root}" for root in values) if values else "- none"


def db_path():
    return os.path.expanduser(os.environ.get("OPENCODE_INDEX_DB", DEFAULT_DB))


def embed_url():
    return os.environ.get("LMSTUDIO_EMBEDDING_URL", DEFAULT_EMBED_URL)


def embed_model():
    return os.environ.get("LMSTUDIO_EMBEDDING_MODEL", DEFAULT_EMBED_MODEL)


def lmstudio_ensure_script():
    configured = os.environ.get("LMSTUDIO_ENSURE_MODELS_SCRIPT")
    if configured:
        return os.path.expanduser(configured)
    candidates = [
        os.path.expanduser(DEFAULT_LMSTUDIO_ENSURE_SCRIPT),
        str(pathlib.Path(__file__).resolve().parent.parent / "ensure-lmstudio-models-linux.sh"),
        str(pathlib.Path(__file__).resolve().parent.parent / "ensure-lmstudio-models.sh"),
    ]
    for candidate in candidates:
        if pathlib.Path(candidate).exists():
            return candidate
    return candidates[0]


def ensure_embedding_model():
    script = lmstudio_ensure_script()
    if not pathlib.Path(script).exists():
        log(f"LM Studio ensure script not found: {script}")
        return False
    timeout_raw = os.environ.get("LMSTUDIO_ENSURE_TIMEOUT_SECONDS", "300")
    try:
        timeout = max(30, int(timeout_raw))
    except ValueError:
        timeout = 300
    command = [script]
    if script.endswith(".sh"):
        command = ["/bin/zsh", script]
    env = os.environ.copy()
    env.setdefault("LMSTUDIO_LOAD_CHAT_ROLLBACK", "0")
    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            env=env,
            check=False,
        )
    except Exception as exc:
        log(f"LM Studio embedding autoload failed: {exc}")
        return False
    if result.returncode == 0:
        log("LM Studio embedding model ensured")
        return True
    detail = (result.stderr or result.stdout or "").strip()
    log(f"LM Studio embedding autoload failed: {detail}")
    return False


def connect():
    path = db_path()
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute("pragma journal_mode=wal")
    conn.execute("pragma synchronous=normal")
    conn.execute(
        """
        create table if not exists chunks (
            id integer primary key,
            root text not null,
            path text not null,
            start_line integer not null,
            end_line integer not null,
            mtime_ns integer not null,
            size integer not null,
            sha256 text not null,
            content text not null,
            embedding blob not null,
            dims integer not null,
            updated_at integer not null
        )
        """
    )
    conn.execute("create index if not exists idx_chunks_path on chunks(root, path)")
    conn.execute(
        """
        create table if not exists meta (
            key text primary key,
            value text not null
        )
        """
    )
    return conn


def should_index(path):
    name = path.name
    if name in TEXT_NAMES:
        return True
    return path.suffix.lower() in TEXT_EXTENSIONS


def iter_files(root):
    root_path = pathlib.Path(root)
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.endswith(".xcodeproj")]
        for filename in files:
            path = pathlib.Path(current) / filename
            if not should_index(path):
                continue
            try:
                stat = path.stat()
            except OSError:
                continue
            if stat.st_size <= 0 or stat.st_size > MAX_FILE_BYTES:
                continue
            try:
                relative = str(path.relative_to(root_path))
            except ValueError:
                relative = str(path)
            yield path, relative, stat


def read_text(path):
    raw = path.read_bytes()
    if b"\x00" in raw[:4096]:
        return None
    for encoding in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            pass
    return None


def chunk_text(text):
    lines = text.splitlines()
    if not lines:
        return []
    chunks = []
    start = 0
    while start < len(lines):
        end = min(len(lines), start + MAX_LINES_PER_CHUNK)
        while end > start + 1 and len("\n".join(lines[start:end])) > MAX_CHARS_PER_CHUNK:
            end -= 1
        body = "\n".join(lines[start:end]).strip()
        if body:
            chunks.append((start + 1, end, body))
        if end >= len(lines):
            break
        start = max(end - CHUNK_OVERLAP_LINES, start + 1)
    return chunks


def encode_vector(values):
    data = array.array("f", values)
    return data.tobytes()


def decode_vector(blob):
    data = array.array("f")
    data.frombytes(blob)
    return data


def embed_once(texts):
    if not texts:
        return []
    payload = json.dumps({"model": embed_model(), "input": texts}).encode("utf-8")
    request = urllib.request.Request(
        embed_url(),
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"embedding request failed: HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"embedding request failed: {exc}") from exc
    if body.get("error"):
        raise RuntimeError(f"embedding request failed: {body['error']}")
    rows = sorted(body.get("data", []), key=lambda item: item.get("index", 0))
    return [row["embedding"] for row in rows]


def embed(texts):
    if not texts:
        return []
    try:
        return embed_once(texts)
    except RuntimeError:
        if not truthy("LMSTUDIO_EMBEDDING_AUTOLOAD", True):
            raise
        if ensure_embedding_model():
            return embed_once(texts)
        raise


def is_unchanged(conn, root, rel_path, stat):
    row = conn.execute(
        "select 1 from chunks where root=? and path=? and mtime_ns=? and size=? limit 1",
        (root, rel_path, stat.st_mtime_ns, stat.st_size),
    ).fetchone()
    return row is not None


def sync_index(force=False):
    with SYNC_LOCK:
        return _sync_index(force)


def _sync_index(force=False):
    conn = connect()
    start_time = time.time()
    indexed = 0
    skipped = 0
    removed = 0
    removed_roots = 0
    chunk_count = 0
    errors = []
    seen = set()
    active_roots = roots()

    for root in active_roots:
        for path, rel_path, stat in iter_files(root):
            seen.add((root, rel_path))
            if not force and is_unchanged(conn, root, rel_path, stat):
                skipped += 1
                continue
            try:
                text = read_text(path)
                if not text:
                    continue
                chunks = chunk_text(text)
                if not chunks:
                    continue
                conn.execute("delete from chunks where root=? and path=?", (root, rel_path))
                chunk_inputs = [
                    f"{rel_path}:{start_line}-{end_line}\n{content}"
                    for start_line, end_line, content in chunks
                ]
                vectors = []
                for offset in range(0, len(chunk_inputs), EMBED_BATCH_SIZE):
                    vectors.extend(embed(chunk_inputs[offset : offset + EMBED_BATCH_SIZE]))
                now = int(time.time())
                for (start_line, end_line, content), vector in zip(chunks, vectors):
                    digest = hashlib.sha256(content.encode("utf-8", "ignore")).hexdigest()
                    conn.execute(
                        """
                        insert into chunks
                        (root, path, start_line, end_line, mtime_ns, size, sha256, content, embedding, dims, updated_at)
                        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            root,
                            rel_path,
                            start_line,
                            end_line,
                            stat.st_mtime_ns,
                            stat.st_size,
                            digest,
                            content,
                            encode_vector(vector),
                            len(vector),
                            now,
                        ),
                    )
                indexed += 1
                chunk_count += len(chunks)
                conn.commit()
            except Exception as exc:
                errors.append(f"{rel_path}: {exc}")

        existing = conn.execute("select distinct path from chunks where root=?", (root,)).fetchall()
        for (rel_path,) in existing:
            if (root, rel_path) not in seen:
                conn.execute("delete from chunks where root=? and path=?", (root, rel_path))
                removed += 1
        conn.commit()

    active_root_set = set(active_roots)
    existing_roots = conn.execute("select distinct root from chunks").fetchall()
    for (root,) in existing_roots:
        if root not in active_root_set:
            conn.execute("delete from chunks where root=?", (root,))
            removed_roots += 1
    conn.commit()

    conn.execute("insert or replace into meta(key, value) values('last_sync', ?)", (str(int(time.time())),))
    conn.commit()
    total_chunks = conn.execute("select count(*) from chunks").fetchone()[0]
    total_files = conn.execute("select count(distinct root || char(0) || path) from chunks").fetchone()[0]
    conn.close()
    return {
        "indexed_files": indexed,
        "skipped_files": skipped,
        "removed_files": removed,
        "removed_roots": removed_roots,
        "new_chunks": chunk_count,
        "total_files": total_files,
        "total_chunks": total_chunks,
        "seconds": round(time.time() - start_time, 2),
        "errors": errors[:20],
    }


def maybe_sync():
    conn = connect()
    row = conn.execute("select value from meta where key='last_sync'").fetchone()
    conn.close()
    last = int(row[0]) if row and row[0].isdigit() else 0
    raw = os.environ.get("OPENCODE_INDEX_AUTO_SYNC_SECONDS", str(AUTO_SYNC_SECONDS))
    try:
        auto_sync_seconds = max(15, int(raw))
    except ValueError:
        auto_sync_seconds = AUTO_SYNC_SECONDS
    if time.time() - last > auto_sync_seconds:
        return sync_index(False)
    return None


def background_interval():
    raw = os.environ.get("OPENCODE_INDEX_BACKGROUND_SECONDS", str(BACKGROUND_SYNC_SECONDS))
    try:
        return max(15, int(raw))
    except ValueError:
        return BACKGROUND_SYNC_SECONDS


def background_sync_enabled():
    return truthy("OPENCODE_INDEX_BACKGROUND", False)


def background_sync_loop():
    interval = background_interval()
    while True:
        try:
            summary = sync_index(False)
            if (
                summary["indexed_files"]
                or summary["removed_files"]
                or summary.get("removed_roots")
                or summary["errors"]
            ):
                log(
                    "background sync: "
                    + f"{summary['indexed_files']} changed files, "
                    + f"{summary['removed_files']} removed files, "
                    + f"{summary.get('removed_roots', 0)} removed roots, "
                    + f"{summary['total_chunks']} chunks"
                )
                if summary["errors"]:
                    log("background sync errors: " + "; ".join(summary["errors"][:5]))
        except Exception as exc:
            log(f"background sync failed: {exc}")
        time.sleep(interval)


def start_background_sync():
    global BACKGROUND_STARTED
    if BACKGROUND_STARTED or not background_sync_enabled():
        return
    BACKGROUND_STARTED = True
    thread = threading.Thread(target=background_sync_loop, name="opencode-local-code-index", daemon=True)
    thread.start()
    log(f"background indexing enabled every {background_interval()} seconds")


def cosine(a, b):
    dot = 0.0
    norm_a = 0.0
    norm_b = 0.0
    for x, y in zip(a, b):
        dot += x * y
        norm_a += x * x
        norm_b += y * y
    if not norm_a or not norm_b:
        return 0.0
    return dot / math.sqrt(norm_a * norm_b)


def search(query, limit=8, root_filter=None):
    sync_summary = maybe_sync()
    query_vector = embed([query])[0]
    conn = connect()
    if root_filter:
        rows = conn.execute(
            "select root, path, start_line, end_line, content, embedding from chunks where root=?",
            (root_filter,),
        ).fetchall()
    else:
        rows = conn.execute(
            "select root, path, start_line, end_line, content, embedding from chunks"
        ).fetchall()
    conn.close()
    scored = []
    for root, path, start_line, end_line, content, blob in rows:
        score = cosine(query_vector, decode_vector(blob))
        scored.append((score, root, path, start_line, end_line, content))
    scored.sort(reverse=True, key=lambda item: item[0])
    results = scored[: max(1, min(int(limit), 20))]
    lines = []
    if sync_summary:
        lines.append(
            "Index refreshed: "
            + f"{sync_summary['indexed_files']} changed files, "
            + f"{sync_summary['total_chunks']} chunks total."
        )
        lines.append("")
    for rank, (score, root, path, start_line, end_line, content) in enumerate(results, 1):
        snippet = content.strip()
        if len(snippet) > 900:
            snippet = snippet[:900].rstrip() + "\n..."
        lines.append(f"{rank}. {path}:{start_line}-{end_line}  score={score:.3f}")
        lines.append(f"root: {root}")
        lines.append("```")
        lines.append(snippet)
        lines.append("```")
        lines.append("")
    if not results:
        lines.append("No indexed code chunks matched.")
    return "\n".join(lines).rstrip()


def status_text():
    conn = connect()
    total_chunks = conn.execute("select count(*) from chunks").fetchone()[0]
    total_files = conn.execute("select count(distinct root || char(0) || path) from chunks").fetchone()[0]
    last_row = conn.execute("select value from meta where key='last_sync'").fetchone()
    conn.close()
    last = "never"
    if last_row and last_row[0].isdigit():
        last = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(int(last_row[0])))
    return (
        f"Index database: {db_path()}\n"
        f"Embedding model: {embed_model()}\n"
        f"Embedding URL: {embed_url()}\n"
        f"Auto-discover OpenCode projects: {'on' if auto_discovery_enabled() else 'off'}\n"
        f"OpenCode Desktop state: {desktop_state_path()}\n"
        f"Background indexing: {'on' if background_sync_enabled() else 'off'}"
        f" every {background_interval()}s\n"
        f"Roots:\n{roots_text()}\n"
        f"Indexed files: {total_files}\n"
        f"Indexed chunks: {total_chunks}\n"
        f"Last sync: {last}"
    )


def tool_result(text, is_error=False):
    return {"content": [{"type": "text", "text": text}], "isError": is_error}


def handle_tool(name, args):
    args = args or {}
    if name == "code_index_search":
        query = str(args.get("query", "")).strip()
        if not query:
            return tool_result("Missing required argument: query", True)
        return tool_result(search(query, int(args.get("limit", 8)), args.get("root")))
    if name == "code_index_refresh":
        force = bool(args.get("force", False))
        summary = sync_index(force)
        return tool_result(json.dumps(summary, indent=2))
    if name == "code_index_status":
        return tool_result(status_text())
    return tool_result(f"Unknown tool: {name}", True)


TOOLS = [
    {
        "name": "code_index_search",
        "description": "Semantic search over indexed local code.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "limit": {"type": "integer"},
                "root": {"type": "string"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "code_index_refresh",
        "description": "Refresh local code index.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "force": {"type": "boolean"}
            },
        },
    },
    {
        "name": "code_index_status",
        "description": "Show index status.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def send(message):
    print(json.dumps(message, separators=(",", ":")), flush=True)


def mcp_loop():
    start_background_sync()
    log(f"starting MCP server for roots: {', '.join(roots()) or 'none'}")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            method = request.get("method")
            request_id = request.get("id")
            if method == "initialize":
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": {
                            "protocolVersion": request.get("params", {}).get("protocolVersion", "2024-11-05"),
                            "capabilities": {"tools": {}},
                            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
                        },
                    }
                )
            elif method == "notifications/initialized":
                continue
            elif method == "tools/list":
                send({"jsonrpc": "2.0", "id": request_id, "result": {"tools": TOOLS}})
            elif method == "tools/call":
                params = request.get("params", {})
                result = handle_tool(params.get("name"), params.get("arguments", {}))
                send({"jsonrpc": "2.0", "id": request_id, "result": result})
            elif request_id is not None:
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {"code": -32601, "message": f"Method not found: {method}"},
                    }
                )
        except Exception as exc:
            request_id = None
            try:
                request_id = json.loads(line).get("id")
            except Exception:
                pass
            if request_id is not None:
                send({"jsonrpc": "2.0", "id": request_id, "error": {"code": -32000, "message": str(exc)}})
            log(f"error: {exc}")


def main():
    if len(sys.argv) > 1 and sys.argv[1] in {"--index", "--reindex"}:
        force = sys.argv[1] == "--reindex"
        print(json.dumps(sync_index(force), indent=2))
        return
    if len(sys.argv) > 1 and sys.argv[1] == "--status":
        print(status_text())
        return
    mcp_loop()


if __name__ == "__main__":
    main()
