# GraphSense Setup

Docker compose setup for GraphSense components.


## About

The goal of this project is to allow an out-of-the-box yet customizable setup
of all required GraphSense components. Graphsense consists of several services.

List of components:
- `clients`: dockerized cryptocurrency clients for Bitcoin, Bitcoin Cash,
  Litecoin and Zcash.
- `ingest`: these services are part of the 
   [graphsense-blocksci][graphsense-blocksci] project to parse and ingest
   Blockchain data and exchange rates for all supported currencies.
- `transformation`: a Spark job that reads raw data from Cassandra and writes
   the computed the address and entity graphs to a transformed keyspace.
- `rest`: a Flask REST service exposing denormalized views computed by the
  transformation pipeline.
- `dashboard`: a front-end dashboard for interactive cryptocurrency analysis.

Although each one is required for the platform to work, some of them must be run
in a sequential order.


## Prerequisites

- Git version control system
- [Docker][docker], see e.g. https://docs.docker.com/engine/install/
- Docker Compose: https://docs.docker.com/compose/install/
- a machine with at least 60GB RAM to run the `graphsense-blocksci` component
- standalone [Apache Spark][apache-spark] cluster (version 2.7.7/Scala 2.12)
- [Apache Cassandra][apache-cassandra] cluster

All containers run with UID 10000 (user `dockeruser`). Ensure that a user
UID `10000` exists on your local system(s) and that mapped local volumes are
owned by this user.


## Setup

Each GraphSense component has its own `Dockerfile` and can be built and run
individually (please consult the `README` files). Most of the times however,
one would want to quickly set up a set of services and be sure that they are
going to work well together.

For that, we provide a set of `docker-compose.yml` files in the corresponding
subdirectories. The source code of all required GraphSense components is
included through Git submodules. To fetch the source code for all components use

```
git clone https://github.com/graphsense/graphsense-setup.git .
git submodule init
git submodule update
```

The components must be set up/run in the following order:

- clients
- ingest
- transformation
- rest
- dashboard

In each subdirectory copy the `env.template` file to `.env` and fill in all
parameters in the `.env` files. Verify that all parameters have a value set:

```
docker-compose config
```


### Clients

The `client` subdirectory contains the source code and Docker setup for
all supported cryptocurrency clients. To build the Docker images, change
to the `client` directory and execute

```
docker-compose build
```

In the Docker Compose file, we define the following services:

- `bitcoin-client`
- `bitcoin-cash-client`
- `litecoin-client`
- `zcash-client`

Before starting the containers, create all directories as defined in the `.env`
file (must be writable by UID 10000). To start all services in detached mode
(i.e., to run the containers in the
background), execute

```
docker-compose up -d
```

List all running containers:

```
> docker-compose ps
    Name                  Command               State           Ports
------------------------------------------------------------------------------
bitcoin        bitcoind -conf=/opt/graphs ...   Up      0.0.0.0:8332->8332/tcp
bitcoin-cash   bitcoind -conf=/opt/graphs ...   Up      0.0.0.0:8432->8432/tcp
litecoin       litecoind -conf=/opt/graph ...   Up      0.0.0.0:8532->8532/tcp
zcash          zcashd -conf=/opt/graphsen ...   Up      0.0.0.0:8632->8632/tcp
```

To keep track of the client synchronization process, use

```
# all clients
docker-compose logs
# only BTC
docker-compose logs -f bitcoin-client
```


### Ingest

The `ingest` directory includes the `graphsense-blocksci` component, which
employs [BlockSci][blocksci] for parsing blockchains and filtering CoinJoins.

The Docker Compose file defines services
- to parse the blockchain data gathered by the cryptocurrency clients and
  ingest it to an existing, external Apache Cassandra cluster, and
- to retrieve and ingest exchange rates from [CoinDesk][coindesk] or
  [CoinMarketCap][coinmarketcap].

As above for the clients, build the Docker image using

```
docker-compose build
```

To parse and ingest the data, the Docker Compose setup defines three services
for each cryptocurrency, which should run sequentially. E.g., for Bitcoin

```
# blockchain parsing
docker-compose run parser-btc
# ingest parsed data into raw Cassandra keyspace
# (by default, up to the last block of previous day, since exchange rates
# are not available for the current day)
docker-compose run ingest-btc
# ingest exchange rates to Cassandra
docker-compose run ingest-exchange-rates-btc
```

To parse the Bitcoin blockchain, BlockSci requires at least 60GB of RAM
(as of July 2020).

After successful parsing and ingest, execute

```
docker-compose down
```

to remove all containers and volumes.

#### GraphSense tagpacks (optional)

There is currently no Docker setup for the ingest of attribution tags.
The ingest of TagPacks to the raw Cassandra keyspace needs to be
performed manually, see [graphsense-tagpack-tool][graphsense-tagpack-tool]
for further information.


### Transformation

The `transformation` directory contains a dockerized version of the Spark
transformation pipeline ([graphsense-transformation][graphsense-transformation]).

The current Docker setup requires an existing, external Spark standalone cluster
(Spark version 2.7.7 with Scala 2.12), which could also be deployed using Docker
(as [Docker Swarm](https://docs.docker.com/get-started/swarm-deploy/)).
The environment variable `SPARK_DRIVER_HOST` specifies the network address of
the host machine where the container will be running. Spark cluster nodes should
be able to resolve this address. This is necessary for communication between
executors and the driver program. For detailed technical information see
[SPARK-4563](https://issues.apache.org/jira/browse/SPARK-4563).
The option `spark.driver.bindAddress` is set to `0.0.0.0` inside the container.
It allows a different address from the local one to be advertised to
executors or external systems, which is necessary when running containers
with bridged networking. For this to properly work, the different
ports used by the driver need to be forwarded from the container's host
(`SPARK_DRIVER_PORT`,`SPARK_UI_PORT`, `SPARK_BLOCKMGR_PORT`).

After finishing the Spark configuration edit the arguments section in the
`.env` file, and build and run the container:

```
docker-compose build
docker-compose run --service-ports transformation
```

Note that the `--service-ports` option is required, to enable the port mapping
to the host.


### Rest

The `rest` subdirectory contains the Docker Compose setup for the
`graphsense-rest` component.
Change to the `rest` directory and copy the template config file

```
mkdir -p graphsense-rest/instance
cp graphsense-rest/conf/config.yaml.template graphsense-rest/instance/config.yaml
```

and edit all required parameters.

Furthermore, edit the `.env` file and build and start the service

```
docker-compose build
docker-compose up -d
```

The REST service will be accessible at `0.0.0.0:REST_PORT`. `REST_PORT` is
configured through the `.env` file.

The view the generated API documentation, open `http://127.0.0.1:REST_PORT/ui`
in a web browser.

### Dashboard

Edit the `.env` file and build and start the service:

```
docker-compose build
docker-compose up -d
```

The dashboard is going to be accessible at `0.0.0.0:DASHBOARD_PORT`.
`DASHBOARD_PORT` is configured through the `.env` file.


[apache-spark]: https://spark.apache.org/downloads.html
[apache-cassandra]: http://cassandra.apache.org/download
[graphsense-blocksci]: https://github.com/graphsense/graphsense-blocksci
[docker]: https://www.docker.com
[blocksci]: https://github.com/citp/BlockSci
[coindesk]: https://www.coindesk.com/api
[coinmarketcap]: https://coinmarketcap.com
[graphsense-tagpack-tool]: https://github.com/graphsense/graphsense-tagpack-tool
[graphsense-transformation]: https://github.com/graphsense/graphsense-transformation
