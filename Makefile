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

.PHONY: run
run: build
	@docker stop mcs || true
	@docker rm mcs || true
	docker run --name mcs \
		-a stdout -a stderr \
		-e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 \
		--rm vettadock/mariadb-columnstore:dev
