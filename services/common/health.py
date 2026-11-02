"""Health endpoint for services that have no HTTP API of their own."""

import threading
from collections.abc import Callable
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def start_health_server(is_healthy: Callable[[], bool], port: int = 8080) -> None:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            healthy = self.path == "/healthz" and is_healthy()
            self.send_response(200 if healthy else 503)
            self.end_headers()

        def log_message(self, *args: object) -> None:
            pass

    server = ThreadingHTTPServer(("", port), Handler)  # noqa: S104 - reached by the kubelet
    threading.Thread(target=server.serve_forever, daemon=True).start()
