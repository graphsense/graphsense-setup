# GraphSense Setup

Docker compose setup for GraphSense components.

## About

The goal of this project is to allow an out-of-the-box yet customisable setup of all required graphsense services.
Graphsense consists of several services. Although each one is required for the product to work, running them all on one machine can be impractical due to high resource demand.


Service list:
 - `parser`, part of graphsense-blocksci project - reads bitcoin client's block files to a more useful format on disk.
 - `exporter`, part of graphsense-blocksci project - reads data produced by parser and inserts that into the cassandra database
 - `cassandra` - the primary and only database. Stores raw (produced by exporter) and transformed (produced by transformation) data in corresponding Cassandra keyspaces.
 - `transformation` - a spark job that reads raw data from cassandra, computes infromation useful for the end-user and stores result in the 'transformed' keyspace.
 - `graphsense-rest` - a flash REST service that exposes data stored in cassandra to the outside world. 
 - *...others, not yet covered by this project*


## Setup
Each service has its own `docker-compose.yml` config and can be built and run individually (please consult README files!). Most of the times however, one would want to quickly set up a set of above services and be sure that they are going to work well together.
For that, follow these steps:

 - Modify the `docker-compose.yml` file also supplied in this repo to only keep services that you want to include in this setup. Alternatively, keep all services.
 - `cp env.example .env`
 - Fill in all parameters in `.env` file. Parameters related to services removed from `docker-compose.yml` can be omitted. **Make sure all parameters have a value set!**
 

*If you choose to run graphsense-rest from this composition too, a flask secret key needs to be generated:* `./rest/gen_secret_key.sh`.



**Make sure the parent directory of this project has all the required graphsense services git-cloned in their correct directories, or docker-compose's extend won't find those.**
All `docker-compose` commands should be run from this directory!

After the above steps are complete, build the services:

`docker-compose build`


Then, you can start some services.
Nothing can happen without parser first finishing its job, so let's start it: 

`docker-compose up -d parser`


Parser is going to read all blocks it finds in `BLOCK_DIR`. You can track the progress as follows:

`docker-compose logs -f parser`


Once parser is done, exporter can start its duty. You may want to adjust `FROM_BLOCK` and `TO_BLOCK` variables in your `.env` file. 

`docker-compose up -d exporter` (This will also start up cassandra)


Once exporter is finished, transformation can start:

`docker-compose up -d transformation`


Before the `transformation` pipeline has completed, cassandra will only have some basic (i.e. not very useful) data.
In any case, the REST service already can run:

`docker-compose up -d graphsense-rest`

The REST service will be accessible at `0.0.0.0:REST_PORT`; `REST_PORT` is configured in the .env file.
To create a user account for using Graphsense, run `./rest/add_user.sh <username> <password>`.
