#!/usr/bin/env python3

import argparse
import json
import datetime
from flask import Flask

app = Flask(__name__)

CONFIG_PATH = 'server_config.json'

def load_config():
    try:
        with open(CONFIG_PATH, 'r') as f:
            return json.load(f)
    except Exception:
        return {"port": 8000, "report_json": "report.json", "refresh_interval": 5}

def load_report(path):
    data = []
    try:
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    data.append(json.loads(line))
    except FileNotFoundError:
        pass
    return data

@app.route('/')
def index():
    cfg = load_config()
    data = load_report(cfg.get('report_json'))
    added = sum(len(d.get('added_urls', [])) for d in data)
    changed = sum(len(d.get('changed_urls', [])) for d in data)
    removed = sum(len(d.get('removed_urls', [])) for d in data)
    rows = []
    for d in data[-10:][::-1]:
        ts = d.get('timestamp')
        if isinstance(ts, (int, float)):
            ts = datetime.datetime.utcfromtimestamp(ts).isoformat()
        rows.append({
            'time': ts,
            'added': len(d.get('added_urls', [])),
            'changed': len(d.get('changed_urls', [])),
            'removed': len(d.get('removed_urls', []))
        })
    html = """
    <html><head>
    <meta http-equiv='refresh' content='{ref}'>
    <style>table,th,td{{border:1px solid #ccc;border-collapse:collapse;padding:4px;}}</style>
    </head><body>
    <h1>Real-Time Sitemap Report</h1>
    <p>Total added: {added} | Total changed: {changed} | Total removed: {removed}</p>
    <table>
    <tr><th>Timestamp</th><th>Added</th><th>Changed</th><th>Removed</th></tr>
    {rows}
    </table>
    </body></html>
    """.format(
        ref=cfg.get('refresh_interval', 5),
        added=added,
        changed=changed,
        removed=removed,
        rows="\n".join(
            f"<tr><td>{r['time']}</td><td>{r['added']}</td><td>{r['changed']}</td><td>{r['removed']}</td></tr>" for r in rows
        )
    )
    return html


def main() -> None:
    parser = argparse.ArgumentParser(description='Serve real-time reports')
    parser.add_argument(
        'config',
        nargs='?',
        default='server_config.json',
        help='Path to server configuration JSON'
    )
    args = parser.parse_args()

    global CONFIG_PATH
    CONFIG_PATH = args.config

    cfg = load_config()
    app.run(host='0.0.0.0', port=cfg.get('port', 8000), debug=True)


if __name__ == '__main__':
    main()
