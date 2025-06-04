#!/usr/bin/env bash
# Author: Johan Caripson

# Exit immediately if a command exits with a non-zero status, treat unset
# variables as an error and make pipelines fail if any command fails.
set -euo pipefail

usage() {
    # Print script usage information and exit with an error code.
    echo "Usage: $0 <sitemap_index_url> <output_file>" >&2
    exit 1
}

fetch_locs() {
    # Retrieve all <loc> entries from the sitemap passed as the first argument.
    local url="$1"
    # curl downloads the XML and xmlstarlet prints every value of <loc> on a
    # separate line.
    curl -s "$url" | xmlstarlet sel -t -m '//*[local-name()="loc"]' -v . -n
}

main() {
    # Ensure exactly two arguments are provided: the index URL and output file.
    if [[ $# -ne 2 ]]; then
        usage
    fi

    # URL to the sitemap index.
    local index_url="$1"
    # File where the extracted URLs will be written.
    local output_file="$2"

    # Verify that the output file is writable.
    if ! touch "$output_file" 2>/dev/null; then
        echo "Cannot write to $output_file" >&2
        exit 1
    fi

    # Seed the output file with a small header.
    echo "# URL list" > "$output_file"

    # Read all sitemap URLs from the index into an array.
    local -a sitemaps
    mapfile -t sitemaps < <(fetch_locs "$index_url")

    # Determine how many parallel workers should run.
    local parallel_jobs="${PARALLEL_JOBS:-1}"
    if [[ "$parallel_jobs" -gt 1 ]]; then
        # Export the helper so xargs can call it in parallel.
        export -f fetch_locs
        # Feed the sitemap URLs to xargs which spawns workers that append their
        # results to the output file.
        printf '%s\n' "${sitemaps[@]}" | \
            xargs -n1 -P "$parallel_jobs" -I{} bash -c 'fetch_locs "$1"' _ {} >> "$output_file"
    else
        # Sequentially process each sitemap when PARALLEL_JOBS is 1.
        for sitemap_url in "${sitemaps[@]}"; do
            fetch_locs "$sitemap_url" >> "$output_file"
        done
    fi
}

main "$@"
