FROM --platform=$TARGETOS/$TARGETARCH debian:stable-slim

LABEL author="Matthew Penner" maintainer="matthew@pterodactyl.io"

LABEL org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL org.opencontainers.image.licenses=MIT

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    netcat-traditional \
    tar unzip git curl \
    ca-certificates \
    gcc g++ gdb \
    net-tools \
    iproute2 \
    tzdata \
    telnet \
    libc6:i386 \
    libgcc-s1:i386 \
    libstdc++6:i386 \
    lib32gcc-s1 \
    libgcc1 \
    libcurl4-gnutls-dev:i386 \
    libssl3:i386 \
    libcurl4:i386 \
    lib32tinfo6 \
    lib32z1 \
    lib32stdc++6 \
    libncurses6:i386 \
    libtinfo6:i386 \
    libcurl3-gnutls:i386 \
    libsdl2-2.0-0:i386 \
    libsdl1.2debian \
    libfontconfig1 && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -d /home/container container

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/bin/bash", "/entrypoint.sh" ]
