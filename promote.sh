#!/usr/bin/env bash
set -e
set -u

PGBOUNCER_DATABASE_INI_NEW="/tmp/pgbouncer.database.ini"
PGBOUNCER_HOSTS="pg-pgbouncer-1"
DATABASES="postgres"

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

# TODO Generate new config file for barman, reconfigure barman, reload barman
