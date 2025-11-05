#!/bin/bash

################################################################################
# LLM Observatory - Cron Job Examples
################################################################################
#
# Description:
#   Example cron job configurations for automated backups and maintenance.
#   Copy the desired cron jobs to your crontab.
#
# Installation:
#   1. Edit this file to set correct paths
#   2. Make scripts executable: chmod +x /path/to/scripts/*.sh
#   3. Add to crontab: crontab -e
#   4. Copy relevant cron entries from below
#
# Important Notes:
#   - Ensure scripts have execute permissions
#   - Set up .env file with database credentials
#   - Configure AWS credentials for S3 backups
#   - Set up email notifications if desired
#   - Monitor /var/log/syslog for cron execution
#
################################################################################

# Set these variables to match your installation
PROJECT_ROOT="/workspaces/llm-observatory"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
BACKUP_DIR="${PROJECT_ROOT}/backups"

# Email for notifications
NOTIFICATION_EMAIL="admin@example.com"

################################################################################
# Cron Job Examples
################################################################################

# IMPORTANT: Add these lines to your crontab with: crontab -e
# Format: minute hour day month dayofweek command

#------------------------------------------------------------------------------
# Daily Full Backups
#------------------------------------------------------------------------------

# Daily local backup at 2:00 AM
# Retention: 30 days (default)
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v 2>&1 | logger -t llm-backup

# Daily S3 backup at 2:30 AM (production)
# Upload to S3 with encryption
# 30 2 * * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b production-backups -e -v 2>&1 | logger -t llm-s3-backup

# Daily backup with custom retention (60 days)
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -r 60 -v 2>&1 | logger -t llm-backup

# Daily backup to custom directory
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -d /mnt/backups -v 2>&1 | logger -t llm-backup

#------------------------------------------------------------------------------
# Hourly Backups (for critical systems)
#------------------------------------------------------------------------------

# Hourly backup (every hour at :00)
# Keep only last 24 backups (1 day retention)
# 0 * * * * /workspaces/llm-observatory/scripts/backup.sh -r 1 -d /mnt/backups/hourly -v 2>&1 | logger -t llm-hourly-backup

# Every 6 hours
# 0 */6 * * * /workspaces/llm-observatory/scripts/backup.sh -v 2>&1 | logger -t llm-backup

#------------------------------------------------------------------------------
# Weekly Backup Verification
#------------------------------------------------------------------------------

# Weekly verification on Sunday at 3:00 AM
# Verifies the latest backup by restoring to test database
# 0 3 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify

# Weekly S3 backup verification
# 30 3 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -s -b production-backups -v 2>&1 | logger -t llm-verify-s3

# Verify specific backup and keep test database for inspection
# 0 3 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh --keep-test-db -v 2>&1 | logger -t llm-verify

#------------------------------------------------------------------------------
# Monthly Long-term Archival
#------------------------------------------------------------------------------

# First day of month at 1:00 AM - create monthly archive to Glacier
# 0 1 1 * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b monthly-archives -s GLACIER -p monthly/ -e -v 2>&1 | logger -t llm-monthly-archive

# Monthly archive to Deep Archive (lowest cost, 12h retrieval)
# 0 1 1 * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b long-term-archives -s DEEP_ARCHIVE -p archives/$(date +\%Y)/ -e -v 2>&1 | logger -t llm-archive

#------------------------------------------------------------------------------
# Combined Backup Strategy (Recommended)
#------------------------------------------------------------------------------

# 1. Hourly local backups (1 day retention)
# 0 * * * * /workspaces/llm-observatory/scripts/backup.sh -d /var/backups/llm/hourly -r 1 -v 2>&1 | logger -t llm-hourly

# 2. Daily local backups (30 days retention) - 2:00 AM
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -d /var/backups/llm/daily -r 30 -v 2>&1 | logger -t llm-daily

# 3. Daily S3 backup (Standard-IA, lifecycle manages retention) - 3:00 AM
# 0 3 * * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-backups -p daily/ -e -v 2>&1 | logger -t llm-s3-daily

# 4. Weekly backup verification - Sunday 4:00 AM
# 0 4 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify

# 5. Monthly archive to Glacier - 1st of month, 5:00 AM
# 0 5 1 * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-archives -s GLACIER -p monthly/$(date +\%Y-\%m)/ -e -v 2>&1 | logger -t llm-monthly

#------------------------------------------------------------------------------
# WAL Archiving for Point-in-Time Recovery (PITR)
#------------------------------------------------------------------------------

# Note: WAL archiving is configured in PostgreSQL configuration (postgresql.conf)
# See docs/disaster-recovery.md for setup instructions
#
# Example PostgreSQL configuration:
# wal_level = replica
# archive_mode = on
# archive_command = '/workspaces/llm-observatory/scripts/archive_wal.sh %p %f'
#
# The archive command runs automatically when PostgreSQL rotates WAL files
# No cron job needed for WAL archiving

#------------------------------------------------------------------------------
# Maintenance Tasks
#------------------------------------------------------------------------------

# Daily VACUUM ANALYZE at 1:00 AM (off-peak hours)
# 0 1 * * * PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -d llm_observatory -c "VACUUM ANALYZE;" 2>&1 | logger -t llm-vacuum

# Weekly VACUUM FULL on Sunday at 2:00 AM (requires downtime)
# 0 2 * * 0 PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U postgres -d llm_observatory -c "VACUUM FULL;" 2>&1 | logger -t llm-vacuum-full

# Daily cleanup of old WAL files (if not using WAL archiving)
# 0 0 * * * find /var/lib/postgresql/data/pg_wal -name "*.old" -mtime +7 -delete 2>&1 | logger -t llm-wal-cleanup

################################################################################
# Email Notifications Setup
################################################################################

# Install mailutils for email notifications:
# sudo apt-get install mailutils

# Configure MAILTO in crontab:
# MAILTO=admin@example.com
#
# Or use a wrapper script for email notifications:
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh 2>&1 | mail -s "Backup Report" admin@example.com

################################################################################
# Monitoring Backup Success
################################################################################

# Check if backup ran successfully today
# 0 12 * * * [ $(find /var/backups/llm/daily -name "*.sql.gz" -mtime -1 | wc -l) -eq 0 ] && echo "WARNING: No backup created in last 24 hours" | mail -s "Backup Alert" admin@example.com

# Check S3 backup age
# 0 12 * * * aws s3 ls s3://prod-backups/daily/ --recursive | sort | tail -1 | awk '{if ((systime() - mktime(substr($1,1,4)" "substr($1,6,2)" "substr($1,9,2)" 00 00 00")) > 86400) print "WARNING: Latest S3 backup is older than 24 hours"}' | mail -s "S3 Backup Alert" admin@example.com

################################################################################
# Docker-Specific Cron Jobs
################################################################################

# If running PostgreSQL in Docker, use docker exec:
# 0 2 * * * docker exec llm-observatory-db pg_dump -U postgres llm_observatory | gzip > /backups/llm_$(date +\%Y\%m\%d).sql.gz 2>&1 | logger -t llm-docker-backup

# Backup using the backup script with Docker database:
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -c /workspaces/llm-observatory/.env -v 2>&1 | logger -t llm-backup

################################################################################
# Testing Cron Jobs
################################################################################

# To test a cron job, run it manually first:
# /workspaces/llm-observatory/scripts/backup.sh -v
#
# To test cron timing, use a temporary cron entry:
# */5 * * * * echo "Cron test: $(date)" >> /tmp/cron-test.log
#
# Monitor cron execution:
# tail -f /var/log/syslog | grep CRON

################################################################################
# Cron Best Practices
################################################################################

# 1. Always use absolute paths in cron jobs
# 2. Redirect output to logger or a log file
# 3. Set up email notifications for failures
# 4. Test scripts manually before adding to cron
# 5. Stagger backup times to avoid resource contention
# 6. Monitor backup success regularly
# 7. Verify backups periodically
# 8. Document your backup schedule
# 9. Keep retention policies aligned with business requirements
# 10. Review and update cron jobs regularly

################################################################################
# Example Crontab Entry
################################################################################

# Here's a complete example crontab for LLM Observatory:
#
# SHELL=/bin/bash
# PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# MAILTO=admin@example.com
#
# # LLM Observatory Automated Backups
# # Daily full backup at 2:00 AM
# 0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v 2>&1 | logger -t llm-backup
#
# # Daily S3 backup at 3:00 AM
# 0 3 * * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-backups -e -v 2>&1 | logger -t llm-s3-backup
#
# # Weekly verification on Sunday at 4:00 AM
# 0 4 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify
#
# # Monthly archive to Glacier on 1st at 5:00 AM
# 0 5 1 * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-archives -s GLACIER -p monthly/ -e -v 2>&1 | logger -t llm-monthly

################################################################################
# Systemd Timers (Alternative to Cron)
################################################################################

# For systems using systemd, you can use timers instead of cron.
# See docs/disaster-recovery.md for systemd timer examples.

echo "This file contains cron job examples. Do not execute directly."
echo "Copy the desired cron entries to your crontab with: crontab -e"
exit 0
