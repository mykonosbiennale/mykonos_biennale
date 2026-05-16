#!/bin/bash
set -e

echo "=== Syncing uploads to Fly.io ==="
echo ""
echo "This script uploads your local uploads to the Fly.io persistent volume."
echo "It creates a tarball locally, copies it to the machine, and extracts it there."
echo ""

# Create tarball of uploads (excluding hidden files like .DS_Store)
echo "Creating tarball of priv/static/uploads/..."
tar czf /tmp/uploads.tar.gz -C priv/static uploads/ --exclude='.DS_Store'

TARBALL_SIZE=$(du -sh /tmp/uploads.tar.gz | cut -f1)
echo "Tarball size: $TARBALL_SIZE"
echo ""

# Upload to the machine
echo "Uploading tarball to Fly.io machine..."
fly sftp put /tmp/uploads.tar.gz /tmp/uploads.tar.gz

# Extract on the remote machine
echo "Extracting tarball on remote machine..."
fly ssh console -C "mkdir -p /data/uploads && tar xzf /tmp/uploads.tar.gz -C /data/ && rm /tmp/uploads.tar.gz"

# Clean up local tarball
rm /tmp/uploads.tar.gz

echo ""
echo "=== Done! ==="
echo "Uploads are now in /data/uploads/ on the Fly.io volume."
echo "Verify with: fly ssh console -C 'ls /data/uploads/ | head'"