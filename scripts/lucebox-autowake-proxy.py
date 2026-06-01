#!/usr/bin/env python3
import http.server
import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request


SERVER_NAME = "lucebox-autowake-proxy"
BACKEND_SERVICE = os.environ.get("LUCEBOX_BACKEND_SERVICE", "lucebox-dflash.service")
PROXY_HOST = os.environ.get("LUCEBOX_PROXY_HOST", "127.0.0.1")
PROXY_PORT = int(os.environ.get("LUCEBOX_PROXY_PORT", "18080"))
BACKEND_URL = os.environ.get("LUCEBOX_BACKEND_URL", "http://127.0.0.1:18081").rstrip("/")
BACKEND_HEALTH_URL = os.environ.get("LUCEBOX_BACKEND_HEALTH_URL", f"{BACKEND_URL}/health")
IDLE_UNLOAD_SECONDS = int(os.environ.get("LUCEBOX_IDLE_UNLOAD_SECONDS", "3600"))
START_TIMEOUT_SECONDS = int(os.environ.get("LUCEBOX_START_TIMEOUT_SECONDS", "900"))
REQUEST_TIMEOUT_SECONDS = int(os.environ.get("LUCEBOX_PROXY_REQUEST_TIMEOUT_SECONDS", "900"))
IDLE_POLL_SECONDS = max(1, int(os.environ.get("LUCEBOX_IDLE_POLL_SECONDS", "15")))

HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}


def log(message):
    print(f"[{SERVER_NAME}] {message}", file=sys.stderr, flush=True)


def service_command(*args, check=False, timeout=30):
    result = subprocess.run(
        ["systemctl", "--user", *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise RuntimeError(f"systemctl --user {' '.join(args)} failed: {detail}")
    return result


def service_active():
    return service_command("is-active", "--quiet", BACKEND_SERVICE).returncode == 0


def backend_healthy(timeout=2):
    request = urllib.request.Request(BACKEND_HEALTH_URL, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return 200 <= response.status < 500
    except Exception:
        return False


class ProxyState:
    def __init__(self):
        self.lock = threading.Lock()
        self.start_lock = threading.Lock()
        self.active_requests = 0
        self.last_activity = time.monotonic() if service_active() else 0.0

    def begin_request(self):
        with self.lock:
            self.active_requests += 1
            self.last_activity = time.monotonic()

    def end_request(self):
        with self.lock:
            self.active_requests = max(0, self.active_requests - 1)
            self.last_activity = time.monotonic()

    def snapshot(self):
        with self.lock:
            return self.active_requests, self.last_activity

    def mark_activity(self):
        with self.lock:
            self.last_activity = time.monotonic()

    def mark_unloaded(self):
        with self.lock:
            self.last_activity = 0.0


STATE = ProxyState()


def start_backend():
    if backend_healthy():
        return
    with STATE.start_lock:
        if backend_healthy():
            return
        log(f"starting {BACKEND_SERVICE}")
        service_command("start", BACKEND_SERVICE, check=True, timeout=60)
        deadline = time.monotonic() + START_TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            if backend_healthy():
                STATE.mark_activity()
                log(f"{BACKEND_SERVICE} is healthy")
                return
            if not service_active():
                state = service_command("status", BACKEND_SERVICE, "--no-pager", timeout=10)
                detail = (state.stdout or state.stderr or "").strip()
                raise RuntimeError(f"{BACKEND_SERVICE} stopped before becoming healthy: {detail}")
            time.sleep(2)
        raise TimeoutError(f"{BACKEND_SERVICE} did not become healthy within {START_TIMEOUT_SECONDS}s")


def stop_backend_if_idle():
    if IDLE_UNLOAD_SECONDS <= 0:
        return
    active_requests, last_activity = STATE.snapshot()
    if active_requests:
        return
    if not last_activity:
        if service_active():
            STATE.mark_activity()
        return
    idle_seconds = time.monotonic() - last_activity
    if idle_seconds < IDLE_UNLOAD_SECONDS:
        return
    if not service_active():
        STATE.mark_unloaded()
        return
    log(f"stopping {BACKEND_SERVICE} after {int(idle_seconds)}s idle")
    service_command("stop", BACKEND_SERVICE, timeout=60)
    STATE.mark_unloaded()


def idle_loop():
    while True:
        time.sleep(IDLE_POLL_SECONDS)
        try:
            stop_backend_if_idle()
        except Exception as exc:
            log(f"idle stop failed: {exc}")


def proxy_health():
    active_requests, last_activity = STATE.snapshot()
    last_activity_age = None
    if last_activity:
        last_activity_age = round(time.monotonic() - last_activity, 3)
    return {
        "status": "ok",
        "proxy": {
            "name": SERVER_NAME,
            "listen": f"{PROXY_HOST}:{PROXY_PORT}",
            "idle_unload_seconds": IDLE_UNLOAD_SECONDS,
            "active_requests": active_requests,
            "last_activity_seconds_ago": last_activity_age,
        },
        "backend": {
            "service": BACKEND_SERVICE,
            "url": BACKEND_URL,
            "active": service_active(),
            "healthy": backend_healthy(),
        },
    }


def should_forward(path):
    request_path = urllib.parse.urlsplit(path).path
    return request_path == "/props" or request_path == "/v1" or request_path.startswith("/v1/")


def target_url(path):
    return f"{BACKEND_URL}{path}"


class LuceboxProxyHandler(http.server.BaseHTTPRequestHandler):
    server_version = SERVER_NAME

    def do_GET(self):
        if urllib.parse.urlsplit(self.path).path == "/health":
            self.send_json(200, proxy_health())
            return
        self.handle_forward()

    def do_POST(self):
        self.handle_forward()

    def do_OPTIONS(self):
        self.handle_forward()

    def do_HEAD(self):
        self.handle_forward()

    def log_message(self, fmt, *args):
        log(f"{self.address_string()} {fmt % args}")

    def send_json(self, status, payload):
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def send_error_json(self, status, message):
        self.send_json(status, {"error": {"message": message, "type": "proxy_error"}})

    def handle_forward(self):
        if not should_forward(self.path):
            self.send_error_json(404, "not found")
            return

        STATE.begin_request()
        try:
            start_backend()
            self.forward_to_backend()
        except Exception as exc:
            log(f"request failed: {exc}")
            self.send_error_json(502, str(exc))
        finally:
            STATE.end_request()

    def forward_to_backend(self):
        body = None
        content_length = self.headers.get("Content-Length")
        if content_length:
            body = self.rfile.read(int(content_length))
        elif self.command in {"POST", "PUT", "PATCH"}:
            body = b""

        headers = {}
        for key, value in self.headers.items():
            lower = key.lower()
            if lower in HOP_BY_HOP_HEADERS or lower == "host" or lower == "content-length":
                continue
            headers[key] = value

        request = urllib.request.Request(
            target_url(self.path),
            data=body,
            headers=headers,
            method=self.command,
        )
        try:
            response = urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS)
        except urllib.error.HTTPError as exc:
            self.write_backend_response(exc)
            return
        self.write_backend_response(response)

    def write_backend_response(self, response):
        self.send_response(getattr(response, "status", getattr(response, "code", 502)))
        for key, value in response.headers.items():
            if key.lower() in HOP_BY_HOP_HEADERS:
                continue
            self.send_header(key, value)
        self.end_headers()
        if self.command == "HEAD":
            response.close()
            return
        try:
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        finally:
            response.close()


def main():
    threading.Thread(target=idle_loop, name="lucebox-idle-stop", daemon=True).start()
    server = http.server.ThreadingHTTPServer((PROXY_HOST, PROXY_PORT), LuceboxProxyHandler)
    log(
        f"listening on {PROXY_HOST}:{PROXY_PORT}, forwarding to {BACKEND_URL}, "
        f"idle unload {IDLE_UNLOAD_SECONDS}s"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
