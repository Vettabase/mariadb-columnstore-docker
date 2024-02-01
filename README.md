# MariaDB Columnstore Docker

This is a fork of [mariadb-columnstore-docker](https://github.com/mariadb-corporation/mariadb-columnstore-docker/tree/master) maintained by [Vettabase](https://vettabase.com/).
The aim of this fork is to keep an updated version of MariaDB Community edition with Columnstore and the S3 engine for use with client installations,

The official MariaDB docker currently does not support Columnstore of the S3 engine, an [issue](https://github.com/MariaDB/mariadb-docker/issues/457) is already open.
Another [ticket](https://jira.mariadb.org/browse/MCOL-5646) has been raised to update the current Columnstore image, but we feel like it is not suitable for container deployment or orchestration.

Some usage examples below or the `examples/` directory for runn Columnstore as single or multi-node deployments.

## Summary

MariaDB ColumnStore is a columnar storage engine that utilizes a massively parallel distributed data architecture. It was built by porting InfiniDB to MariaDB and has been released under the GPL license.

MariaDB ColumnStore is designed for big data scaling to process petabytes of data, linear scalability and exceptional performance with real-time response to analytical queries. It leverages the I/O benefits of columnar storage, compression, just-in-time projection, and horizontal and vertical partitioning to deliver tremendous performance when analyzing large data sets.

## Requirements

* A container runtime such as [Docker](https://www.docker.com/) or [Podman](https://podman.io/).
* A shared volume mount for all servers when using a multi-node setup, or access to S3/S3-Compatible.

## Usage

    docker run -d -e 

### Multi-Node with CMAPI

### Using S3 and MinIO
