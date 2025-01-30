#!/bin/bash

# Pull style backup
# -----------------
#
# Should be initialized from the backup server and thus needs ssh-access to the
# app-server (local server)
# On the backup server, do
# ssh-keygen -t ed25519
# ssh-copy-id -i ~/.ssh/id_ed25519.pub local_user@local_host
#
# Test the connection
# ssh local_user@local_host
#
# Add the script to crontab
# crontab -e
# 0 2 * * * /path/to/backup.sh >> /var/log/dbkk-library-backup.log 2>&1

# Configuration
LOCAL_USER="local_user"              # Local server username
LOCAL_HOST="local_host"              # Local server hostname or IP
LOCAL_UPLOADS_DIR="/path/to/uploads" # Local uploads directory
LOCAL_DB_PATH="/path/to/database.db" # Local SQLite database path
BACKUP_DIR="/path/to/remote/backups" # Remote backup directory
TIMESTAMP=$(date +"%Y%m%d%H%M%S")   # Timestamp for backup files

echo "$(date): Backup started"
# Create remote backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Compress the uploads directory on the local server
UPLOADS_ARCHIVE="/tmp/uploads_$TIMESTAMP.tar.gz"
ssh "$LOCAL_USER@$LOCAL_HOST" "tar -czf $UPLOADS_ARCHIVE -C $LOCAL_UPLOADS_DIR ."

# Check if the uploads archive has changed compared to the latest backup
LATEST_UPLOADS_BACKUP=$(ls -t "$BACKUP_DIR"/uploads_*.tar.gz 2>/dev/null | head -n 1)
if [ -n "$LATEST_UPLOADS_BACKUP" ]; then
  # Compare the new archive with the latest backup
  ssh "$LOCAL_USER@$LOCAL_HOST" "cmp --silent $UPLOADS_ARCHIVE <(cat $LATEST_UPLOADS_BACKUP)"
  if [ $? -eq 0 ]; then
    echo "No changes in uploads directory. Skipping transfer."
    ssh "$LOCAL_USER@$LOCAL_HOST" "rm $UPLOADS_ARCHIVE"
  else
    echo "Changes detected in uploads directory. Transferring new backup."
    scp "$LOCAL_USER@$LOCAL_HOST:$UPLOADS_ARCHIVE" "$BACKUP_DIR/uploads_$TIMESTAMP.tar.gz"
    ssh "$LOCAL_USER@$LOCAL_HOST" "rm $UPLOADS_ARCHIVE"
  fi
else
  echo "No existing uploads backup found. Transferring new backup."
  scp "$LOCAL_USER@$LOCAL_HOST:$UPLOADS_ARCHIVE" "$BACKUP_DIR/uploads_$TIMESTAMP.tar.gz"
  ssh "$LOCAL_USER@$LOCAL_HOST" "rm $UPLOADS_ARCHIVE"
fi

# Backup the SQLite database
DB_BACKUP="/tmp/db_$TIMESTAMP.db"
ssh "$LOCAL_USER@$LOCAL_HOST" "sqlite3 $LOCAL_DB_PATH '.backup $DB_BACKUP'"

# Check if the database backup has changed compared to the latest backup
LATEST_DB_BACKUP=$(ls -t "$BACKUP_DIR"/db_*.db.gz 2>/dev/null | head -n 1)
if [ -n "$LATEST_DB_BACKUP" ]; then
  # Compare the new backup with the latest backup
  ssh "$LOCAL_USER@$LOCAL_HOST" "cmp --silent $DB_BACKUP <(zcat $LATEST_DB_BACKUP)"
  if [ $? -eq 0 ]; then
    echo "No changes in database. Skipping transfer."
    ssh "$LOCAL_USER@$LOCAL_HOST" "rm $DB_BACKUP"
  else
    echo "Changes detected in database. Transferring new backup."
    scp "$LOCAL_USER@$LOCAL_HOST:$DB_BACKUP" "$BACKUP_DIR/db_$TIMESTAMP.db"
    gzip "$BACKUP_DIR/db_$TIMESTAMP.db"
    ssh "$LOCAL_USER@$LOCAL_HOST" "rm $DB_BACKUP"
  fi
else
  echo "No existing database backup found. Transferring new backup."
  scp "$LOCAL_USER@$LOCAL_HOST:$DB_BACKUP" "$BACKUP_DIR/db_$TIMESTAMP.db"
  gzip "$BACKUP_DIR/db_$TIMESTAMP.db"
  ssh "$LOCAL_USER@$LOCAL_HOST" "rm $DB_BACKUP"
fi

# Optional: Delete backups older than 7 days
find "$BACKUP_DIR" -type f -mtime +7 -exec rm {} \;

echo "Pull backup completed."
