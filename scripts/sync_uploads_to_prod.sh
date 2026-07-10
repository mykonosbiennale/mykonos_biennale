#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-admin.mykonosbiennale.com}"
REMOTE_USER="${REMOTE_USER:-ubuntu}"
REMOTE_UPLOADS_DIR="${REMOTE_UPLOADS_DIR:-/data/uploads}"

echo "=== Syncing uploads to production ($REMOTE_HOST) ==="
echo ""
echo "Uploading priv/static/uploads/ to $REMOTE_HOST:$REMOTE_UPLOADS_DIR/"
echo ""

rsync -avz --exclude='.DS_Store' \
  priv/static/uploads/ \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_UPLOADS_DIR/"

echo ""
echo "=== Done! ==="
echo "Verify with: ssh $REMOTE_USER@$REMOTE_HOST 'ls $REMOTE_UPLOADS_DIR/ | head'"
