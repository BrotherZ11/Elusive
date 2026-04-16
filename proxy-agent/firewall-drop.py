#!/usr/bin/env python3

import json
import subprocess
import sys

LOG_PATH = "/var/ossec/logs/firewall-drop-debug.log"
BLOCK_PAGE_IP = "172.31.0.2"
BLOCK_PAGE_PORT = "8089"
WEB_IP = "172.31.0.20"


def log(message):
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as handle:
            handle.write(f"{message}\n")
    except OSError:
        pass


def run(command):
    return subprocess.run(
        command,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode


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
        )
    )


def add_block(srcip):
    accept_rule = ["iptables", "-C", "INPUT", "-s", srcip, "-p", "tcp", "--dport", BLOCK_PAGE_PORT, "-j", "ACCEPT"]
    if run(accept_rule) != 0:
        run(["iptables", "-I", "INPUT", "1", "-s", srcip, "-p", "tcp", "--dport", BLOCK_PAGE_PORT, "-j", "ACCEPT"])

    dnat_rule = [
        "iptables", "-t", "nat", "-C", "LAB_BLOCK_WEB",
        "-s", srcip, "-d", WEB_IP, "-p", "tcp", "--dport", "80",
        "-j", "DNAT", "--to-destination", f"{BLOCK_PAGE_IP}:{BLOCK_PAGE_PORT}",
    ]
    if run(dnat_rule) != 0:
        run([
            "iptables", "-t", "nat", "-I", "LAB_BLOCK_WEB", "1",
            "-s", srcip, "-d", WEB_IP, "-p", "tcp", "--dport", "80",
            "-j", "DNAT", "--to-destination", f"{BLOCK_PAGE_IP}:{BLOCK_PAGE_PORT}",
        ])

    drop_rule = ["iptables", "-C", "LAB_BLOCK", "-s", srcip, "-j", "DROP"]
    if run(drop_rule) != 0:
        run(["iptables", "-I", "LAB_BLOCK", "1", "-s", srcip, "-j", "DROP"])


def delete_block(srcip):
    run(["iptables", "-D", "INPUT", "-s", srcip, "-p", "tcp", "--dport", BLOCK_PAGE_PORT, "-j", "ACCEPT"])
    run([
        "iptables", "-t", "nat", "-D", "LAB_BLOCK_WEB",
        "-s", srcip, "-d", WEB_IP, "-p", "tcp", "--dport", "80",
        "-j", "DNAT", "--to-destination", f"{BLOCK_PAGE_IP}:{BLOCK_PAGE_PORT}",
    ])
    run(["iptables", "-D", "LAB_BLOCK", "-s", srcip, "-j", "DROP"])


def main():
    payload = read_payload()
    if payload is None:
        return 0

    command = payload.get("command", "")
    srcip = srcip_from(payload)

    if not srcip:
        log("Missing srcip in active response payload")
        return 1

    if command == "add":
        send_check_keys(srcip)
        response = read_payload()
        if response is None:
            log("Missing response to check_keys")
            return 1

        decision = response.get("command", "")
        if decision == "abort":
            log(f"Abort received for {srcip}")
            return 0
        if decision != "continue":
            log(f"Unexpected command: {decision}")
            return 1

        add_block(srcip)
        log(f"Blocked {srcip}")
        return 0

    if command == "delete":
        delete_block(srcip)
        log(f"Unblocked {srcip}")
        return 0

    log(f"Unsupported command: {command}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
