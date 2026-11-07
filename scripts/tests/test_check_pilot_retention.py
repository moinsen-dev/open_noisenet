"""A synthetic HTTP monitor verifies nonzero exits, no secret leaks or redirects."""
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCRIPT = Path(__file__).resolve().parents[1] / 'check-pilot-retention.py'


def test_probe_alarms_for_stale_unavailable_and_redirect_without_leaking_token():
    received = []
    class Handler(BaseHTTPRequestHandler):
        status = 'ok'
        def do_GET(self):
            received.append((self.path, self.headers.get('Authorization')))
            if self.status == 'redirect':
                self.send_response(302)
                self.send_header('Location', '/target')
                self.end_headers()
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(json.dumps({'status': self.status}).encode())
        def log_message(self, format, *args):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = dict(os.environ, OPENNOISENET_PILOT_HEALTH_URL=f'http://127.0.0.1:{server.server_port}/api/v1/map-pilot/admin/retention-health', OPENNOISENET_PILOT_HEALTH_TOKEN='synthetic-token')
    try:
        for status, expected in [('ok', 0), ('stale', 2), ('missing', 2), ('redirect', 2)]:
            Handler.status = status
            result = subprocess.run([sys.executable, str(SCRIPT), '--allow-loopback-http'], env=env, capture_output=True, text=True, timeout=10)
            assert result.returncode == expected
            assert 'synthetic-token' not in result.stdout + result.stderr
        assert len(received) == 4 and all(path.endswith('/retention-health') for path, _ in received)
        assert all(token == 'Bearer synthetic-token' for _, token in received)
        no_local_permission = subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=10)
        assert no_local_permission.returncode == 2 and len(received) == 4
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
