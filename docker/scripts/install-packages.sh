#!/bin/bash
set -e

# Update package lists
apt-get update

# Install system dependencies
apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    tmux \
    screen \
    htop \
    tree \
    jq \
    unzip \
    build-essential \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    sqlite3 \
    postgresql-client \
    redis-tools \
    net-tools \
    iputils-ping \
    telnet \
    netcat-openbsd \
    rsync \
    zip

# Clean up to reduce image size
rm -rf /var/lib/apt/lists/*
apt-get clean