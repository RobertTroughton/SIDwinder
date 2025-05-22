#!/bin/bash

# Need to run as root to change permissions
if [ "$(id -u)" -eq 0 ]; then
    # Fix ownership of the workspace directory
    echo "Fixing workspace permissions..."
    find /workspaces -path '*/\.git/*' -prune -o -exec sudo chown vscode:vscode {} \;

    # If we're running as root but should be running as vscode
    # Re-execute the entrypoint script as vscode
    exec sudo -u vscode /usr/local/bin/entrypoint.sh "$@"
else
    echo "Running as vscode user..."
fi

# Execute the command passed to docker run
exec "$@"