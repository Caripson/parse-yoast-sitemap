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
    echo "📥 Usage: $0 [-e] [-j jobs] [-a user_agent] [-f pattern] [-c] [-k days] [-r] <config_file> <output_file>" >&2
    exit 1
}

parse_locs_file() {
    # Extract <loc> entries from a local XML file.
    local file="$1"
    if [[ "$USE_C" == true ]]; then
        cat "$file" | extract_locs
    else
        cat "$file" | xmlstarlet sel -t -m '//*[local-name()="loc"]' -v . -n
    fi
}

generate_report() {
    # Compare previous and current versions of a sitemap and print a summary.
    local url="$1"
    local old_file="$2"
    local new_file="$3"
    local old_size new_size
    old_size=$(stat -c %s "$old_file" 2>/dev/null || echo 0)
    new_size=$(stat -c %s "$new_file")
    echo "Changes for $url:" >&2
    echo "  Size: $old_size -> $new_size" >&2
    local tmp_old tmp_new
    tmp_old=$(mktemp)
    tmp_new=$(mktemp)
    parse_locs_file "$old_file" | sort > "$tmp_old"
    parse_locs_file "$new_file" | sort > "$tmp_new"
    local added removed
    added=$(comm -13 "$tmp_old" "$tmp_new" || true)
    removed=$(comm -23 "$tmp_old" "$tmp_new" || true)
    if [[ -n "$added" ]]; then
        echo "  Added URLs:" >&2
        echo "$added" | sed 's/^/    /' >&2
    fi
    if [[ -n "$removed" ]]; then
        echo "  Removed URLs:" >&2
        echo "$removed" | sed 's/^/    /' >&2
    fi
    rm -f "$tmp_old" "$tmp_new"
}

fetch_locs() {
    # Retrieve all <loc> entries from the sitemap passed as the first argument.
    local url="$1"
    local -a curl_cmd=(curl -s)
    if [[ -n "$USER_AGENT" ]]; then
        curl_cmd+=( -A "$USER_AGENT" )
    fi

    # Determine cache file based on a hash of the URL.
    local hash
    hash=$(printf '%s' "$url" | md5sum | cut -d' ' -f1)
    local cache_file="$CACHE_DIR/$hash.xml"
    local max_age=$((CACHE_DAYS * 86400))
    local now
    now=$(date +%s)
    local fetch_new=1

    if [[ -f "$cache_file" ]]; then
        local age=$((now - $(stat -c %Y "$cache_file")))
        if [[ $age -lt $max_age ]]; then
            fetch_new=0
        fi
    fi

    local old_file=""
    if [[ "$REPORT" == true && -f "$cache_file" ]]; then
        old_file=$(mktemp)
        cp "$cache_file" "$old_file"
        fetch_new=1
    fi

    if [[ $fetch_new -eq 1 ]]; then
        mkdir -p "$CACHE_DIR"
        "${curl_cmd[@]}" "$url" -o "$cache_file"
    fi

    local results
    if [[ "$USE_C" == true ]]; then
        results=$(cat "$cache_file" | extract_locs)
    else
        results=$(cat "$cache_file" | \
            xmlstarlet sel -t -m '//*[local-name()="loc"]' -v . -n)
    fi
    if [[ -n "${FILTER_PATTERN:-}" ]]; then
        results=$(printf '%s\n' "$results" | grep -E "$FILTER_PATTERN" || true)
    fi
    if [[ -n "$results" ]]; then
        printf '%s\n' "$results"
    fi

    if [[ "$REPORT" == true && -n "$old_file" ]]; then
        generate_report "$url" "$old_file" "$cache_file"
        rm -f "$old_file"
    fi
}

main() {
    require_command curl
    require_command xmlstarlet
    require_command jq
    # Parse options; -j for jobs, -e to echo URLs to stdout, -a to set curl user agent.
    local cli_jobs=""
    local echo_urls=false
    local user_agent=""
    local filter_pattern=""
    local use_c=false
    local cache_days=30
    local report=false
    while getopts "j:ea:f:k:cr" opt; do
        case "$opt" in
            j)
                cli_jobs="$OPTARG"
                ;;
            e)
                echo_urls=true
                ;;
            a)
                user_agent="$OPTARG"
                ;;
            f)
                filter_pattern="$OPTARG"
                ;;
            c)
                use_c=true
                ;;
            k)
                cache_days="$OPTARG"
                ;;
            r)
                report=true
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND - 1))

    USER_AGENT="$user_agent"
    FILTER_PATTERN="$filter_pattern"
    USE_C="$use_c"
    CACHE_DAYS="$cache_days"
    REPORT="$report"
    CACHE_DIR="${CACHE_DIR:-cache}"
    if [[ "$USE_C" == true ]]; then
        require_command extract_locs
    fi

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
        export output_file tmp_counts echo_urls USER_AGENT FILTER_PATTERN CACHE_DIR CACHE_DAYS REPORT USE_C
        # Feed the sitemap URLs to xargs which spawns workers that append their
        # results to the output file and record how many URLs were written.
        printf '%s\n' "${sitemaps[@]}" | \
            xargs -n1 -P "$parallel_jobs" -I{} bash -c '
                urls=$(fetch_locs "$1")
                if [[ "$echo_urls" == true ]]; then
                    printf "%s\n" "$urls"
                fi
                printf "%s\n" "$urls" >> "$output_file"
                printf "%s\n" "$urls" | wc -l >> "$tmp_counts"
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
            if [[ "$echo_urls" == true ]]; then
                printf '%s\n' "${tmp[@]}"
            fi
            ((url_count+=${#tmp[@]}))
        done
    fi

    echo "✅ Extracted $url_count URLs."
}

main "$@"
