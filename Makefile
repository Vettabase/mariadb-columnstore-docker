IMAGE        := vettadock/mariadb-columnstore-docker
VERSION      := latest

all: build

.PHONY: build
build:
	docker build --rm --shm-size=512mb -t $(IMAGE):$(VERSION) .
