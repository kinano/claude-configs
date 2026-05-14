#!/usr/bin/env python3
"""
Minimal MCP stub server. Responds to the initialization handshake with zero
tools and stays alive. Used by wrapper scripts when a server is not configured
on this machine, so Claude Desktop sees the server as connected (no tools)
rather than disconnected (error toast).
"""
import sys
import json


def write(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        msg = json.loads(raw)
    except Exception:
        continue
    req_id = msg.get("id")
    method = msg.get("method", "")
    if req_id is None:
        continue  # notifications — no response needed
    if method == "initialize":
        write({"jsonrpc": "2.0", "id": req_id, "result": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "serverInfo": {"name": "stub", "version": "0.0.0"},
        }})
    elif method == "tools/list":
        write({"jsonrpc": "2.0", "id": req_id, "result": {"tools": []}})
    else:
        write({"jsonrpc": "2.0", "id": req_id, "result": {}})
