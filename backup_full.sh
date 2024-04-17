#!/bin/bash
#set -e
WORKDIR=$(dirname "$0")
source $WORKDIR/common_vars

destination="$BACKUP_PATH_SAVE"
date
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H-%M-%S')
BACKUP_FOLDER_TMP="${BACKUP_PATH_TMP}/full"
ALERT_CHAT_ID="-xxxxxxx"
ALERT_TAG_PEOPLE="@xxxxx"
#########################
# define some functions
#########################
export url='http://alertmanager-url'
PROJ=projectname
check () {
  if [[ $(echo $?) != 0 ]]
  then
    backup_alert "$@"
    exit 1
  fi
}

#backup_alert () {
#  echo "alert at stage $@"
#  curl -XPOST $url -d "[{\"status\": \"firing\",\"labels\": {\"PROJ\":\"$PROJ\",\"alertname\": \"backups\",\"service\": \"backup-slave\",\"severity\": \"warning\",\"instance\": \"0\"},\"annotations\": {\"summary\": \"Backup failed\",\"description\": \"Backup $PROJ failed at $@.\"}}]"
#}


echo "#################################################"
echo "===== Staring full backup process for $DATE====="
echo "#################################################"

#########################
# clearing the folder
#########################

rm -rf "$BACKUP_FOLDER_TMP"
check "backup_folder_delete"
mkdir -p "$BACKUP_FOLDER_TMP"
#echo 1 > /tmp
check "backup_folder_create tmp"

#########################
# making the full backup
#########################
$DOCKER_EXEC bash -c "mysql -uroot --password=\$MYSQL_ROOT_PASSWORD mysql -e 'STOP SLAVE;'"
check "backup_xtrabackup_create stop"
$DOCKER_EXEC bash -c "mariabackup --backup --rsync --safe-slave-backup --target-dir=${BACKUP_FOLDER_TMP} --user=root --password=\$MYSQL_ROOT_PASSWORD"
check "backup_xtrabackup_create backup"
$DOCKER_EXEC bash -c "mysql -uroot --password=\$MYSQL_ROOT_PASSWORD mysql -e 'START SLAVE;'"
check "backup_xtrabackup_create stop"

#########################
# preparing backup for restore
#########################
$DOCKER_EXEC bash -c "mariabackup --prepare --target-dir=${BACKUP_FOLDER_TMP}"
check "backup_xtrabackup_prepare"

#########################
# compressing the backup
#########################
tar --ignore-failed-read -czvf "$BACKUP_PATH/db-full-$DATE.tar.gz" "$BACKUP_FOLDER_TMP"
#check "backup_compress"

# Save backup, maked 15th every month
find "$BACKUP_PATH" -maxdepth 1 -type f -name "db-full*-15*" -exec mv {} "$destination" \;

#########################
# deleting the backup
# (!) Do not do this if you want
#     to create incremental backup
#########################
##docker exec -i $DB_CONTAINER /bin/bash -c 'rm -rf '$BACKUP_FOLDER'/full'
##check "backup_delete_uncompressed"

# Delete older than 30 days
find "$BACKUP_PATH" -maxdepth 1 -type f -mtime +14 -delete
check "backup_delete_uncompressed 15"

#########################
# sending archive to FTP
#########################
#cd /srv/path/pimcore/dbprod/mysql/.backups/$DATE
#ftp -n <<EOF
#open $FTP_HOST
#user $FTP_USER $FTP_PASSWORD
#mkdir pimcore_backup/FULL/$DATE
#cd pimcore_backup/FULL/$DATE
#binary
#put full.tar.gz
#EOF
#check "backup_send_to_ftp"

find $BACKUP_PATH/db-full* -mtime +366 -exec rm {} \;
check "backup_delete_uncompressed 366"

date
