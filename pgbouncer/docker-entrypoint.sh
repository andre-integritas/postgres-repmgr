#!/bin/sh

sed -i "s/\$POSTGRES_PASSWORD/$POSTGRES_PASSWORD/g" /etc/pgbouncer/userlist.txt
sed -i "s/\$PRIMARY_NODE/$PRIMARY_NODE/g" /etc/pgbouncer/pgbouncer.database.ini

/etc/init.d/ssh start

exec gosu postgres /usr/sbin/pgbouncer /etc/pgbouncer/pgbouncer.ini
