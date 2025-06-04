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
    echo "📥 Usage: $0 [-e] [-j jobs] [-a user_agent] [-f pattern] [-c] [-k days] [-r] [--report-json file] [--report-csv file] [--process-report file] <config_file> <output_file>" >&2
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

parse_url_entries() {
    # Extract "url lastmod" pairs from a local XML file.
    local file="$1"
    xmlstarlet sel -t -m '//*[local-name()="url"]' \
        -v 'concat(./*[local-name()="loc"]," ",./*[local-name()="lastmod"])' -n "$file"
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
    parse_url_entries "$old_file" | sort > "$tmp_old"
    parse_url_entries "$new_file" | sort > "$tmp_new"

    declare -A old_map new_map
    while read -r u m; do
        old_map["$u"]="$m"
    done < "$tmp_old"
    while read -r u m; do
        new_map["$u"]="$m"
    done < "$tmp_new"

    local -a added changed removed
    for u in "${!new_map[@]}"; do
        if [[ -z "${old_map[$u]+x}" ]]; then
            added+=("$u")
            if [[ -n "${REPORT_CSV_FILE:-}" ]]; then
                printf 'sitemap-%s,%s,NEW,%s\n' "$(date -r "$new_file" +%s)" "$u" "${new_map[$u]}" >> "$REPORT_CSV_FILE"
            fi
        else
            if [[ "${old_map[$u]}" != "${new_map[$u]}" ]]; then
                changed+=("$u")
                if [[ -n "${REPORT_CSV_FILE:-}" ]]; then
                    printf 'sitemap-%s,%s,Change,%s\n' "$(date -r "$new_file" +%s)" "$u" "${new_map[$u]}" >> "$REPORT_CSV_FILE"
                fi
            fi
        fi
    done
    for u in "${!old_map[@]}"; do
        if [[ -z "${new_map[$u]+x}" ]]; then
            removed+=("$u")
            if [[ -n "${REPORT_CSV_FILE:-}" ]]; then
                printf 'sitemap-%s,%s,deleted,%s\n' "$(date -r "$new_file" +%s)" "$u" "${old_map[$u]}" >> "$REPORT_CSV_FILE"
            fi
        fi
    done

    if [[ ${#added[@]} -gt 0 ]]; then
        echo "  Added URLs:" >&2
        printf '%s\n' "${added[@]}" | sed 's/^/    /' >&2
    fi
    if [[ ${#removed[@]} -gt 0 ]]; then
        echo "  Removed URLs:" >&2
        printf '%s\n' "${removed[@]}" | sed 's/^/    /' >&2
    fi
    if [[ ${#changed[@]} -gt 0 ]]; then
        echo "  Changed URLs:" >&2
        printf '%s\n' "${changed[@]}" | sed 's/^/    /' >&2
    fi

    if [[ -n "${REPORT_JSON_FILE:-}" ]]; then
        local added_json removed_json changed_json
        added_json=$(printf '%s\n' "${added[@]}" | jq -Rn '[inputs] | map(select(length>0))')
        removed_json=$(printf '%s\n' "${removed[@]}" | jq -Rn '[inputs] | map(select(length>0))')
        changed_json=$(printf '%s\n' "${changed[@]}" | jq -Rn '[inputs] | map(select(length>0))')
        jq -n --arg url "$url" \
              --argjson old_size "$old_size" \
              --argjson new_size "$new_size" \
              --argjson added_urls "$added_json" \
              --argjson removed_urls "$removed_json" \
              --argjson changed_urls "$changed_json" \
              '{url:$url, old_size:$old_size, new_size:$new_size, added_urls:$added_urls, removed_urls:$removed_urls, changed_urls:$changed_urls}' >> "$REPORT_JSON_FILE"
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
    local report_json_file=""
    local report_csv_file=""
    local process_report_file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -j)
                cli_jobs="$2"; shift 2 ;;
            -e)
                echo_urls=true; shift ;;
            -a)
                user_agent="$2"; shift 2 ;;
            -f)
                filter_pattern="$2"; shift 2 ;;
            -c)
                use_c=true; shift ;;
            -k)
                cache_days="$2"; shift 2 ;;
            -r)
                report=true; shift ;;
            --report-json)
                report_json_file="$2"; shift 2 ;;
            --report-csv)
                report_csv_file="$2"; shift 2 ;;
            --process-report)
                process_report_file="$2"; shift 2 ;;
            --)
                shift; break ;;
            -* )
                usage ;;
            *)
                break ;;
        esac
    done

    USER_AGENT="$user_agent"
    FILTER_PATTERN="$filter_pattern"
    USE_C="$use_c"
    CACHE_DAYS="$cache_days"
    REPORT="$report"
    REPORT_JSON_FILE="$report_json_file"
    REPORT_CSV_FILE="$report_csv_file"
    PROCESS_REPORT_FILE="$process_report_file"
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
        export output_file tmp_counts echo_urls USER_AGENT FILTER_PATTERN CACHE_DIR CACHE_DAYS REPORT USE_C REPORT_JSON_FILE REPORT_CSV_FILE PROCESS_REPORT_FILE
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
    if [[ -n "${PROCESS_REPORT_FILE:-}" && -n "${REPORT_JSON_FILE:-}" ]]; then
        python3 "$(dirname "$0")/process_report.py" "$REPORT_JSON_FILE" "$PROCESS_REPORT_FILE"
    fi
}

main "$@"
