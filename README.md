# postgres-repmgr
PostgreSQL Docker image with repmgrd for automatic failover

This is heavily based on [2ndQuadrant's blog post on the topic](https://blog.2ndquadrant.com/pg-phriday-getting-rad-docker-part-3/)), but:

- several environment variables have been added
- this image doesn't use passwordless replication. Make sure to set `REPMGR_PASSWORD`
- I've taken the liberty to add my own [pg_recall](https://github.com/mreithub/pg_recall) PostgreSQL extension, because I need it on all my production clusters.  
  It's a source-only extension, so unless you call `CREATE EXTENSION recall`, it's entirely inactive.
- a few other minor changes

Environment:

This docker image uses the following environment variables (with their defaults if applicable):

- `REPMGR_USER=repmgr`
- `REPMGR_DB=repmgr`
- `REPMGR_PASSWORD` (required)  
  Use something like `pwgen -n 24 1` to generate a random one (and make sure you use the same one on all your nodes
- `BARMAN_PASSWORD` (required)  
  Use something like `pwgen -n 24 1` to generate a random one (and make sure you use the same one on all your nodes
- `STREAMING_PASSWORD` (required)  
  Use something like `pwgen -n 24 1` to generate a random one (and make sure you use the same one on all your nodes
- `PRIMARY_NODE=`  
  If set, this is used in the `conninfo` string (used by other nodes to connect to this one.  
  If empty, `hostname -f` is used
  Make sure you use a hostname the others can resolve (or an IP address)
- `WITNESS=`
  If non-empty, this node is set up as witness node (i.e. won't hold actual data but still has a vote in leader election).  
  

### BUILD IT
docker build --tag postgres-repmgr .

docker build --tag postgres-pgbouncer pgbouncer

docker build --tag postgres-barman barman

### RUN IT
export REPMGR_PASSWORD=`nicepass --password-length 24`

export BARMAN_PASSWORD=`nicepass --password-length 24`

export STREAMING_PASSWORD=`nicepass --password-length 24`

docker run --name pg-repmgr-1 --network pg_stream -e REPMGR_PASSWORD=$REPMGR_PASSWORD -e BARMAN_PASSWORD=$BARMAN_PASSWORD -e STREAMING_PASSWORD=$STREAMING_PASSWORD -d postgres-repmgr

sleep 2

docker run --name pg-repmgr-2 --network pg_stream -e REPMGR_PASSWORD=$REPMGR_PASSWORD -e BARMAN_PASSWORD=$BARMAN_PASSWORD -e STREAMING_PASSWORD=$STREAMING_PASSWORD -e PRIMARY_NODE=pg-repmgr-1 -d postgres-repmgr

sleep 2

docker run --name pg-repmgr-3 --network pg_stream -e REPMGR_PASSWORD=$REPMGR_PASSWORD -e BARMAN_PASSWORD=$BARMAN_PASSWORD -e STREAMING_PASSWORD=$STREAMING_PASSWORD -e PRIMARY_NODE=pg-repmgr-1 -d postgres-repmgr

sleep 8

docker exec -it pg-repmgr-2 su -c "repmgr cluster show" - postgres
sleep 3


#### PGBOUNCER
docker run --name pg-pgbouncer-1 --network pg_stream -e PRIMARY_NODE=pg-repmgr-1 -d postgres-pgbouncer

sleep 1

docker exec -it pg-pgbouncer-1 psql -U postgres -c "select client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn from pg_stat_replication;"

#### BARMAN
docker run --name pg-barman-1 --network pg_stream -e BARMAN_PASSWORD=$BARMAN_PASSWORD -e STREAMING_PASSWORD=$STREAMING_PASSWORD -e PRIMARY_NODE=pg-repmgr-1 -d postgres-barman

sleep 60
docker exec -it pg-barman-1 barman check pg-repmgr-1

### FORCE FAILOVER
[ monitor from another shell ] docker logs -f pg-repmgr-2

docker pause pg-repmgr-1

sleep 120

docker exec -it pg-repmgr-2 su -c "repmgr cluster show" - postgres

### TEST BOUNCER TO NEW MASTER
docker exec -it pg-pgbouncer-1 psql -U postgres -c "select client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn from pg_stat_replication;"

### REJOIN OLD MASTER
docker unpause pg-repmgr-1

sleep 10

docker exec -it -u postgres pg-repmgr-1 bash -c 'repmgr node service --action=stop --checkpoint'

docker exec -it -u postgres pg-repmgr-1 bash -c 'cp -f /etc/postgresql/postgresql.conf /var/lib/postgresql/data/postgresql.conf'

docker exec -it -u postgres pg-repmgr-1 bash -c 'repmgr -h pg-repmgr-2 -d repmgr node rejoin'

docker exec -it pg-pgbouncer-1 psql -U postgres -c "select client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn from pg_stat_replication;"


### TEAR DOWN
docker kill pg-repmgr-1

docker kill pg-repmgr-2

docker kill pg-repmgr-3

docker kill pg-pgbouncer-1

docker kill pg-barman-1

docker rm pg-repmgr-1

docker rm pg-repmgr-2

docker rm pg-repmgr-3

docker rm pg-pgbouncer-1

docker rm pg-barman-1
