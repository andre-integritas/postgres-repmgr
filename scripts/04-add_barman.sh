#!/bin/bash

set -eo pipefail
 
if [ $(grep -c "barman" ${PGDATA}/pg_hba.conf) -gt 0 ]; then
    return
fi

if [ -z "$BARMAN_PASSWORD" ]; then
	echo 'ERROR: Missing $$BARMAN_PASSWORD variable' >&2
	exit 1
fi

if [ -z "$STREAMING_PASSWORD" ]; then
	echo 'ERROR: Missing $STREAMING_PASSWORD variable' >&2
	exit 1
fi

echo '~~ 01: add barman' >&2

function add_user {
	local user=${!1}
	local pw=${!2}
	local db=${3}
	local options="${4}"

	echo "Creating ${user} user in database."
	local cmd="CREATE USER ${user} WITH ${options}"
	local auth
	if [[ -n ${pw} ]]; then
		cmd+=" ENCRYPTED PASSWORD '<password>'"
		auth="md5"
		echo "Be sure to add the following to the .pgpass file on the barman server:"
		echo "$(hostname):${PGPORT:-5432}:${PGDATABASE}:${user}:<password>"
	else
		auth="trust"
		echo "${user} is being created without any password!!!"
	fi

	echo "Running ${cmd}"
	psql -c "${cmd/<password>/${pw//\'/\'\'}}"

	echo "Adding ${user} to pg_hba.conf"
	echo "host ${db} ${user} 0.0.0.0/0 ${auth}" >> ${PGDATA}/pg_hba.conf
	echo "host ${db} ${user} ::/0 ${auth}" >> ${PGDATA}/pg_hba.conf
}

add_user BARMAN_USER BARMAN_PASSWORD all SUPERUSER
add_user STREAMING_USER STREAMING_PASSWORD replication REPLICATION

if [[ -n ${BARMAN_SLOT_NAME} ]]; then
  echo "Creating replication slot '${BARMAN_SLOT_NAME}' for barman."
  psql -v ON_ERROR_STOP=1 -c "SELECT * FROM pg_create_physical_replication_slot('${BARMAN_SLOT_NAME//\'/\'\'}');"
else
  echo "BARMAN_SLOT_NAME is empty; not creating replication slot."
fi
 
sleep 5
