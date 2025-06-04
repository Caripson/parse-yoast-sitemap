# parse-yoast-sitemap
Parse yoast sitemap.xml with bash to URL list

## 📝 Requirements

The script depends on `curl` and [`xmlstarlet`](https://xmlstar.sourceforge.net/).
Both commands must be installed for the script to run. By default, sitemaps
are processed sequentially. To fetch them in parallel, set the
`PARALLEL_JOBS` environment variable or pass `-j <jobs>` on the command
line; parallel execution relies on `xargs` to spawn multiple workers.

## 📥 Usage

```bash
./extract_yoast_sitemap.sh [-e] [-j jobs] <config_file> <output_file>
```

* `-e`  also echo each extracted URL to stdout
* `-j`  run multiple workers in parallel

## 🚀 Installation

Use your system package manager to install the required tools:

* **Linux (apt)**

  ```bash
  sudo apt-get update && sudo apt-get install curl xmlstarlet
  ```

* **macOS (brew)**

  ```bash
  brew install curl xmlstarlet
  ```

Both commands must be available in your `PATH` before running the script.


## 🧪 Running Tests

This repository uses [Bats](https://github.com/bats-core/bats-core) for testing. After installing the `bats` package, run:

```bash
bats tests/extract_yoast_sitemap.bats
```


The test uses sample sitemaps in `tests/data` and verifies that `extract_yoast_sitemap.sh` outputs the expected URLs.

## 📝 Example Run

```bash
./extract_yoast_sitemap.sh -e https://example.com/sitemap_index.xml urls.txt
cat urls.txt
```


## 🛠️ Troubleshooting

If `curl` or `xmlstarlet` are missing in the Codex environment, tests may fail. Enable internet access or provide a setup script to install the packages before running tests.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
