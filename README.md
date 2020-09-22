# GraphSense Setup

Docker compose setup for GraphSense components.

## About

The goal of this project is to allow an out-of-the-box yet customisable setup of all required graphsense services.
Graphsense consists of several services. Although each one is required for the product to work, running them all on one machine can be impractical due to high resource demand.


Service list:
 - `parser`, part of graphsense-blocksci project - reads bitcoin client's block files to a more useful format on disk.
 - `exporter`, part of blocksci project - reads data produced by parser and inserts that into the cassandra database
 - `cassandra` - the primary and only database. Stores raw (produced by exporter) and transformed (produced by transformation) data in corresponding Cassandra keyspaces.
 - `transformation` - a spark job that reads raw data from cassandra, computes infromation useful for the end-user and stores result in the 'transformed' keyspace.
 - *...others, not yet covered by this project*


## Setup

Each service has its own `docker-compose.yml` config and can be built and run manually. Most of the times however, one would want to quickly set up a set of above services and be sure that they will work together well.
For that, follow these steps:

 - Modify the `docker-compose.yml` file also supplied in this repo to only keep services that you want to include in this setup. Alternatively, keep all services.
 - `cp env.example .env`
 - Fill in all parameters in `.env` file. Parameters related to services removed from `docker-compose.yml` can be omitted.
 

**Make sure the parent directory of this project has all the required graphsense services git-cloned in their correct directories, or docker-compose's extend won't find those.**
All `docker-compose` commands should be run from this directory!
>>>>>>> Add README
