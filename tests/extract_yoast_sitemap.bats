#!/usr/bin/env bats

setup_file() {
  for cmd in curl xmlstarlet jq gcc xml2-config; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      skip "Required command '$cmd' not installed"
    fi
  done
}

setup() {
  TMP_OUT="$(mktemp)"
  TMP_CONFIG="$(mktemp)"
  TMP_INDEX1="$(mktemp)"
  TMP_INDEX2="$(mktemp)"
  TMP_BIN_DIR="$(mktemp -d)"
  sed "s|{{ROOT}}|file://${PWD}|g" tests/data/index1.template.xml > "$TMP_INDEX1"
  sed "s|{{ROOT}}|file://${PWD}|g" tests/data/index2.template.xml > "$TMP_INDEX2"
  if command -v xml2-config >/dev/null 2>&1; then
    gcc extract_locs.c -o "$TMP_BIN_DIR/extract_locs" $(xml2-config --cflags --libs)
  else
    gcc extract_locs.c -o "$TMP_BIN_DIR/extract_locs" $(pkg-config --cflags --libs libxml-2.0)
  fi
  PATH="$TMP_BIN_DIR:$PATH"
  cat > "$TMP_CONFIG" <<EOF
{
  "domains": [
    {"url": "file://$TMP_INDEX1"},
    {"url": "file://$TMP_INDEX2"}
  ]
}
EOF
}

teardown() {
  rm -f "$TMP_OUT" "$TMP_CONFIG" "$TMP_INDEX1" "$TMP_INDEX2"
  rm -rf "$TMP_BIN_DIR"
}

@test "extracts all URLs from sitemap" {
  run bash extract_yoast_sitemap.sh "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"✅ Extracted 4 URLs."* ]]
}

@test "filters URLs with -f" {
  run bash extract_yoast_sitemap.sh -f page "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  ! grep -q "http://example.com/post1" "$TMP_OUT"
  ! grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"✅ Extracted 2 URLs."* ]]
}

@test "extracts URLs in parallel" {
  PARALLEL_JOBS=2 run bash extract_yoast_sitemap.sh "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"✅ Extracted 4 URLs."* ]]
}

@test "accepts -j flag" {
  run bash extract_yoast_sitemap.sh -j 2 "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"✅ Extracted 4 URLs."* ]]
}

@test "accepts -a flag" {
  run bash extract_yoast_sitemap.sh -a "TestAgent" "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"✅ Extracted 4 URLs."* ]]
}

@test "echoes URLs with -e" {
  run bash extract_yoast_sitemap.sh -e "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"http://example.com/page1"* ]]
  [[ "$output" == *"http://example.com/page2"* ]]
  [[ "$output" == *"http://example.com/post1"* ]]
  [[ "$output" == *"http://example.com/post2"* ]]
  [[ "$output" == *"✅ Extracted 4 URLs."* ]]
}

@test "uses C parser with -c" {
  run bash extract_yoast_sitemap.sh -c "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
  [[ "$output" == *"✅ Extracted 4 URLs."* ]]
}

@test "errors when curl is missing" {
  BIN_DIR="$(mktemp -d)"
  ln -s "$(command -v xmlstarlet)" "$BIN_DIR/xmlstarlet"
  ln -s "$(command -v touch)" "$BIN_DIR/touch"
  PATH="$BIN_DIR" run /usr/bin/bash extract_yoast_sitemap.sh "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -ne 0 ]
  [[ "$output" == *curl* ]]
}

@test "errors when xmlstarlet is missing" {
  BIN_DIR="$(mktemp -d)"
  ln -s "$(command -v curl)" "$BIN_DIR/curl"
  ln -s "$(command -v touch)" "$BIN_DIR/touch"
  PATH="$BIN_DIR" run /usr/bin/bash extract_yoast_sitemap.sh "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -ne 0 ]
  [[ "$output" == *xmlstarlet* ]]
}

@test "errors when jq is missing" {
  BIN_DIR="$(mktemp -d)"
  ln -s "$(command -v curl)" "$BIN_DIR/curl"
  ln -s "$(command -v xmlstarlet)" "$BIN_DIR/xmlstarlet"
  ln -s "$(command -v touch)" "$BIN_DIR/touch"
  PATH="$BIN_DIR" run /usr/bin/bash extract_yoast_sitemap.sh "$TMP_CONFIG" "$TMP_OUT"
  [ "$status" -ne 0 ]
  [[ "$output" == *jq* ]]
}

@test "writes CSV report with --report-csv" {
  TMP_CFG2="$(mktemp)"
  TMP_OUT2="$(mktemp)"
  TMP_CSV="$(mktemp)"
  TMP_INDEX="$(mktemp)"
  TMP_POSTS="$(mktemp)"
  cat > "$TMP_POSTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://example.com/post1</loc><lastmod>2020-01-01T00:00:00+00:00</lastmod></url>
  <url><loc>http://example.com/post2</loc><lastmod>2020-01-02T00:00:00+00:00</lastmod></url>
</urlset>
EOF
  cat > "$TMP_INDEX" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>file://$TMP_POSTS</loc></sitemap>
</sitemapindex>
EOF
  cat > "$TMP_CFG2" <<EOF
{
  "domains": [
    {"url": "file://$TMP_INDEX"}
  ]
}
EOF
  CACHE_DIR_DIR="$(mktemp -d)"
  CACHE_DIR="$CACHE_DIR_DIR" bash extract_yoast_sitemap.sh "$TMP_CFG2" "$TMP_OUT2"
  cat > "$TMP_POSTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://example.com/post1</loc><lastmod>2020-02-01T00:00:00+00:00</lastmod></url>
  <url><loc>http://example.com/post3</loc><lastmod>2020-01-03T00:00:00+00:00</lastmod></url>
</urlset>
EOF
  CACHE_DIR="$CACHE_DIR_DIR" run bash extract_yoast_sitemap.sh -r --report-csv "$TMP_CSV" "$TMP_CFG2" "$TMP_OUT2"
  [ "$status" -eq 0 ]
  grep -q "NEW" "$TMP_CSV"
  grep -q "Change" "$TMP_CSV"
  grep -q "deleted" "$TMP_CSV"
  rm -f "$TMP_CFG2" "$TMP_OUT2" "$TMP_CSV" "$TMP_INDEX" "$TMP_POSTS"
}
