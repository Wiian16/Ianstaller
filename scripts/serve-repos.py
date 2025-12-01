#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

# Determine repo path relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
REPO_DIR = os.path.join(PROJECT_ROOT, "repo-official")

PORT = 8080

if not os.path.isdir(REPO_DIR):
    print(f"ERROR: repo directory not found: {REPO_DIR}")
    sys.exit(1)

os.chdir(REPO_DIR)
print(f"Serving official repo from: {REPO_DIR}")
print(f"Listening on port {PORT}...")

handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("", PORT), handler) as httpd:
    httpd.serve_forever()
