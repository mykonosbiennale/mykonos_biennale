#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-admin.mykonosbiennale.com}"
REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/mykonos_biennale}"
REMOTE_UPLOADS_DIR="${REMOTE_UPLOADS_DIR:-/data/uploads}"

echo "=== Sync production data to local dev ==="
echo ""
echo "This script:"
echo "  1. Downloads production uploads (images) to priv/static/uploads/"
echo "  2. Downloads production generated media (thumbnails) to priv/static/media/"
echo ""

# Step 1: Sync uploads (original image files)
echo "Syncing uploads from $REMOTE_HOST:$REMOTE_UPLOADS_DIR/..."
rsync -avz --exclude='.DS_Store' \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_UPLOADS_DIR/" \
  priv/static/uploads/

# Step 2: Sync generated media (thumbnails) if it exists on the remote
echo ""
echo "Syncing generated media from $REMOTE_HOST:$REMOTE_APP_DIR/priv/static/media/..."
rsync -avz --exclude='.DS_Store' \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR/priv/static/media/" \
  priv/static/media/ 2>/dev/null || echo "(media dir not found on remote — thumbnails will be generated locally)"

echo ""
echo "=== Done! ==="
echo "Local uploads: priv/static/uploads/"
echo "Local media:   priv/static/media/"
