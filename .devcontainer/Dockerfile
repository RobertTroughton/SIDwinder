FROM mcr.microsoft.com/devcontainers/cpp:debian

# Install additional tools including Java
RUN apt-get update && apt-get -y install --no-install-recommends \
    cmake \
    build-essential \
    ninja-build \
    gdb \
    cppcheck \
    valgrind \
    clang \
    lldb \
    llvm \
    default-jdk \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Ensure permissions are set correctly
RUN mkdir -p /workspaces && \
    chmod -R 755 /workspaces

# Add a script that will run every time the container starts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Run as non-root user by default
USER $USERNAME

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]