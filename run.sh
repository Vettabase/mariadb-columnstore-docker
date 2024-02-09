#!/usr/bin/env bash

docker stop mcs
docker rm mcs
docker run --name mcs -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 --rm vettadock/mariadb-columnstore:dev
