#!/usr/bin/env bash
set -e
set -u

PGBOUNCER_DATABASE_INI_NEW="/tmp/pgbouncer.database.ini"
PGBOUNCER_HOSTS="pg-pgbouncer-1"
DATABASES="postgres"

BARMAN_DATABASE_INI_NEW="/tmp/barman.database.ini"
BARMAN_DATABASE_PASSWORD="/tmp/barman.password.ini"
BARMAN_HOSTS="pg-barman-1"

# Pause pgbouncer
for h in ${PGBOUNCER_HOSTS}
do
  for d in ${DATABASES}
  do
      psql -U postgres -h ${h} -p 5432 pgbouncer -tc "pause ${d}"
  done
done

# Promote server
/usr/lib/postgresql/10/bin/pg_ctl -w -D '/var/lib/postgresql/data' promote

# Generate new config file for pgbouncer
echo -e "[databases]\n" > ${PGBOUNCER_DATABASE_INI_NEW}
for d in ${DATABASES}
do
  echo -e "${d}= host=$(hostname -f)\n" >> ${PGBOUNCER_DATABASE_INI_NEW}
done

# Copy new config file, reload and resume pgbouncer
for h in ${PGBOUNCER_HOSTS}
do
  for d in ${DATABASES}
  do
      rsync -a ${PGBOUNCER_DATABASE_INI_NEW} ${h}:/etc/pgbouncer/pgbouncer.database.ini
      psql -U postgres -h ${h} -p 5432 pgbouncer -tc "reload"
      psql -U postgres -h ${h} -p 5432 pgbouncer -tc "resume ${d}"
  done
done

rm ${PGBOUNCER_DATABASE_INI_NEW}

# BARMAN

PRIMARY_NODE=$(hostname -f)

cat >$BARMAN_DATABASE_INI_NEW <<EOF
[$PRIMARY_NODE]
; active = true
; archiver = off
; archiver_batch_size = 0
; backup_directory = %(barman_home)s/%(name)s
; backup_method = rsync
; backup_options =
; basebackup_retry_sleep = 30
; basebackup_retry_times = 0
; basebackups_directory = %(backup_directory)s/base
; check_timeout = 30
conninfo = host=$PRIMARY_NODE user=$BARMAN_USER dbname=postgres
description = 'Test database'
; disabled = false
; errors_directory = %(backup_directory)s/errors
; immediate_checkpoint = false
; incoming_wals_directory = %(backup_directory)s/incoming
; minimum_redundancy = 0
; network_compression = false
path_prefix = /usr/lib/postgresql/10
; recovery_options =
; retention_policy_mode = auto
ssh_command = 'ssh -l postgres $PRIMARY_NODE'
slot_name = $BARMAN_SLOT_NAME
; streaming_archiver = off
; streaming_archiver_batch_size = 0
; streaming_archiver_name = barman_receive_wal
; streaming_backup_name = barman_streaming_backup
streaming_conninfo = host=$PRIMARY_NODE user=$STREAMING_USER dbname=postgres
; streaming_wals_directory = %(backup_directory)s/streaming
; wal_retention_policy = main
; wals_directory = %(backup_directory)s/wals
EOF

echo "${PRIMARY_NODE}:*:*:${BARMAN_USER}:${BARMAN_PASSWORD}" > ${BARMAN_DATABASE_PASSWORD}
echo "${PRIMARY_NODE}:*:*:${STREAMING_USER}:${STREAMING_PASSWORD}" >> ${BARMAN_DATABASE_PASSWORD}
chmod 600 ${BARMAN_DATABASE_PASSWORD}

for h in ${BARMAN_HOSTS}
do
  rsync -a ${BARMAN_DATABASE_INI_NEW} barman@${h}:/etc/barman/barman.d/pg.conf
  rsync -a ${BARMAN_DATABASE_PASSWORD} barman@${h}:/home/barman/.pgpass
	
	ssh -l barman ${h} "barman -q cron"
	sleep 1
	
	ssh -l barman ${h} "barman receive-wal --create-slot $PRIMARY_NODE"
	sleep 3
	
	ssh -l barman ${h} "barman switch-xlog --force --archive $PRIMARY_NODE || true"
done

rm -f ${BARMAN_DATABASE_INI_NEW}
rm -f ${BARMAN_DATABASE_PASSWORD}
