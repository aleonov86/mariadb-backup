#!/bin/bash

WORKDIR=$(dirname "$0")
source $WORKDIR/common_vars

date
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H-%M-%S')
BACKUP_FOLDER_FULL="${BACKUP_PATH_TMP}/full"
BACKUP_FOLDER_INC="${BACKUP_PATH}/inc"
KEEP_HOURS=24
ALERT_CHAT_ID="-xxxxxxxx"
ALERT_TAG_PEOPLE="@xxxxxxxx"

#########################
# define some functions
#########################
check () {
  if [[ $(echo $?) != 0 ]]
  then
    backup_alert $1
    exit 1
  fi
}

#backup_alert () {
#  curl --data "chat_id=$ALERT_CHAT_ID" --data "message=%F0%9F%94%A5 Production INCREMENTAL backup failed. Reason: $1 $ALERT_TAG_PEOPLE" http://zabbix-url
#}

echo "#################################################"
echo "===== Staring  inc  backup process for $DATE====="
echo "#################################################"

#########################
# preparing the folder
#########################
mkdir -p "$BACKUP_FOLDER_INC/$TIME"
#check "backup_folder_create"

#########################
# making the inc backup
#########################
$DOCKER_EXEC bash -c "mariabackup --backup --user=root --password=\$MYSQL_ROOT_PASSWORD --target-dir=$BACKUP_FOLDER_INC/$TIME --incremental-basedir=$BACKUP_FOLDER_FULL"
#check "backup_xtrabackup_create"


#########################
# compressing the backup
#########################
tar -czvf "$BACKUP_PATH/db-inc-$DATE-$TIME.tar.gz" "$BACKUP_FOLDER_INC/$TIME"
#check "backup_compress"


#########################
# sending archive to FTP
#########################
#cd /srv/path/mysql/.backups/$DATE
#ftp -n <<EOF
#open $FTP_HOST
#user $FTP_USER $FTP_PASSWORD
#mkdir pimcore_backup/TRANS/$DATE
#cd pimcore_backup/TRANS/$DATE
#binary
#put inc-$TIME.tar.gz
#EOF
#check "backup_send_to_ftp"

#########################
# deleting the backup
#########################
rm -rf "$BACKUP_FOLDER_INC/$TIME"
find $BACKUP_PATH/db-inc* -mtime +1 -exec rm {} \;
#check "backup_delete"

date
