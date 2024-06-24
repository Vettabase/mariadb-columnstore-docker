#!/usr/bin/env bash

if [[ -z $1 ]]
then
    MARIADB_PORT=3307
else
    MARIADB_PORT=$1
fi

docker stop mcs
docker rm mcs
docker run -d --name mcs -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 --rm vettadock/mariadb-columnstore:dev --port=$MARIADB_PORT
