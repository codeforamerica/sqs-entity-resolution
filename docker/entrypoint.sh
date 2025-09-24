#!/bin/bash

# Execute scripts in /entrypoint.d/
for f in /entrypoint.d/*; do
    case "$f" in
        *.sh)     echo "$0: running $f"; . "$f" ;;
        *)        echo "$0: ignoring $f" ;;
    esac
    echo
done

# Execute the main command passed to the script.
echo "Running as user: $(whoami)"
echo "Executing command: $@"
exec "$@"
