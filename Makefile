IMAGE ?= ghcr.io/maltej/debian-ai
TAG   ?= latest

.PHONY: build run push

build:
	docker buildx build --load -t $(IMAGE):$(TAG) -f Containerfile .

run:
	docker run --rm -it \
	  -v "$$PWD":/workspace \
	  $(IMAGE):$(TAG)

push:
	docker buildx build --push \
	  --platform linux/amd64,linux/arm64 \
	  -t $(IMAGE):$(TAG) -f Containerfile .
