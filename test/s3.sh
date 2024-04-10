#!/usr/bin/env bash

#docker run -d --name=minio -p 9000:9000 -p 9001:9001 minio/minio server /data --console-address ":9001"

docker stop mcs
docker rm mcs
docker run --name mcs -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 \
    -e USE_S3_STORAGE=1 \
    -e S3_HOSTNAME="minio" \
    -e S3_BUCKET=data \
    -e S3_PORT=9000 \
    -e S3_ACCESS_KEY="111" \
    -e S3_SECRET_KEY="11111111" \
    --rm vettadock/mariadb-columnstore:dev

