import json
import subprocess
from pathlib import Path
import sys
import os

project_root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project_root / "src"))


def test_process_report_generates_summary(tmp_path: Path):
    # Create sample JSON report
    report_path = tmp_path / "report.json"
    entries = [
        {
            "timestamp": "2023-10-01T00:00:00Z",
            "added_urls": ["a", "b"],
            "changed_urls": ["c"],
            "removed_urls": [],
        },
        {
            "timestamp": "2023-10-02T00:00:00Z",
            "added_urls": ["d"],
            "changed_urls": ["e", "f"],
            "removed_urls": ["g", "h", "i"],
        },
    ]
    with report_path.open("w") as f:
        for e in entries:
            json.dump(e, f)
            f.write("\n")

    html_out = tmp_path / "out.html"
    env = os.environ.copy()
    env["PYTHONPATH"] = str(project_root / "src")
    subprocess.run(
        [
            "python3",
            "-m",
            "yoast_monitor.process_report",
            str(report_path),
            str(html_out),
        ],
        check=True,
        env=env,
    )

    text = html_out.read_text()
    assert "Total added URLs: 3" in text
    assert "Total changed URLs: 3" in text
    assert "Total removed URLs: 3" in text
