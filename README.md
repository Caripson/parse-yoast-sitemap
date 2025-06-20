# parse-yoast-sitemap
Parse an entire **Yoast** `sitemap.xml` (and its nested index files) into a plain
list of URLs using one lean Bash script – no heavyweight dependencies required.

The tool is built for **administrators, SEO specialists and DevOps/SRE teams**
who need a repeatable way to collect every public URL exposed by
Yoast-powered WordPress sites. Typical tasks include site migrations,
broken-link audits or verifying crawl coverage.

<img src="parse-yoast-sitemap-logo.png" alt="Screenshot" width="300">

## ✨ Features

- **Single-file Bash script** – portable, easy to read, no installer needed.  
- **Fast** – XML streamed through `xmlstarlet`; optional C parser for huge sitemaps.  
- **Diff & caching** – stores previous downloads, highlights added/removed URLs, JSON/CSV reports.  
- **Real-time dashboard** – lightweight Flask UI with auto-refresh to watch crawls live.
- **Cross-platform** – works on Linux and macOS; falls back to compatible `stat`/hash commands.  
- **Automated tests & CI** – Bats + pytest with GitHub Actions, coverage ≥ 90 %.  
- **Docker image** – build the provided Dockerfile to run everything in a container.

## 📝 Requirements

### Basic tools

These must be installed for `extract_yoast_sitemap.sh` to run:

* [`curl`](https://curl.se/) – fetches the sitemap XML files
* [`xmlstarlet`](https://xmlstar.sourceforge.net) – extracts `<loc>` entries
* [`jq`](https://stedolan.github.io/jq/) – reads the JSON config file
* `xargs` – used for parallel execution with `-j` or `PARALLEL_JOBS`

### Optional for advanced features

* `gcc` and `libxml2-dev` – compile `extract_locs.c` for a faster C parser
* `pip install -r requirements.txt` – enables HTML/PDF reports and the
  real-time Flask dashboard
* `boto3` and `paramiko` or the AWS CLI – required for the EC2 helpers

All commands must be available in your `PATH` for the script to run. By
default sitemaps are processed sequentially. To fetch them in parallel, set the
`PARALLEL_JOBS` environment variable or pass `-j <jobs>` on the command line.

## 📥 Usage

```bash
./extract_yoast_sitemap.sh [-e] [-j jobs] [-a user_agent] [-f pattern] [-k days] [-r] [--report-json file] [--report-csv file] [--process-report file] <config_file> <output_file>
```

### Flags

* `-e` &nbsp; echo each extracted URL to stdout
* `-j` &nbsp; run multiple workers in parallel
* `-a` &nbsp; specify a custom User-Agent header when fetching sitemaps
* `-f` &nbsp; only include URLs matching the given pattern
* `-c` &nbsp; use the optional C parser for URL extraction
* `-k` &nbsp; keep downloaded sitemaps for the given number of days (default 30)
* `-r` &nbsp; fetch new versions and report changes compared to the cached copy
* `--report-json` &nbsp; append change summaries as JSON objects to the given file
* `--report-csv` &nbsp; append detailed change rows to the given CSV file
* `--process-report` &nbsp; create an HTML/PDF report from the JSON data

The script uses `curl --fail`, so any HTTP error (status code >= 400) will
terminate execution with a non-zero exit code.

## 🚀 Installation

Use your system package manager to install the required tools:

* **Linux (apt)**

  ```bash
  sudo apt-get update && sudo apt-get install curl xmlstarlet jq
  ```

* **macOS (brew)**

  ```bash
  brew install curl xmlstarlet jq
  ```

To enable the optional C parser, also install the `libxml2` development
package and compile the helper binary:

```bash
gcc extract_locs.c -o extract_locs $(xml2-config --cflags --libs)
```

To enable HTML/PDF report generation, install the Python packages `matplotlib`
and `weasyprint`:

```bash
pip install matplotlib weasyprint
```

All of the above commands must be available in your `PATH` before running the script.

## 🖥 Compatibility

`extract_yoast_sitemap.sh` automatically detects whether `stat -c` and
`md5sum` are present. On systems like macOS where they are not available it
falls back to `stat -f` and `md5` or `shasum`. The helper functions
`file_mtime` and `hash_string` handle this detection so the script works the
same across Linux and macOS.


## 🧪 Running Tests

This repository uses [Bats](https://github.com/bats-core/bats-core) and
[pytest](https://docs.pytest.org/) for testing. Make sure the system tools used
by the script (`curl`, `xmlstarlet` and `jq`) are available in your `PATH`.
CI installs them via `apt`, but local runs may require installing these
packages manually. After installing the dependencies and the `bats` package,
run:

```bash
bats tests/extract_yoast_sitemap.bats
pytest
```

The Bats suite uses sample sitemaps in `tests/data` and verifies that
`extract_yoast_sitemap.sh` outputs the expected URLs. The pytest suite checks the
`process_report.py` helper.

## 📝 Example Run

```bash
./extract_yoast_sitemap.sh -e -c -a "MyBot/1.0" -f page https://example.com/sitemap_index.xml urls.txt
cat urls.txt
```

## 📦 Caching and Reports

Downloaded sitemap files are stored in the `cache` directory. By default the
script keeps them for 30 days to avoid unnecessary network requests. The
retention period can be adjusted with the `-k` flag. Use `-r` to force a fresh
download and print a report of added or removed URLs compared to the cached
version. Combine `-r` with `--report-json <file>` to store these reports in
machine readable form, or `--report-csv <file>` to log row based changes.
Pass `--process-report <output.html>` together with `--report-json` to
generate a styled HTML file (and a PDF if possible). Run for example:

```bash
python3 -m yoast_monitor.process_report report.json report.html
```

Each sitemap change is
appended as a single JSON object:

```json
{"url":"https://example.com/sitemap.xml","old_size":123,"new_size":156,"added_urls":["https://example.com/new"],"removed_urls":[]}
```

## 🐳 Running with Docker

Build the image and run the script inside a container:

```bash
docker build -t parse-yoast-sitemap .
docker run --rm -v "$PWD":/data parse-yoast-sitemap /data/config.json /data/urls.txt
```

## 🔭 Future Work

Here are a few ideas for how this project could evolve:

* Support for compressed (`.gz`) sitemaps


## 🛠️ Troubleshooting

If `curl`, `xmlstarlet` or `jq` are missing in the Codex environment, tests may fail. Enable internet access or provide a setup script to install the packages before running tests.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Example Configuration

Copy `config.example.json` to `config.json` and edit the sitemap URLs you want to process:

```json
{
  "domains": [
    {"url": "https://example.com/sitemap_index.xml"},
    {"url": "https://example.org/sitemap.xml"}
  ]
}
```

## Quick Start

Follow these steps to get up and running:

1. Clone the repository and enter the folder:
   ```bash
   git clone https://github.com/Caripson/parse-yoast-sitemap.git
   cd parse-yoast-sitemap
   ```
2. Install the basic tools (Debian/Ubuntu example):
   ```bash
   sudo apt-get update && sudo apt-get install curl xmlstarlet jq
   ```
   To use the faster C parser also install `libxml2-dev` and compile it:
   ```bash
   gcc extract_locs.c -o extract_locs $(xml2-config --cflags --libs)
   ```
   For HTML reports or the web dashboard install the Python packages:
   ```bash
   pip install -r requirements.txt
   ```
3. Create your configuration file:
   ```bash
   cp config.example.json config.json
   # edit config.json and add your sitemap links
   ```
4. Run the script and store all URLs in `urls.txt`:
   ```bash
   bash extract_yoast_sitemap.sh config.json urls.txt
   ```

### Example commands

```bash
# Print URLs while they are saved
bash extract_yoast_sitemap.sh -e config.json urls.txt

# Only fetch URLs containing the word "blog" and run four jobs in parallel
bash extract_yoast_sitemap.sh -f blog -j 4 config.json urls.txt

# Specify a custom User-Agent
bash extract_yoast_sitemap.sh -a "MyBot/1.0" config.json urls.txt

# Use the C parser with two parallel jobs
bash extract_yoast_sitemap.sh -c -j 2 config.json urls.txt
```

## 📊 Real-Time Reporting

Run the optional web server to monitor changes live. The server does not start
automatically when running `extract_yoast_sitemap.sh`, so the script can be
executed on its own. Start the server only if you want to inspect statistics
while the reports are being written. First install the Python packages:

```bash
pip install -r requirements.txt
```

Create a `server_config.json` based on `server_config.example.json` and start the
server:

```bash
cp server_config.example.json server_config.json
python3 -m yoast_monitor.serve_reports
```

Edit `server_config.json` to change the port or choose a different JSON file to
monitor. By default the server reads `report.json` on port `8000`. You can also
override the refresh interval with the `--interval` flag when starting the
server:

```bash
python3 -m yoast_monitor.serve_reports --interval 10
```

The real-time page now uses Bootstrap and Bootstrap Icons for a cleaner look.

Open `http://localhost:8000` in your browser to see the latest statistics. The
page automatically refreshes based on the `refresh_interval` setting.

The web page summarizes the total number of URLs that have been added,
changed or removed across all runs and shows the last ten executions in a
table.

## 🚀 EC2 Deployment

Use `ec2_manager.py` to spin up an AWS EC2 instance that automatically
clones this project and launches the real-time server. Before running the
script, create `ec2_config.json` based on `ec2_config.example.json` and
fill in your AMI, key pair and security group information. Then start an
instance:

```bash
python3 ec2_manager.py start --config ec2_config.json
```

The script waits until the web server is reachable and prints the instance
IP address. Browse to `http://<ip>:8080` (or your configured port) to view
the live report along with CPU, memory and disk usage statistics for the
server. Terminate the instance when done:

```bash
python3 ec2_manager.py stop <instance-id>
```

### Using the AWS CLI

If you prefer to rely on the AWS CLI rather than boto3, the repository also
includes `ec2_cli.py`. Ensure the [AWS CLI](https://aws.amazon.com/cli/) is
installed and configured. Create `ec2_cli_config.json` based on
`ec2_cli_config.example.json` and run:

```bash
python3 ec2_cli.py start --config ec2_cli_config.json
```

The default configuration launches a small Ubuntu instance using the `t3a`
family. The script ensures that the HTTP port specified in `server_port` is
open in the security group for the IP range defined by `allowed_ip` (or to the
world if you use `0.0.0.0/0`). Terminate the instance with:

```bash
python3 ec2_cli.py stop <instance-id>
```


## 🛡 Best Practices

* Keep the `cache` directory under version control if you want reproducible
  reports.
* Store report JSON files in a dedicated folder such as `reports/`.
* Schedule regular sitemap checks via cron and point the web server to the same
  report file for historical trends.

## 📜 Change Log

* Added trending charts and a built-in Flask server for real-time monitoring.
* `extract_yoast_sitemap.sh` now records timestamps in JSON reports.
* Included `requirements.txt` and `server_config.example.json`.
* Added `ec2_manager.py` for easy EC2 deployment and live server metrics.
* Added `ec2_cli.py` for deployments via the AWS CLI.

## 📚 History

The script started as a small internal helper written by Johan Caripson to
collect URLs from several WordPress sites.  It has since been cleaned up and
packaged with a test suite so it can be reused by others.
