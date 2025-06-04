#!/usr/bin/env bats

setup() {
  TMP_OUT="$(mktemp)"
  TMP_INDEX="$(mktemp)"
  sed "s|{{ROOT}}|file://${PWD}|g" tests/data/sitemap_index.template.xml > "$TMP_INDEX"
}

teardown() {
  rm -f "$TMP_OUT" "$TMP_INDEX"
}

@test "extracts all URLs from sitemap" {
  run bash extract_yoast_sitemap.sh "file://$TMP_INDEX" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
}

@test "extracts URLs in parallel" {
  PARALLEL_JOBS=2 run bash extract_yoast_sitemap.sh "file://$TMP_INDEX" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
}

@test "accepts -j flag" {
  run bash extract_yoast_sitemap.sh -j 2 "file://$TMP_INDEX" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
}
