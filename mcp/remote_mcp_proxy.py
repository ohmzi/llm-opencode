#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request


TARGET = os.environ.get("PROXY_TARGET", "context7")
TIMEOUT = int(os.environ.get("PROXY_TIMEOUT_SECONDS", "60"))
MAX_TEXT = 12000

URLS = {
    "context7": "https://mcp.context7.com/mcp",
    "gh_grep": "https://mcp.grep.app",
}


def log(message):
    print(f"[{TARGET}-proxy] {message}", file=sys.stderr, flush=True)


def parse_sse(text):
    chunks = []
    for line in text.splitlines():
        if line.startswith("data:"):
            chunks.append(line[5:].strip())
    payload = "\n".join(chunks).strip() or text.strip()
    return json.loads(payload) if payload else {}


def post(payload, session_id=None, expect_body=True):
    url = URLS[TARGET]
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if session_id:
        headers["MCP-Session-Id"] = session_id
    request = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            body = response.read().decode("utf-8", "replace")
            session = response.headers.get("MCP-Session-Id")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc
    if not expect_body or not body.strip():
        return {}, session
    return parse_sse(body), session


def remote_call(remote_name, arguments):
    init, session = post(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": f"{TARGET}-proxy", "version": "0.1.0"},
            },
        }
    )
    if init.get("error"):
        raise RuntimeError(init["error"].get("message", init["error"]))
    if session:
        try:
            post({"jsonrpc": "2.0", "method": "notifications/initialized"}, session, expect_body=False)
        except Exception:
            pass
    response, _ = post(
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": remote_name, "arguments": arguments},
        },
        session,
    )
    if response.get("error"):
        raise RuntimeError(response["error"].get("message", response["error"]))
    return response.get("result", {})


def trim_result(result):
    for item in result.get("content", []):
        if item.get("type") == "text" and len(item.get("text", "")) > MAX_TEXT:
            item["text"] = item["text"][:MAX_TEXT] + "\n... truncated ..."
    return result


CONTEXT7_TOOLS = [
    {
        "name": "context7_resolve",
        "description": "Find a Context7 library id.",
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string"}, "libraryName": {"type": "string"}},
            "required": ["query", "libraryName"],
        },
    },
    {
        "name": "context7_docs",
        "description": "Query Context7 docs.",
        "inputSchema": {
            "type": "object",
            "properties": {"libraryId": {"type": "string"}, "query": {"type": "string"}},
            "required": ["libraryId", "query"],
        },
    },
]

GH_GREP_TOOLS = [
    {
        "name": "gh_grep_search",
        "description": "Search public GitHub code.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "language": {"type": "array", "items": {"type": "string"}},
                "repo": {"type": "string"},
                "path": {"type": "string"},
                "useRegexp": {"type": "boolean"},
            },
            "required": ["query"],
        },
    }
]


def tools():
    return CONTEXT7_TOOLS if TARGET == "context7" else GH_GREP_TOOLS


def handle(name, args):
    args = args or {}
    if TARGET == "context7" and name == "context7_resolve":
        return trim_result(remote_call("resolve-library-id", args))
    if TARGET == "context7" and name == "context7_docs":
        return trim_result(remote_call("query-docs", args))
    if TARGET == "gh_grep" and name == "gh_grep_search":
        return trim_result(remote_call("searchGitHub", args))
    return {"content": [{"type": "text", "text": f"unknown tool: {name}"}], "isError": True}


def send(message):
    print(json.dumps(message, separators=(",", ":")), flush=True)


def loop():
    log(f"proxying {URLS.get(TARGET)}")
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
                            "serverInfo": {"name": f"{TARGET}-proxy", "version": "0.1.0"},
                        },
                    }
                )
            elif method == "notifications/initialized":
                continue
            elif method == "tools/list":
                send({"jsonrpc": "2.0", "id": req_id, "result": {"tools": tools()}})
            elif method == "tools/call":
                params = req.get("params", {})
                try:
                    result = handle(params.get("name"), params.get("arguments"))
                except Exception as exc:
                    result = {"content": [{"type": "text", "text": str(exc)}], "isError": True}
                send({"jsonrpc": "2.0", "id": req_id, "result": result})
            elif req_id is not None:
                send({"jsonrpc": "2.0", "id": req_id, "error": {"code": -32601, "message": f"method not found: {method}"}})
        except Exception as exc:
            log(f"error: {exc}")


if __name__ == "__main__":
    if TARGET not in URLS:
        raise SystemExit(f"unknown PROXY_TARGET: {TARGET}")
    loop()
