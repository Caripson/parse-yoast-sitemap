# parse-yoast-sitemap
Parse Yoast sitemap.xml files with Bash and output a flat list of URLs.

## Purpose
This script was written to quickly extract every URL from a Yoast generated
sitemap index. It reads the index, follows each sitemap entry and prints all
`<loc>` values to a file. The goal is to provide a small and dependency-light
tool for crawling or auditing tasks.

## History
Created by **Johan Caripson**, the project began as a short helper script and
gradually evolved with tests and parallel execution support.

## Requirements

The script depends on `curl`, [`xmlstarlet`](https://xmlstar.sourceforge.net/)
and `gzip` for handling compressed sitemaps. By default, sitemaps are processed
sequentially. To fetch them in parallel, either set the `PARALLEL_JOBS`
environment variable or pass `-j` on the command line; parallel execution
relies on `xargs` to spawn multiple workers.

## Usage

```bash
bash extract_yoast_sitemap.sh [-j jobs] [-u user-agent] <sitemap_index_url> <output_file>
```

- `-j` sets the number of parallel workers (default is `1`).
- `-u` specifies a custom User-Agent string for `curl`.

Sitemaps ending in `.gz` are automatically decompressed if `gzip` is available.

## Running Tests

This repository uses [Bats](https://github.com/bats-core/bats-core) for testing. After installing the `bats` package, run:

```bash
bats tests/extract_yoast_sitemap.bats
```

The test uses sample sitemaps in `tests/data` and verifies that `extract_yoast_sitemap.sh` outputs the expected URLs.

## How to Verify

1. Run the script against a known sitemap index.
2. Confirm that the resulting file contains every expected URL.
3. Optionally execute the Bats tests with `bats tests/extract_yoast_sitemap.bats` to ensure all automated checks pass.

## Future Improvements

* Better error handling when downloading sitemaps.
* Support incremental updates to avoid reprocessing unchanged files.
* Provide a Docker wrapper for easier distribution.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Johan Caripson
