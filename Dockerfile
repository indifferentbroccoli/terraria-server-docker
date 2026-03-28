# BUILD THE SERVER IMAGE
FROM --platform=linux/amd64 ubuntu:22.04

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    curl \
    gettext-base \
    procps \
    libsdl2-2.0-0 \
    lib32gcc-s1 \
    libicu70 \
    xvfb \
    ca-certificates \
    && wget -q -O /tmp/steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    && mkdir -p /usr/local/steamcmd \
    && tar -xzf /tmp/steamcmd.tar.gz -C /usr/local/steamcmd \
    && rm /tmp/steamcmd.tar.gz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

LABEL maintainer="support@indifferentbroccoli.com" \
      name="indifferentbroccoli/terraria-server-docker" \
      github="https://github.com/indifferentbroccoli/terraria-server-docker" \
      dockerhub="https://hub.docker.com/r/indifferentbroccoli/terraria-server-docker"

RUN useradd -m -s /bin/bash terraria

ENV GAME_ID=terraria \
    HOME=/home/terraria \
    GAME_PORT=7777 \
    SERVER_IP=0.0.0.0 \
    TERRARIA_VERSION=1455 \
    TMODLOADER_ENABLED=false \
    TMODLOADER_VERSION=latest \
    WORKSHOP_MODS=

COPY ./scripts /home/terraria/server/

COPY branding /branding

RUN mkdir -p /terraria/worlds && \
    chown -R terraria:terraria /home/terraria /terraria && \
    chmod +x /home/terraria/server/*.sh

WORKDIR /home/terraria/server

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=5m \
            --retries=3 \
            CMD /home/terraria/server/healthcheck.sh

EXPOSE 7777/tcp

ENTRYPOINT ["/home/terraria/server/init.sh"]
