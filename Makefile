IMAGE ?= ghcr.io/maltej/debian-ai
TAG   ?= latest

.PHONY: build run push

build:
	docker buildx build --load -t $(IMAGE):$(TAG) -f Containerfile .

run:
	docker run --rm -it \
	  -v "$$PWD":/workspace \
	  $(IMAGE):$(TAG)

# amd64 only, like the CI: the sandboxes run on x86_64 nodes.
push:
	docker buildx build --push \
	  --platform linux/amd64 \
	  -t $(IMAGE):$(TAG) -f Containerfile .
