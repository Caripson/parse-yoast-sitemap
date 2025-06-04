#!/usr/bin/env bats

setup() {
  TMP_OUT="$(mktemp)"
  TMP_CONFIG="$(mktemp)"
  TMP_INDEX1="$(mktemp)"
  TMP_INDEX2="$(mktemp)"
  sed "s|{{ROOT}}|file://${PWD}|g" tests/data/index1.template.xml > "$TMP_INDEX1"
  sed "s|{{ROOT}}|file://${PWD}|g" tests/data/index2.template.xml > "$TMP_INDEX2"
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
