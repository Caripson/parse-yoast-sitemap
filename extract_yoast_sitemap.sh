#!/usr/bin/env bash
if [[ $# -ne 2 ]]; then
    echo "Usage: extract_yoast_sitemap.sh <sitemap_index_url> <output_file>"
    exit 1
fi


echo "# URL list" > "$2"

main_url=$(curl -s "$1" | grep "<loc>" | awk -F"<loc>" '{print $2} ' | awk -F"</loc>" '{print $1}')

for i in $main_url
do

        urls=$(curl -s "$i" | grep "<loc>" | awk -F"<loc>" '{print $2} ' | awk -F"</loc>" '{print $1}')
        for site_url in $urls
        do

                echo "$site_url"
                echo "$site_url" >> "$2"

         done

done
