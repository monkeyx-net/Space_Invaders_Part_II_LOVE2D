import http.server, os, threading, webbrowser

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass

PORT = 8000
URL  = f"http://localhost:{PORT}"
os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/web")
server = http.server.HTTPServer(("localhost", PORT), Handler)
print(f"Serving {URL} — Ctrl+C to stop")
threading.Timer(0.2, lambda: webbrowser.open(URL)).start()
server.serve_forever()
