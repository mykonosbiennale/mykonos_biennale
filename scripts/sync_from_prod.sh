#!/bin/bash
set -e

APP_NAME="mykonos-biennale"

echo "=== Sync production data to local dev ==="
echo ""
echo "This script dumps the production database, downloads it, and restores"
echo "it into your local dev database."
echo ""

# Step 1: Dump production DB to JSON on the remote machine
echo "Dumping production database..."
fly ssh console -C "cd /app && mix app.dump --output /tmp/data_dump.json" -a "$APP_NAME"

# Step 2: Download the dump file
echo "Downloading dump file..."
fly sftp get /tmp/data_dump.json priv/repo/data_dump_from_prod.json -a "$APP_NAME"

# Step 3: Clean up the remote dump
fly ssh console -C "rm /tmp/data_dump.json" -a "$APP_NAME"

# Step 4: Backup local DB
LOCAL_DB="mykonos_biennale_dev.db"
if [ -f "$LOCAL_DB" ]; then
  BACKUP="${LOCAL_DB}.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backing up local DB to $BACKUP..."
  cp "$LOCAL_DB" "$BACKUP"
fi

# Step 5: Restore into local DB
echo "Restoring production data into local dev database..."
mix app.restore --input priv/repo/data_dump_from_prod.json

# Step 6: Clean up
rm -f priv/repo/data_dump_from_prod.json

echo ""
echo "=== Done! ==="
echo "Local dev database now contains production data."
if [ -n "$BACKUP" ]; then
  echo "Backup saved to: $BACKUP"
  echo "To rollback: cp $BACKUP $LOCAL_DB"
fi