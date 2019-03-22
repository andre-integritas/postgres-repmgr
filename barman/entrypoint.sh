#!/bin/bash

set -eo pipefail

echo "${PRIMARY_NODE}:*:*:${BARMAN_USER}:${BARMAN_PASSWORD}" > /home/barman/.pgpass
echo "${PRIMARY_NODE}:*:*:${STREAMING_USER}:${STREAMING_PASSWORD}" >> /home/barman/.pgpass

chmod 600 /home/barman/.pgpass
chown -R barman:barman /home/barman

install -d -m 0755 -o barman -g barman "${BARMAN_LOG_DIR}"
install -d -m 0700 -o barman -g barman "${BARMAN_DATA_DIR}"

sed -i "s#\$BARMAN_LOG_DIR#$BARMAN_LOG_DIR#g" /etc/logrotate.conf

sed -i "s#\$PRIMARY_NODE#$PRIMARY_NODE#g" /etc/barman/barman.d/pg.conf
sed -i "s#\$BARMAN_USER#$BARMAN_USER#g" /etc/barman/barman.d/pg.conf
sed -i "s#\$BARMAN_SLOT_NAME#$BARMAN_SLOT_NAME#g" /etc/barman/barman.d/pg.conf
sed -i "s#\$STREAMING_USER#$STREAMING_USER#g" /etc/barman/barman.d/pg.conf

chown -R barman:barman /etc/barman

/etc/init.d/ssh start

gosu barman barman -q cron

gosu barman barman switch-xlog --force --archive $PRIMARY_NODE

exec "$@"
