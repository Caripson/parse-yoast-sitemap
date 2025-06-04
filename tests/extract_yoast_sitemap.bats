#!/usr/bin/env bats

setup() {
  TMP_OUT="$(mktemp)"
  TMP_INDEX="$(mktemp --suffix=.xml)"
  sed "s|{{ROOT}}|file://${PWD}|g" tests/data/sitemap_index.template.xml > "$TMP_INDEX"
  TMP_ROBOT_DIR="$(mktemp -d)"
  sed "s|{{SITEMAP}}|file://$TMP_INDEX|g" tests/data/robots.template.txt > "$TMP_ROBOT_DIR/robots.txt"
}

teardown() {
  rm -f "$TMP_OUT" "$TMP_INDEX"
  rm -rf "$TMP_ROBOT_DIR"
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

@test "auto-detects index from robots.txt" {
  run bash extract_yoast_sitemap.sh "file://$TMP_ROBOT_DIR" "$TMP_OUT"
  [ "$status" -eq 0 ]
  grep -q "http://example.com/page1" "$TMP_OUT"
  grep -q "http://example.com/page2" "$TMP_OUT"
  grep -q "http://example.com/post1" "$TMP_OUT"
  grep -q "http://example.com/post2" "$TMP_OUT"
}
