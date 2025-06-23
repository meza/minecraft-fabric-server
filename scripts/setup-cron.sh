#!/usr/bin/env bash

# Configure cron schedules for duply backups
USER=minecraft

BACKUP_CRON="${CRON_BACKUP:-0 * * * *}"
FULL_CRON="${CRON_FULL:-30 05 * * *}"
PURGE_CRON="${CRON_PURGE:-15 08 */7 * *}"

add_job() {
  local schedule="$1"
  local command="$2"
  if [ -n "$schedule" ]; then
    (crontab -u "$USER" -l 2>/dev/null; echo "$schedule $command") \
      | sort - | uniq - | crontab -u "$USER" -
  fi
}

add_job "$PURGE_CRON" "/usr/bin/duply minecraft purgeAuto --force --allow-source-mismatch 2> /var/log/duply.err 1> /var/log/duply.log"
add_job "$BACKUP_CRON" "/usr/bin/duply minecraft backup now --allow-source-mismatch 2> /var/log/duply.error 1> /var/log/duply.log"
add_job "$FULL_CRON" "/usr/bin/duply minecraft full now --allow-source-mismatch 2> /var/log/duply.error 1> /var/log/duply.log"

echo "Crontab prepared"
