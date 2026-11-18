#!/bin/bash
set -eu
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y python3
mkdir -p /opt/study-demo

# 데이터 저장 없이, 요청을 처리한 서버의 이름만 반환합니다.
cat > /opt/study-demo/server.py <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from socket import gethostname


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (gethostname() + "\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
PY

cat > /etc/systemd/system/study-demo.service <<'UNIT'
[Unit]
Description=Study hostname response server
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
ExecStart=/usr/bin/python3 /opt/study-demo/server.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now study-demo
