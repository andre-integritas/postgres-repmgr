FROM postgres:10

RUN apt-get update \
	&& apt-get install -y --no-install-recommends wget cron gcc libpq-dev libpython-dev logrotate openssh-client rsync python3-pip openssh-server \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /etc/crontab /etc/cron.*/* \
	&& sed -i 's/\(.*pam_loginuid.so\)/#\1/' /etc/pam.d/cron

ENV \
	BARMAN_DATA_DIR=/var/lib/barman \
	BARMAN_LOG_DIR=/var/log/barman

RUN pip3 install barman requests psycopg2-binary

RUN useradd --system --shell /bin/bash barman
RUN install -d -m 0700 -o barman -g barman /home/barman/.ssh

COPY barman.pem /home/barman/.ssh/id_rsa
RUN chmod 600 /home/barman/.ssh/id_rsa

COPY ssh_config /home/barman/.ssh/config
COPY pgbouncer.pub /home/barman/.ssh/authorized_keys

RUN chown -R barman:barman /home/barman/.ssh

ENV \
	BARMAN_USER=barman \
	BARMAN_PASSWORD= \
	BARMAN_SLOT_NAME=barman \
	STREAMING_USER=streaming_barman \
	STREAMING_PASSWORD= \
	PRIMARY_NODE=

RUN rm -f /etc/logrotate.d/*

COPY logrotate.conf /etc/logrotate.conf
RUN chown root:root /etc/logrotate.conf
RUN chmod 644 /etc/logrotate.conf

COPY basebackup.cron /etc/cron.d/basebackup
RUN chown root:root /etc/cron.d/basebackup
RUN chmod 644 /etc/cron.d/basebackup

COPY crontab /etc/crontab
RUN chown root:root /etc/crontab
RUN chmod 644 /etc/crontab

COPY etc /etc/barman

VOLUME /var/log/barman

ENTRYPOINT ["/entrypoint.sh"]
CMD ["cron", "-L", "0",  "-f"]

COPY entrypoint.sh /

WORKDIR ${BARMAN_DATA_DIR}
