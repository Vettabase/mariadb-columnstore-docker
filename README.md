# MariaDB Columnstore Docker

This is a fork of [mariadb-columnstore-docker](https://github.com/mariadb-corporation/mariadb-columnstore-docker/tree/master) maintained by [Vettabase](https://vettabase.com/).
The aim of this fork is to keep an updated version of MariaDB Community edition with Columnstore and the S3 engine for use with client installations,

The official MariaDB docker currently does not support Columnstore of the S3 engine, an [issue](https://github.com/MariaDB/mariadb-docker/issues/457) is already open.
Another [ticket](https://jira.mariadb.org/browse/MCOL-5646) has been raised to update the current Columnstore image, but we feel like it is not suitable for container deployment or orchestration.

Some usage examples are below documented and in the `examples/`.

## Summary

MariaDB ColumnStore is a columnar storage engine that utilizes a massively parallel distributed data architecture. It was built by porting InfiniDB to MariaDB and has been released under the GPL license.

MariaDB ColumnStore is designed for big data scaling to process petabytes of data, linear scalability and exceptional performance with real-time response to analytical queries. It leverages the I/O benefits of columnar storage, compression, just-in-time projection, and horizontal and vertical partitioning to deliver tremendous performance when analyzing large data sets.

## Requirements

* A container runtime such as [Docker](https://www.docker.com/) or [Podman](https://podman.io/).
* A shared volume mount for all servers when using a multi-node setup, or access to S3/S3-Compatible.

## Usage

To start the container from the Dockerfile:

    docker run -d -e --name mcs

To start using `mariadb` CLI client:

    docker exec -ti mcs mariadb

To run a query in a non-interactive fashion from the host:

    docker exec -ti mcs mariadb -e "SHOW SCHEMAS;"

To take a [logical backup](https://mariadb.com/kb/en/mariadb-dump/) and write it into a file outside of the container:

    docker exec -ti mcs mariadb-dump --all-databases --single-transaction > backup.sql

The default user is `mysql`, and it can't sudo. To log into the container shell as root:

    docker exec -ti -u 0 mcs bash

### Multi-Node with CMAPI

### Using S3 and MinIO
