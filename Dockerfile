FROM ubuntu:22.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl xmlstarlet jq bash \
    && rm -rf /var/lib/apt/lists/*
COPY extract_yoast_sitemap.sh /usr/local/bin/
WORKDIR /data
ENTRYPOINT ["bash", "/usr/local/bin/extract_yoast_sitemap.sh"]
