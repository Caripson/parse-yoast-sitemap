# parse-yoast-sitemap
Parse yoast sitemap.xml with bash to URL list

## Requirements

The script depends on `curl` and [`xmlstarlet`](https://xmlstar.sourceforge.net/)
for parsing XML. To enable parallel sitemap fetching, install the
`parallel` package and set the `PARALLEL_JOBS` environment variable.

## Running Tests

This repository uses [Bats](https://github.com/bats-core/bats-core) for testing. After installing the `bats` package, run:

```bash
bats tests/extract_yoast_sitemap.bats
```

The test uses sample sitemaps in `tests/data` and verifies that `extract_yoast_sitemap.sh` outputs the expected URLs.
