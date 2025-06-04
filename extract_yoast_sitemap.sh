#!/usr/bin/env bash
# Author: Johan Caripson

# Exit immediately if a command exits with a non-zero status, treat unset
# variables as an error and make pipelines fail if any command fails.
set -euo pipefail

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Required command '$1' not found" >&2
        exit 1
    fi
}

usage() {
    # Print script usage information and exit with an error code.
    echo "Usage: $0 [-j jobs] <config_file> <output_file>" >&2
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
    require_command curl
    require_command xmlstarlet
    require_command jq
    # Parse options; currently only -j for specifying parallel jobs.
    local cli_jobs=""
    while getopts "j:" opt; do
        case "$opt" in
            j)
                cli_jobs="$OPTARG"
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND - 1))

    # Ensure exactly two arguments are provided: the config file and output file.
    if [[ $# -ne 2 ]]; then
        usage
    fi

    # Path to the JSON configuration file.
    local config_file="$1"
    # File where the extracted URLs will be written.
    local output_file="$2"

    # Verify that the configuration file exists and is readable.
    if [[ ! -r "$config_file" ]]; then
        echo "Cannot read $config_file" >&2
        exit 1
    fi

    # Verify that the output file is writable.
    if ! touch "$output_file" 2>/dev/null; then
        echo "Cannot write to $output_file" >&2
        exit 1
    fi

    # Seed the output file with a small header.
    echo "# URL list" > "$output_file"

    # Counter for how many URLs we extract in total.
    local url_count=0

    # Gather sitemap URLs from every domain listed in the configuration file.
    local -a index_urls sitemaps tmp
    mapfile -t index_urls < <(jq -r '.domains[].url' "$config_file")
    for index_url in "${index_urls[@]}"; do
        mapfile -t tmp < <(fetch_locs "$index_url")
        sitemaps+=("${tmp[@]}")
    done

    # Determine how many parallel workers should run. The -j option overrides
    # the PARALLEL_JOBS environment variable.
    local parallel_jobs="${cli_jobs:-${PARALLEL_JOBS:-1}}"
    if [[ "$parallel_jobs" -gt 1 ]]; then
        # Temporary file to collect URL counts from each worker.
        local tmp_counts="$(mktemp)"
        export -f fetch_locs
        export output_file tmp_counts
        # Feed the sitemap URLs to xargs which spawns workers that append their
        # results to the output file and record how many URLs were written.
        printf '%s\n' "${sitemaps[@]}" | \
            xargs -n1 -P "$parallel_jobs" -I{} bash -c '
                count=$(fetch_locs "$1" | tee -a "$output_file" | wc -l)
                echo "$count" >> "$tmp_counts"
            ' _ {}
        while read -r c; do
            ((url_count+=c))
        done < "$tmp_counts"
        rm "$tmp_counts"
    else
        # Sequentially process each sitemap when PARALLEL_JOBS is 1.
        for sitemap_url in "${sitemaps[@]}"; do
            mapfile -t tmp < <(fetch_locs "$sitemap_url")
            printf '%s\n' "${tmp[@]}" >> "$output_file"
            ((url_count+=${#tmp[@]}))
        done
    fi

    echo "🔢 Extracted $url_count URLs."
}

main "$@"
