# parse-yoast-sitemap
Parse yoast sitemap.xml with bash to URL list

## Requirements

The script depends on `curl` and [`xmlstarlet`](https://xmlstar.sourceforge.net/).
Both commands must be installed for the script to run. By default, sitemaps
are processed sequentially. To fetch them in parallel, set the
`PARALLEL_JOBS` environment variable or pass `-j <jobs>` on the command
line; parallel execution relies on `xargs` to spawn multiple workers.

## Running Tests

This repository uses [Bats](https://github.com/bats-core/bats-core) for testing. After installing the `bats` package, run:

```bash
bats tests/extract_yoast_sitemap.bats
```

The test uses sample sitemaps in `tests/data` and verifies that `extract_yoast_sitemap.sh` outputs the expected URLs.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
