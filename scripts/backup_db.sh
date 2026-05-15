#!/bin/bash
# Backup the Mykonos Biennale development database
# Usage: ./scripts/backup_db.sh [label]

set -e

DB="mykonos_biennale_dev.db"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUPS_DIR="$PROJECT_DIR/backups"

mkdir -p "$BACKUPS_DIR"

LABEL="${1:-$(date +%Y%m%d_%H%M%S)}"
BACKUP_FILE="$BACKUPS_DIR/${DB%.db}_${LABEL}.db"

if [ ! -f "$PROJECT_DIR/$DB" ]; then
  echo "ERROR: Database not found at $PROJECT_DIR/$DB"
  exit 1
fi

# Checkpoint WAL on the live DB first, then copy
sqlite3 "$PROJECT_DIR/$DB" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
cp "$PROJECT_DIR/$DB" "$BACKUP_FILE"

# Count records for verification
ENTITIES=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM entities;")
RELATIONSHIPS=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM relationships;")
MEDIA=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM media;")

echo "Backup created: $BACKUP_FILE"
echo "  Entities: $ENTITIES"
echo "  Relationships: $RELATIONSHIPS"
echo "  Media: $MEDIA"
