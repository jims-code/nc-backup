# nc-backup
Bash script for creating backups of a Nextcloud Docker Installation.

# Current Version
This script creates Backups of
 - the Docker volumes
 - MariaDB (mysqldump)

Version 0.0.1

Usage
```Shell
docker-backup.sh <BACKUP_DIRECTORY>
                 <BACKUP_DIRECTORY> is optional.
```

# Planned Version
Bash scripts for creating backups of a Nexcloud Docker instance on a remote machine:
- A Scheduler on a centralized backup server (e.g. cron on your NAS) initializes the backup.
- A ssh connection to the Nextcloud machine will be established in order to create the database backup.
- The DB backup file and the Docker volumes will be copied by rsync to the centralized backup server.

# Credits
Based on https://github.com/DecaTec/Nextcloud-Backup-Restore/blob/master/NextcloudBackup.sh
Thank you very much!
