#!/bin/bash
# dev-init.sh
# Thin wrapper that runs before the real Aspen entrypoint.
# Handles dev-only concerns (currently: toggling xdebug on/off, patching
# the symlink block in start.sh for bind-mount setups).
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
# Patch start.sh to skip symlink creation but keep content migration
# ---------------------------------------------------------------------------
# In a bind-mount dev setup, code/web/files, code/web/fonts, and
# code/web/images already exist in the repo and should stay there.
# The entrypoint's symlink block moves content into /data (good) but then moves
# files and replaces the real directories with symlinks (bad — causes Git to see
# spurious changes in the host repo).
# The start.sh script even has a FIXME comment acknowledging this is wrong.
# We patch in-place inside the container at runtime — the built image is
# untouched and the patch re-applies on every container restart.
sed -i '/# Remove source only if/,/ln -sfn.*dest.*source/d' /start.sh
sed -i '/log_info "Created symlink/d' /start.sh
sed -i 's/mv "\$source"\/\* "\$dest"\//cp -r "$source"\/* "$dest"\//' /start.sh
echo "[DEV] Patched start.sh to preserve bind-mounted directories"

# ---------------------------------------------------------------------------
# Run a patched copy of createDirs.php
# ---------------------------------------------------------------------------
# createDirs.php runs `chmod -R 755` on code/web and sites/, which marks every
# file in the bind-mounted repo executable (thousands of Git mode changes).
# It lives in the bind mount, so we patch a copy in /tmp rather than the repo.
# Capital X keeps directories traversable without making regular files executable.
PATCH_DIR="/tmp/aspen-dev-patched"
mkdir -p "$PATCH_DIR/scripts" "$PATCH_DIR/logger"
cp /usr/local/aspen-discovery/docker/files/scripts/createDirs.php "$PATCH_DIR/scripts/"
cp /usr/local/aspen-discovery/docker/files/logger/DockerLogger.php "$PATCH_DIR/logger/"
sed -i -E "/aspenDir\/(code\/web|sites)/ s/'755'/'u=rwX,go=rX'/" "$PATCH_DIR/scripts/createDirs.php"
if grep -q "u=rwX" "$PATCH_DIR/scripts/createDirs.php"; then
    echo "[DEV] Using patched createDirs.php (no execute bit on repo files)"
else
    echo "[DEV] WARNING: createDirs.php patch did not apply; upstream script may have changed"
fi
sed -i "s#php createDirs.php#php $PATCH_DIR/scripts/createDirs.php#" /start.sh

# ---------------------------------------------------------------------------
# Hand off to the real Aspen entrypoint
# ---------------------------------------------------------------------------
exec /entrypoint.sh "$@"
