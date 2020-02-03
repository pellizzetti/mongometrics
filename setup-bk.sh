#!/usr/bin/env bash
set -e

STORAGE_BACKUP_BUCKET_NAME=bucket
MONGODB_HOST=localhost
MONGODB_PORT=27017
MONGODB_USER=mongoadmin
MONGODB_PASS=secret
MONGODB_DATABASE=test
#GOOGLE_APPLICATION_CREDENTIALS=$PWD/credentials/google-application-credentials.json
MAX_BACKUPS=7
BACKUP_PREFIX=mongo-test
GCSFUSE_DIR=$PWD/backup
BACKUP_DIR=$GCSFUSE_DIR/mongo

gcsfuse -o nonempty ${STORAGE_BACKUP_BUCKET_NAME} ${GCSFUSE_DIR}

HOST_STR="--host ${MONGODB_HOST}"
PORT_STR=" --port ${MONGODB_PORT}"
USER_STR=" --username ${MONGODB_USER}"
PASS_STR=" --password ${MONGODB_PASS}"
DB_STR=" --db ${MONGODB_DATABASE}"
EXTRA_STR=" --authenticationDatabase admin"

BACKUP_NAME="${MONGODB_DATABASE}-\$(date +\%Y.\%m.\%d.\%H\%M\%S)"
BACKUP_CMD="mongodump --gzip --archive=${BACKUP_DIR}/${BACKUP_NAME}.gz ${HOST_STR}${PORT_STR}${USER_STR}${PASS_STR}${DB_STR}${EXTRA_STR}"

echo "=> Creating backup script"
rm -f $PWD/backup.sh
cat <<EOF >> $PWD/backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}

echo "=> Backup started"
if ${BACKUP_CMD} ;then
    echo "   Backup succeeded"
else
    echo "   Backup failed"
    rm -rf ${BACKUP_DIR}/${BACKUP_NAME}.gz
fi

if [ -n "\${MAX_BACKUPS}" ]; then
    while [ \$(ls ${BACKUP_DIR} -N1 | wc -l) -gt \${MAX_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=\$(ls ${BACKUP_DIR} -N1 | sort | head -n 1)
        echo "   Deleting backup \${BACKUP_TO_BE_DELETED}"
        rm -rf ${BACKUP_DIR}/\${BACKUP_TO_BE_DELETED}
    done
fi
echo "=> Backup done"
EOF
chmod +x $PWD/backup.sh

echo "=> Creating restore script"
rm -f $PWD/restore.sh
cat <<EOF >> $PWD/restore.sh
#!/bin/bash
echo "=> Restore database from \$1"
if mongorestore --gzip --archive=\$1 ${HOST_STR}${PORT_STR}${USER_STR}${PASS_STR}${EXTRA_STR}; then
    echo "   Restore succeeded"
else
    echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x $PWD/restore.sh

touch $PWD/mongo_backup.log
#tail -f doesn't work on overlay file systems on jessie...
#tail -F $PWD/mongo_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    $PWD/backup.sh
fi

echo "${CRON_TIME} $PWD/backup.sh >> $PWD/mongo_backup.log 2>&1" > $PWD/crontab.conf
crontab  $PWD/crontab.conf
echo "=> Running cron job"
exec cron -f
