import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer


APP_NAME = os.getenv("AGENTEIA_NAME", "Elusive Agent")
LOG_PATH = os.getenv("AGENTEIA_LOG_PATH", "/var/log/agenteia/app.log")
DB_HOST = os.getenv("DATABASE_HOST", "database")
DB_NAME = os.getenv("DATABASE_NAME", "elusive")


def write_log(event_type, path, extra=None):
    payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event_type": event_type,
        "path": path,
        "service": APP_NAME,
        "database_host": DB_HOST,
        "database_name": DB_NAME,
    }
    if extra:
        payload.update(extra)

    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload) + "\n")


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, payload):
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        write_log("http_request", self.path, {"method": "GET", "client": self.client_address[0]})

        if self.path == "/health":
            self._send(200, {"status": "ok", "service": APP_NAME})
            return

        self._send(
            200,
            {
                "service": APP_NAME,
                "role": "Agente IA de laboratorio",
                "database": {"host": DB_HOST, "name": DB_NAME},
                "routes": ["/", "/health", "/ask"],
            },
        )

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8") if length else ""
        write_log(
            "http_request",
            self.path,
            {"method": "POST", "client": self.client_address[0], "body_length": len(body)},
        )

        if self.path != "/ask":
            self._send(404, {"error": "route not found"})
            return

        self._send(
            200,
            {
                "answer": "Entorno preparado. Usa este servicio como placeholder para un agente IA conectado a proxy, logs y base de datos.",
                "received_bytes": len(body),
            },
        )


if __name__ == "__main__":
    write_log("startup", "/", {"message": "Agente IA iniciado"})
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
