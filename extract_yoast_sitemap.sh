#!/usr/bin/env bash
# Author: Johan Caripson

# Exit immediately if a command exits with a non-zero status, treat unset
# variables as an error and make pipelines fail if any command fails.
set -euo pipefail

usage() {
    # Print script usage information and exit with an error code.
    echo "Usage: $0 [-j jobs] [-u user-agent] <sitemap_index_url> <output_file>" >&2
    exit 1
}

fetch_locs() {
    # Retrieve all <loc> entries from the sitemap passed as the first argument.
    local url="$1"

    # Build curl arguments, optionally adding a custom user agent.
    local -a curl_args=( -sL )
    if [[ -n "${USER_AGENT:-}" ]]; then
        curl_args+=( -A "$USER_AGENT" )
    fi

    # If the sitemap is a gzipped file, decompress it before parsing.
    if [[ "$url" == *.gz ]]; then
        curl "${curl_args[@]}" "$url" | gunzip -c |
            xmlstarlet sel -t -m '//*[local-name()="loc"]' -v . -n
    else
        curl "${curl_args[@]}" "$url" |
            xmlstarlet sel -t -m '//*[local-name()="loc"]' -v . -n
    fi
}

main() {
    # Default number of parallel workers. Can be overridden with -j or
    # the PARALLEL_JOBS environment variable.
    local parallel_jobs="${PARALLEL_JOBS:-1}"
    # Optional user agent string for curl.
    local user_agent=""

    # Parse command line options.
    while getopts ":j:u:" opt; do
        case "$opt" in
            j)
                parallel_jobs="$OPTARG"
                ;;
            u)
                user_agent="$OPTARG"
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND - 1))

    # Ensure exactly two arguments are provided: the index URL and output file.
    if [[ $# -ne 2 ]]; then
        usage
    fi

    # URL to the sitemap index.
    local index_url="$1"
    # File where the extracted URLs will be written.
    local output_file="$2"

    # Make variables available to functions executed in subshells.
    export USER_AGENT="$user_agent"

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
