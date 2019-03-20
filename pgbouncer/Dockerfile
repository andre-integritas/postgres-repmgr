FROM postgres:10

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" \
          >> /etc/apt/sources.list.d/pgdg.list
  
RUN apt-get update; apt-get install -y git make postgresql-server-dev-10 libpq-dev pgbouncer postgresql-client-10 openssh-server

COPY pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY pgbouncer.database.ini /etc/pgbouncer/pgbouncer.database.ini
COPY userlist.txt /etc/pgbouncer/userlist.txt

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN chown postgres:postgres /etc/pgbouncer /etc/pgbouncer/pgbouncer.database.ini

ENV PRIMARY_NODE=localhost

COPY id_rsa.pub /var/lib/postgresql/.ssh/authorized_keys

RUN chown -R postgres:postgres /var/lib/postgresql/.ssh
RUN chmod 700 /var/lib/postgresql/.ssh
RUN chmod 600 /var/lib/postgresql/.ssh/authorized_keys

CMD [ "/usr/local/bin/docker-entrypoint.sh" ]
