import argparse
from . import __version__
from .process_report import main as process_report_main
from .serve_reports import main as serve_reports_main


def main(argv=None):
    parser = argparse.ArgumentParser(prog="yoast-monitor")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    pr = sub.add_parser("process-report", help="Generate HTML report from JSON")
    pr.add_argument("json_input")
    pr.add_argument("html_output")

    sv = sub.add_parser("serve", help="Serve real-time reports")
    sv.add_argument("config", nargs="?", default="server_config.json")

    args = parser.parse_args(argv)
    if args.cmd == "process-report":
        process_report_main([args.json_input, args.html_output])
    elif args.cmd == "serve":
        serve_reports_main([args.config])


if __name__ == "__main__":
    main()
