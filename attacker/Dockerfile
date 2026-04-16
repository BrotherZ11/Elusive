FROM kasmweb/core-kali-rolling:1.18.0

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      dnsutils \
      ffuf \
      firefox-esr \
      gobuster \
      hydra \
      iproute2 \
      iputils-ping \
      ldap-utils \
      net-tools \
      netcat-openbsd \
      nmap \
      openssh-client \
      openssh-server \
      sqlmap \
      sshpass \
      wget && \
    mkdir -p /run/sshd /var/run/sshd && \
    rm -rf /var/lib/apt/lists/*
