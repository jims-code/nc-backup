#!/bin/bash

# Bash script for creating backups of a Nextcloud Docker Installation-
# This script creates Backups of
# - the Docker Volumes
# - MariaDB (mysqldump)
#
# Version 0.0.1
#
# Based on https://github.com/DecaTec/Nextcloud-Backup-Restore/blob/master/NextcloudBackup.sh
#
# Usage: docker-backup.sh <BACKUP_DIRECTORY>
# 	     <BACKUP_DIRECTORY> is optional.

################################################
# Parameter (please change for your own needs) #
################################################
#
# Logfile for this script (please set write permissions for the backup user!)
LOGFILE="/home/docker/log/docker-backup.log"
#
# Location of the docker-compose.yml file
DOCKER_COMPOSE_DIR="/home/docker"
#
# Backup will include files in the following Ditrectory  
DOCKER_VOLUME_DIR='/var/lib/docker/volumes'
#
# Backup Target
BACKUP_DEFAULT_DIR='/home/backup'
DOCKER_VOLUME_BACKUP_FILENAME='docker-volumes.tar.gz'
DB_BACKUP_FILENAME='mariadb.sql'
#
# Number of Backups to keep
MAX_NR_OF_BACKUPS=3 # 0=keep all Backups.
#
# User that is allowed to use the commands docker and docker-compose
DOCKER_USER='mydockeruser'
#
# Docker instance names (which are specified in the docker-compose.yml file)
DOCKER_NEXTCLOUD_INSTANCE='nextcloud'
DOCKER_MARIADB_INSTANCE='db'
#
# MariaDB Root Password
MYSQL_ROOT_PASSWORD='my-db-password'
################################################
# End of Parameters                            #
################################################

# Writing Logfile
# logwrite <message for logfile> <errorcode (0=no error)>
logwrite () {
	echo "["`date '+%Y-%m-%d %H.%M.%S'`"] [docker-backup.sh] $1 [Errorcode $2]" >> $LOGFILE
	if [ $? -ne 0 ]; then 
		echo "ERROR: Cannot write Logfile $LOGFILE!"
		exit 10
	fi
	# Stop Script if an error occurred
	if [ $2 -ne 0 ]; then
		exit $2
	fi
	}

# Define Backup Directory
BACKUP_MAIN_DIR=$1
if [ -z "$BACKUP_MAIN_DIR" ]; then
	# The directory where you store the Nextcloud backups (when not specified by args)
    BACKUP_MAIN_DIR=$BACKUP_DEFAULT_DIR
fi
# The actual directory of the current backup - this is a subdirectory of the main directory above with a timestamp
CURRENT_DATE=$(date +"%Y-%m-%d_%H.%M.%S")
BACKUP_DIR="${BACKUP_MAIN_DIR}/${CURRENT_DATE}"
logwrite "### Start Backup to directory: $BACKUP_DIR" 0
cd "$DOCKER_COMPOSE_DIR"

function DisableMaintenanceMode() {
	sudo -u "${DOCKER_USER}" docker-compose exec --user www-data $DOCKER_NEXTCLOUD_INSTANCE php occ maintenance:mode --off
	logwrite "Nextcloud: Disabling Maintenance Mode." $?
}

# Capture CTRL+C
trap CtrlC INT

function CtrlC() {
	logwrite "Backup cancelled." 0
	DisableMaintenanceMode
	exit 1
}

# Check for root
if [ "$(id -u)" != "0" ]; then
	logwrite "ERROR: This script has to be run as root!" 2
fi

# Check if backup dir already exists
if [ ! -d "${BACKUP_DIR}" ]; then
	mkdir -p "${BACKUP_DIR}"
	logwrite "Creating backup directory ${BACKUP_DIR}" $?
else
	logwrite "ERROR: The backup directory ${BACKUP_DIR} already exists!" 3
fi

# Set maintenance mode
sudo -u "${DOCKER_USER}" docker-compose exec --user www-data $DOCKER_NEXTCLOUD_INSTANCE php occ maintenance:mode --on
logwrite "Nextcloud: Enabling Maintenance Mode" $?

# Backup Docker Volume directory
tar -cpzf "${BACKUP_DIR}/${DOCKER_VOLUME_BACKUP_FILENAME}" -C "${DOCKER_VOLUME_DIR}" .
logwrite "Creating backup of Docker Volume directory ${DOCKER_VOLUME_DIR} to ${BACKUP_DIR}/${DOCKER_VOLUME_BACKUP_FILENAME}." $?

# Backup DB
sudo -u "${DOCKER_USER}" docker-compose exec --user root $DOCKER_MARIADB_INSTANCE sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > "${BACKUP_DIR}/${DB_BACKUP_FILENAME}"
logwrite "Backup MariaDB to ${BACKUP_DIR}/${DB_BACKUP_FILENAME}." $?

# Disable maintenance mode
DisableMaintenanceMode

# Delete old backups
if [ ${MAX_NR_OF_BACKUPS} != 0 ]; then
	NUMBER_OF_BACKUPS=$(ls -l ${BACKUP_MAIN_DIR} | grep -c ^d)
	echo 100
	if [ $NUMBER_OF_BACKUPS -gt $MAX_NR_OF_BACKUPS ]; then
		logwrite "Removing old backups..." 0
		ls -t ${BACKUP_MAIN_DIR} | tail -$(( NUMBER_OF_BACKUPS - MAX_NR_OF_BACKUPS )) | while read -r dirToRemove; do
			rm -r "${BACKUP_MAIN_DIR}/${dirToRemove:?}"
			logwrite "Removed ${BACKUP_MAIN_DIR}/${dirToRemove:?}" $?
		done
	fi
fi

logwrite "DONE! Backup created: ${BACKUP_DIR}" 0
