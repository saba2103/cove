import http.server
import socketserver
import os
import sys

PORT = 8089
DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    extensions_map = http.server.SimpleHTTPRequestHandler.extensions_map.copy()
    extensions_map.update({
        '.wasm': 'application/wasm',
        '.js': 'application/javascript',
    })

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", PORT), NoCacheHandler) as httpd:
    print(f"Serving {DIRECTORY} at http://localhost:{PORT} (no-cache)")
    httpd.serve_forever()
