REPOSITORY ?= gitmux

.PHONY:
ls:
	@docker images --no-trunc --format '{{json .}}' | \
		jq -r 'select((.Repository|startswith("$(REPOSITORY)")))' | jq -rs 'sort_by(.Repository)|.[]|"\(.ID)\t\(.Repository):\(.Tag)\t(\(.CreatedSince))\t[\(.Size)]"'

.PHONY:
build:
	@docker build \
	--tag $(REPOSITORY):latest \
	--file Dockerfile .

.PHONY:
run:
	@docker run --interactive --tty \
	--volume $(shell pwd)/gitmux.sh:/gitmux.sh \
	$(REPOSITORY):latest

.PHONY:
run-test:
	@docker run --interactive --tty \
	--volume $(shell pwd)/gitmux.sh:/gitmux.sh \
	--volume $(shell pwd)/test_gitmux.sh:/test_gitmux.sh \
	$(REPOSITORY):latest

