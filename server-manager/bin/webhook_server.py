#!/usr/bin/env python3
"""McnVPS Webhook Server — listens for GitHub webhook POST requests."""

import hashlib
import hmac
import json
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 9999
WEBHOOK_DIR = "/etc/mcnvps/webhooks"
LOG_FILE = "/var/log/mcnvps-webhook.log"


def log(msg: str):
    with open(LOG_FILE, "a") as f:
        from datetime import datetime
        f.write(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}\n")


def verify_signature(payload: bytes, signature: str, secret: str) -> bool:
    if not signature:
        return False
    expected = "sha256=" + hmac.new(
        secret.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def read_conf(path: str) -> dict:
    conf = {}
    if not os.path.isfile(path):
        return conf
    with open(path) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                conf[k.strip()] = v.strip()
    return conf


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        path_parts = self.path.strip("/").split("/")
        if len(path_parts) != 2 or path_parts[0] != "webhook":
            self.send_response(404)
            self.end_headers()
            return

        domain = path_parts[1]
        conf_file = os.path.join(WEBHOOK_DIR, f"{domain}.conf")

        if not os.path.isfile(conf_file):
            log(f"No config for domain: {domain}")
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Domain not configured")
            return

        conf = read_conf(conf_file)
        secret = conf.get("SECRET", "")
        deploy_script = conf.get("DEPLOY_SCRIPT", "")
        branch = conf.get("BRANCH", "main")

        content_length = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(content_length)

        signature = self.headers.get("X-Hub-Signature-256", "")
        if secret and not verify_signature(payload, signature, secret):
            log(f"Invalid signature for {domain}")
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Invalid signature")
            return

        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            data = {}

        ref = data.get("ref", "")
        if ref and ref != f"refs/heads/{branch}":
            log(f"Ignoring push to {ref} for {domain} (watching {branch})")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Ignored (different branch)")
            return

        log(f"Deploying {domain} (branch: {branch})")

        if os.path.isfile(deploy_script) and os.access(deploy_script, os.X_OK):
            subprocess.Popen(
                ["/bin/bash", deploy_script],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Deploy triggered")

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"McnVPS Webhook Server running")

    def log_message(self, fmt, *args):
        log(fmt % args)


if __name__ == "__main__":
    os.makedirs(WEBHOOK_DIR, exist_ok=True)
    server = HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    log(f"Webhook server started on port {PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("Webhook server stopped")
        server.server_close()
