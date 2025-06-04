#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <sitemap_index_url> <output_file>" >&2
    exit 1
}

fetch_locs() {
    local url="$1"
    curl -s "$url" | xmlstarlet sel -t -m '//*[local-name()="loc"]' -v . -n
}

main() {
    if [[ $# -ne 2 ]]; then
        usage
    fi

    local index_url="$1"
    local output_file="$2"

    if ! touch "$output_file" 2>/dev/null; then
        echo "Cannot write to $output_file" >&2
        exit 1
    fi

    echo "# URL list" > "$output_file"

    local -a sitemaps
    mapfile -t sitemaps < <(fetch_locs "$index_url")

    local parallel_jobs="${PARALLEL_JOBS:-1}"
    if [[ "$parallel_jobs" -gt 1 ]]; then
        printf '%s\n' "${sitemaps[@]}" | \
            xargs -n1 -P "$parallel_jobs" -I{} bash -c 'fetch_locs "$1"' _ {} >> "$output_file"
    else
        for sitemap_url in "${sitemaps[@]}"; do
            fetch_locs "$sitemap_url" >> "$output_file"
        done
    fi
}

main "$@"
