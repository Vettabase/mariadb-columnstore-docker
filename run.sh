#!/usr/bin/env bash

docker stop mcs 2>&1 /dev/null
docker rm mcs 2>&1 /dev/null
docker run -e MARIABD_ALLOW_EMPTY_ROOT_PASSWORD=1 vettadock/mariadb-columnstore:dev
