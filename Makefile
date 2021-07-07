SHELL := /bin/bash
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
	docker run \
	--env GH_HOST \
	--env GH_TOKEN \
	--env GITHUB_OWNER \
	--interactive --tty \
	--volume $(shell pwd)/gitmux.sh:/gitmux.sh \
	--volume $(shell pwd)/test_gitmux.sh:/test_gitmux.sh \
	$(REPOSITORY):latest \
	/bin/bash -c \
	"git config --global user.email \"$(shell git config --global user.email)\" &&  \
	git config --global user.name \"$(shell git config --global user.name)\" && \
	./test_gitmux.sh"


define cleanup =
	repositoriesToDelete=$(gh repo list --limit 99 --json nameWithOwner --json name --jq '.[]|select(.name|startswith("gitmux_test_")).nameWithOwner')
	for r in ${repositoriesToDelete}; do
		echo "Deleting ${r}"
		gh api --method DELETE repos/"${r}"
	done
endef

cleanup: ; $(value cleanup)

.ONESHELL:
