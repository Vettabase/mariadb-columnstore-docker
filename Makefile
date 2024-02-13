IMAGE        := vettadock/mariadb-columnstore
VERSION      := dev

all: build

.PHONY: build
build:
	docker build --shm-size=512mb -t $(IMAGE):$(VERSION) .

.PHONY: rebuild
rebuild:
	docker build --no-cache --shm-size=512mb -t $(IMAGE):$(VERSION) .
.PHONY: push
push:
	docker push $(IMAGE):$(VERSION)
