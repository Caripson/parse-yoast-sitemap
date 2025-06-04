# parse-yoast-sitemap
Parse a Yoast sitemap.xml into a plain URL list using a single Bash script.

This tool targets **administrators and SEO specialists** who need a quick way
to gather every URL that Yoast exposes in its sitemap index.  Typical use cases
include site migrations, broken-link audits or verifying that all pages are
being discovered by search engines.

## 📚 History

The script started as a small internal helper written by Johan Caripson to
collect URLs from several WordPress sites.  It has since been cleaned up and
packaged with a test suite so it can be reused by others.

## 📝 Requirements

The script depends on the following command line tools:

* [`curl`](https://curl.se/) – fetches the sitemap XML files
* [`xmlstarlet`](https://xmlstar.sourceforge.net) – extracts `<loc>` entries
* [`jq`](https://stedolan.github.io/jq/) – reads the JSON config file
* `xargs` – used for parallel execution when `-j` or `PARALLEL_JOBS` is set

All commands must be available in your `PATH` for the script to run. By
default, sitemaps are processed sequentially. To fetch them in parallel, set the
`PARALLEL_JOBS` environment variable or pass `-j <jobs>` on the command line.

## 📥 Usage

```bash
./extract_yoast_sitemap.sh [-e] [-j jobs] [-a user_agent] [-f pattern] [-k days] [-r] <config_file> <output_file>
```

### Flags

* `-e` &nbsp; echo each extracted URL to stdout
* `-j` &nbsp; run multiple workers in parallel
* `-a` &nbsp; specify a custom User-Agent header when fetching sitemaps
* `-f` &nbsp; only include URLs matching the given pattern
* `-c` &nbsp; use the optional C parser for URL extraction
* `-k` &nbsp; keep downloaded sitemaps for the given number of days (default 30)
* `-r` &nbsp; fetch new versions and report changes compared to the cached copy

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

All of the above commands must be available in your `PATH` before running the script.


## 🧪 Running Tests

This repository uses [Bats](https://github.com/bats-core/bats-core) for testing. After installing the `bats` package, run:

```bash
bats tests/extract_yoast_sitemap.bats
```


The test uses sample sitemaps in `tests/data` and verifies that `extract_yoast_sitemap.sh` outputs the expected URLs.

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
version.

## 🐳 Running with Docker

Build the image and run the script inside a container:

```bash
docker build -t yoast-sitemap .
docker run --rm -v "$PWD":/data yoast-sitemap /data/config.json /data/urls.txt
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
   git clone https://github.com/<user>/parse-yoast-sitemap.git
   cd parse-yoast-sitemap
   git pull
   ```
2. Install the dependencies (Debian/Ubuntu example):
   ```bash
   sudo apt-get update && sudo apt-get install curl xmlstarlet jq
   ```
   To enable the C version of the parser you also need `libxml2` and a build step:
   ```bash
   gcc extract_locs.c -o extract_locs $(xml2-config --cflags --libs)
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

