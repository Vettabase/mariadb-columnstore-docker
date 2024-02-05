# MariaDB Columnstore Docker

This is a fork of [mariadb-columnstore-docker](https://github.com/mariadb-corporation/mariadb-columnstore-docker/tree/master) maintained by [Vettabase](https://vettabase.com/).
The aim of this fork is to keep an updated version of MariaDB Community edition with Columnstore and the S3 engine for use with community and client installations,

The official MariaDB docker currently does not support Columnstore of the S3 engine, an [issue](https://github.com/MariaDB/mariadb-docker/issues/457) is already open to get this resolved.

Another [ticket](https://jira.mariadb.org/browse/MCOL-5646) has been raised to update the current Columnstore image, but we feel like it is not suitable for container deployment or orchestration.

Some usage examples are documented below, and in the `examples/` directory.

## Summary

MariaDB ColumnStore is a columnar storage engine that utilizes a massively parallel distributed data architecture. It was built by porting InfiniDB to MariaDB and has been released under the GPL license.

MariaDB ColumnStore is designed for big data scaling to process petabytes of data, linear scalability and exceptional performance with real-time response to analytical queries. It leverages the I/O benefits of columnar storage, compression, just-in-time projection, and horizontal and vertical partitioning to deliver tremendous performance when analyzing large data sets.

## Requirements

* A container runtime such as [Docker](https://www.docker.com/) or [Podman](https://podman.io/).
* A shared volume mount for all servers when using a multi-node setup, or access to S3/S3-Compatible.

## Usage Examples

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

### Single node with persistent storage

    docker run -d -P 3307:3306 -v path/to/data:/var/lib/mysql vettadock/mariadb-columnstore-docker

### Single node with S3

    docker run -d -e S3_X -e S3_Y -e S3_Z vettadock/mariadb-columnstore-docker

### Multi-Node with CMAPI

    cd examples
    docker compose up -d

### Using S3 and MinIO

    docker run -d minio/minio
    docker run -d -e S3_X -e S3_Y -e S3_Z vettadock/mariadb-columnstore-docker

## Environment Variables

* USE_S3_STORAGE, set to non-empty value to configure MariaDB Columnstore for use with S3.
* CROSS_ENGINE_USERNAME, use a different username for the Cross Engine Join user, configured in Columnstore.
* CROSS_ENGINE_PASSWORD, use a different password from the randomly generated one for the Cross Engine Join user, configured in Columnstore.

TO DO:

* Show how to use a Docker network
* Show how to expose ports
* Add recipes for Podman
