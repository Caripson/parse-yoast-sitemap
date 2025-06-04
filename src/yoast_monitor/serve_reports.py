#!/usr/bin/env python3

import argparse
import json
import datetime
from flask import Flask
import psutil

app = Flask(__name__)

CONFIG_PATH = "server_config.json"
OVERRIDE_INTERVAL = None


def load_config():
    try:
        with open(CONFIG_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {"port": 8000, "report_json": "report.json", "refresh_interval": 5}


def load_report(path):
    data = []
    try:
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    data.append(json.loads(line))
    except FileNotFoundError:
        pass
    return data


@app.route("/")
def index():
    cfg = load_config()
    if OVERRIDE_INTERVAL is not None:
        cfg["refresh_interval"] = OVERRIDE_INTERVAL
    data = load_report(cfg.get("report_json"))
    stats = {
        "cpu": psutil.cpu_percent(interval=0.1),
        "mem": psutil.virtual_memory(),
        "disk": psutil.disk_io_counters(),
    }
    added = sum(len(d.get("added_urls", [])) for d in data)
    changed = sum(len(d.get("changed_urls", [])) for d in data)
    removed = sum(len(d.get("removed_urls", [])) for d in data)
    rows = []
    for d in data[-10:][::-1]:
        ts = d.get("timestamp")
        if isinstance(ts, (int, float)):
            ts = datetime.datetime.utcfromtimestamp(ts).isoformat()
        rows.append(
            {
                "time": ts,
                "added": len(d.get("added_urls", [])),
                "changed": len(d.get("changed_urls", [])),
                "removed": len(d.get("removed_urls", [])),
            }
        )
    html = """
    <!doctype html>
    <html lang='en'>
    <head>
    <meta charset='utf-8'>
    <meta http-equiv='refresh' content='{ref}'>
    <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css'>
    <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css'>
    <title>Real-Time Sitemap Report</title>
    </head>
    <body class='container py-4'>
    <h1 class='mb-4'><i class='bi bi-graph-up'></i> Real-Time Sitemap Report</h1>
    <p>CPU Usage: {cpu:.1f}% | Memory: {mem_used:.1f}/{mem_total:.1f} MB | Disk Read: {disk_read}B | Disk Write: {disk_write}B</p>
    <p class='mb-3'>Total added: {added} | Total changed: {changed} | Total removed: {removed}</p>
    <table class='table table-striped'>
    <thead><tr><th>Timestamp</th><th><i class='bi bi-plus-circle'></i> Added</th><th><i class='bi bi-arrow-repeat'></i> Changed</th><th><i class='bi bi-dash-circle'></i> Removed</th></tr></thead>
    <tbody>
    {rows}
    </tbody>
    </table>
    </body></html>
    """.format(
        ref=cfg.get("refresh_interval", 5),
        cpu=stats["cpu"],
        mem_used=stats["mem"].used / 1024 / 1024,
        mem_total=stats["mem"].total / 1024 / 1024,
        disk_read=stats["disk"].read_bytes,
        disk_write=stats["disk"].write_bytes,
        added=added,
        changed=changed,
        removed=removed,
        rows="\n".join(
            f"<tr><td>{r['time']}</td><td>{r['added']}</td><td>{r['changed']}</td><td>{r['removed']}</td></tr>"
            for r in rows
        ),
    )
    return html


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description="Serve real-time reports")
    parser.add_argument(
        "config",
        nargs="?",
        default="server_config.json",
        help="Path to server configuration JSON",
    )
    parser.add_argument(
        "--interval",
        type=int,
        help="Override refresh interval in seconds",
    )
    args = parser.parse_args(argv)

    global CONFIG_PATH
    CONFIG_PATH = args.config

    global OVERRIDE_INTERVAL
    OVERRIDE_INTERVAL = args.interval

    cfg = load_config()
    if args.interval is not None:
        cfg["refresh_interval"] = args.interval
    app.run(host="127.0.0.1", port=cfg.get("port", 8000), debug=False)


if __name__ == "__main__":
    main()
