# parse-yoast-sitemap

Parse Yoast sitemap.xml with bash to a URL list.

This script is intended for site owners, SEOs, and developers who want a
lightweight way to export every link from a Yoast sitemap. You might run it
when preparing to audit your pages, feed a crawler, or simply share an
easy-to-read list of URLs.

Run the script with:

```
./extract_yoast_sitemap.sh <sitemap_url> <output_file>
```

The first argument is the URL to the Yoast `sitemap_index.xml` file and the second is the path to the file where extracted links will be written. The output file will begin with a `# URL list` header followed by each discovered URL.
