IMAGE        := vettabase/mariadb-columnstore-docker
VERSION      := latest

all: build

.PHONY: build
build:
	docker build --shm-size=512mb -t $(IMAGE):$(VERSION) .
