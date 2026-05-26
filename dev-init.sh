#!/bin/bash
# dev-init.sh
# Thin wrapper that runs before the real Aspen entrypoint.
# Handles dev-only concerns (currently: toggling xdebug on/off).
# Mounted at /dev-init.sh inside the container — does not conflict with
# the real /entrypoint.sh that the image builds in.

set -e

# ---------------------------------------------------------------------------
# Xdebug toggle
# ---------------------------------------------------------------------------
XDEBUG_SYMLINK="/etc/php/8.4/fpm/conf.d/20-xdebug.ini"
XDEBUG_SOURCE="/etc/php/8.4/mods-available/xdebug.ini"

if [ "${XDEBUG_ENABLE}" = "true" ]; then
    if ! php -m | grep -q xdebug 2>/dev/null; then
        apt-get install -yq php8.4-xdebug 2>/dev/null || true
    fi
    ln -sf "$XDEBUG_SOURCE" "$XDEBUG_SYMLINK" 2>/dev/null || true
    echo "[DEV] Xdebug enabled — connecting to ${XDEBUG_CLIENT_HOST}:${XDEBUG_CLIENT_PORT}"
else
    rm -f "$XDEBUG_SYMLINK" 2>/dev/null || true
    echo "[DEV] Xdebug disabled"
fi

# ---------------------------------------------------------------------------
# Hand off to the real Aspen entrypoint
# ---------------------------------------------------------------------------
exec /entrypoint.sh "$@"
