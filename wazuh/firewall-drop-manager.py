#!/usr/bin/env python3

import json
from pathlib import Path
import sys

QUEUE_PATH = Path("/opt/lab/firewall-state/commands.log")


def read_payload():
    while True:
        line = sys.stdin.readline()
        if not line:
            return None
        line = line.strip()
        if line:
            return json.loads(line)


def srcip_from(payload):
    parameters = payload.get("parameters", {})
    alert = parameters.get("alert", {})
    data = alert.get("data", {})
    return data.get("srcip") or alert.get("srcip")


def queue(action, srcip):
    QUEUE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with QUEUE_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"{action} {srcip}\n")


def send_check_keys(srcip):
    print(
        json.dumps(
            {
                "version": 1,
                "origin": {"name": "firewall-drop", "module": "active-response"},
                "command": "check_keys",
                "parameters": {"keys": [srcip]},
            },
            separators=(",", ":"),
        ),
        flush=True,
    )


def main():
    payload = read_payload()
    if payload is None:
        return 0

    command = payload.get("command", "")
    srcip = srcip_from(payload)
    if not srcip:
        return 1

    if command == "add":
        send_check_keys(srcip)
        response = read_payload()
        if response is None:
            return 1
        decision = response.get("command", "")
        if decision == "abort":
            return 0
        if decision != "continue":
            return 1
        queue("add", srcip)
        return 0

    if command == "delete":
        queue("delete", srcip)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
