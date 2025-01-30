#!/bin/bash

# Configuration
BACKUP_DIR="/path/to/remote/backups" # Remote backup directory
RESTORE_UPLOADS_DIR="/path/to/restore/uploads" # Directory to restore uploads
RESTORE_DB_PATH="/path/to/restore/database.db" # Path to restore the SQLite database

# Find the latest uploads backup
LATEST_UPLOADS_BACKUP=$(ls -t "$BACKUP_DIR"/uploads_*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST_UPLOADS_BACKUP" ]; then
  echo "No uploads backup found in $BACKUP_DIR."
  exit 1
fi

# Find the latest database backup
LATEST_DB_BACKUP=$(ls -t "$BACKUP_DIR"/db_*.db.gz 2>/dev/null | head -n 1)
if [ -z "$LATEST_DB_BACKUP" ]; then
  echo "No database backup found in $BACKUP_DIR."
  exit 1
fi

# Restore the uploads directory
echo "Restoring uploads from $LATEST_UPLOADS_BACKUP..."
mkdir -p "$RESTORE_UPLOADS_DIR"
tar -xzf "$LATEST_UPLOADS_BACKUP" -C "$RESTORE_UPLOADS_DIR"

# Restore the SQLite database
echo "Restoring database from $LATEST_DB_BACKUP..."
zcat "$LATEST_DB_BACKUP" > "$RESTORE_DB_PATH"

echo "Restore completed successfully."
