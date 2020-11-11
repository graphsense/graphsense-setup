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
- standalone Spark Cluster (version 2.7.7/Scala 2.12)
- [Apache Cassandra][apache-cassandra] cluster

All containers run with UID 10000 (user `dockeruser`). Ensure that a user
`dockeruser` with ID `10000` exists on your local system and that mapped local
volumes are owned by this user.

## Setup

Each GraphSense component has its own `Dockerfile` and can be built and run
individually (please consult the `README` files). Most of the times however,
one would want to quickly set up a set of services and be sure that they are
going to work well together.

For that, we provide a set of `docker-compose.yml` files in the corresponding
subdirectories. The source code of all required GraphSense components are
incorporated as Git submodules. To fetch the source code for all components use

```
git clone git@github.com:graphsense/graphsense-setup.git
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

To start all services in detached mode (i.e., to run the containers in the
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
# (by default up to last block of previous day, since exchange rates are not
# available for current day)
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
performed manually, see [here][graphsense-tagpacks].


### Transformation

The `transformation` directory contains a dockerized version of the Spark
transformation pipeline ([graphsense-transformation][graphsense-transformation]).

The current docker setup requires an existing, external Spark standalone cluster
(Spark version 2.7.7 with Scala 2.12).
A static IP from subnet of the Spark cluster is assigned to the container
using the Docker [macvlan bridge network][macvlan] (only supported on Linux).
The macvlan network driver assigns a MAC address to the container's virtual
network interface, making it appear to be a physical network interface directly
connected to the physical network. See the corresponding environment variables
in the `env.template` file.

IF the Spark master node is also used as host system for the container, the
container will not be able to connect to the host (and vice versa). This is
a limitation of macvlan interfaces. A workaround for this problem is to create
another macvlan interface on the host system, and use that to communicate with
the container on the macvlan network:

```
# add macvlan network interface on host
ip link add NETWORK_NAME link SPARK_MACVLAN_DEV type macvlan mode bridge
# configure interface
ip addr add UNUSED_ADDRESS/32 dev NETWORK_NAME
ip link set macvlan_spark up
ip route add SPARK_DRIVER_IP/32 dev NETWORK_NAME
```
(replace `NETWORK_NAME`, `UNUSED_ADDRESS` with appropriate values, and use the
same values for `SPARK_MACVLAN_DEV` and `SPARK_DRIVER_IP` as in `.env`).

After finishing the Spark configuration edit the arguments section in the
`.env` file, and build and start the container.

### Rest

The `rest` subdirectory contains the Docker Compose setup for the
`graphsense-rest` component.

Edit the `.env` file and build and start the service

```
docker-compose build
docker-compose up -d
```

The REST service will be accessible at `0.0.0.0:REST_PORT`. `REST_PORT` is
configured through the .env file.

TODO user management

### Dashboard

Edit the `.env` file and build and start the service

```
docker-compose build
docker-compose up -d
```

The dashboard is going to be accessible at `0.0.0.0:DASHBOARD_PORT`.
`DASHBOARD_PORT` is configured through the `.env` file.


[apache-cassandra]: http://cassandra.apache.org/download
[graphsense-blocksci]: https://github.com/graphsense/graphsense-blocksci
[docker]: https://www.docker.com
[blocksci]: https://github.com/citp/BlockSci
[coindesk]: https://www.coindesk.com/api
[coinmarketcap]: https://coinmarketcap.com
[graphsense-tagpacks]: https://github.com/graphsense/graphsense-tagpacks
[graphsense-transformation]: https://github.com/graphsense/graphsense-transformation
[macvlan]: https://docs.docker.com/network/macvlan
