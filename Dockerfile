FROM debian:bookworm-slim

LABEL maintainer="Leo"

ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /root

# Install essential build tools/dependencies
# defined in setup.sh: xvfb dnsutils nmap python3 python3-pip curl wget unzip git libfreetype6 libfontconfig1
# plus chromium for gowitness/katana
RUN apt-get update && apt-get install -y \
    tzdata \
    curl wget unzip git build-essential libssl-dev pkg-config \
    python3 python3-pip python3-venv \
    dnsutils nmap \
    libfreetype6 libfontconfig1 \
    chromium \
    xvfb \
    shellcheck \
    bats \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copy scripts and config
COPY setup.sh /root
COPY BugBountyScanner.sh /root
COPY utils /root/utils
COPY dist /root/dist
COPY tests /root/tests
COPY .env.example /root

# Golang & Path Setup (Environment variables)
ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=$PATH:/root/go/bin:/usr/local/go/bin:/root/.cargo/bin
ENV GO111MODULE=on

# Run setup
RUN chmod +x /root/BugBountyScanner.sh /root/setup.sh
RUN /root/setup.sh
