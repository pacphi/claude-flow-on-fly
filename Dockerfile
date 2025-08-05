FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale to prevent locale warnings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Copy all Docker scripts and configurations
COPY docker/ /docker/
RUN chmod +x /docker/scripts/*.sh /docker/templates/*.sh

# Install system packages
RUN /docker/scripts/install-packages.sh

# Create developer user and configure system
RUN /docker/scripts/setup-user.sh

# Configure SSH daemon
RUN mkdir -p /var/run/sshd && \
    cp /docker/config/sshd_config /etc/ssh/sshd_config && \
    cp /docker/config/developer-sudoers /etc/sudoers.d/developer

# Setup bash environment for developer user
RUN /docker/scripts/setup-bashrc.sh

# Install NVM and configure Git for developer user
RUN /docker/scripts/install-nvm.sh

# Create welcome script for developer user
RUN /docker/scripts/create-welcome.sh

# Copy vm-configure.sh script to workspace
COPY scripts/vm-configure.sh /workspace/scripts/vm-configure.sh
RUN chown developer:developer /workspace/scripts/vm-configure.sh && \
    chmod +x /workspace/scripts/vm-configure.sh

# Copy health check script
RUN cp /docker/templates/health-check.sh /health.sh && \
    chmod +x /health.sh

# Expose SSH port
EXPOSE 22

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /health.sh

# Use startup script as entry point
CMD ["/docker/scripts/entrypoint.sh"]