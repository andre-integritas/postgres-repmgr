FROM postgres:10

# PostgreSQL 10 docker image with
# repmgr and pg_recall
# (and pg_stat_statements is enabled in postgresql.conf)

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" \
          >> /etc/apt/sources.list.d/pgdg.list
 
RUN ln -s /home/postgres/repmgr.conf /etc/repmgr.conf
 
# override this on secondary nodes
ENV PRIMARY_NODE=localhost

ENV REPMGR_USER=repmgr
ENV REPMGR_DB=repmgr
 
RUN apt-get update; apt-get install -y git make postgresql-server-dev-10 libpq-dev postgresql-10-repmgr repmgr-common openssh-server python3-pip

RUN git clone https://github.com/mreithub/pg_recall.git /root/pg_recall/
RUN cd /root/pg_recall/; make install

RUN pip3 install barman-cli

RUN mkdir -p /home/postgres/; chown postgres:postgres /home/postgres/

COPY postgresql.conf /etc/postgresql/
COPY docker-entrypoint.sh /usr/local/bin/
COPY scripts/*.sh /docker-entrypoint-initdb.d/

COPY promote.sh /usr/local/bin/promote.sh

COPY pgbouncer.pem /var/lib/postgresql/.ssh/id_rsa
COPY ssh_config /var/lib/postgresql/.ssh/config

RUN chown -R postgres:postgres /var/lib/postgresql/.ssh
RUN chmod 700 /var/lib/postgresql/.ssh
RUN chmod 600 /var/lib/postgresql/.ssh/id_rsa

ENV \
	BARMAN_USER=barman \
	BARMAN_PASSWORD= \
	BARMAN_SLOT_NAME=barman \
	STREAMING_USER=streaming_barman \
	STREAMING_PASSWORD=

COPY barman.pub /var/lib/postgresql/.ssh/authorized_keys
RUN chmod 600 /var/lib/postgresql/.ssh/authorized_keys
RUN chown postgres:postgres /var/lib/postgresql/.ssh/authorized_keys

VOLUME /home/postgres/
VOLUME /var/lib/postgresql/data/

CMD [ "postgres", "-c", "config_file=/etc/postgresql/postgresql.conf" ]
