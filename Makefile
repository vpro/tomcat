.DEFAULT_GOAL := docker

.PHONY: exec access_logs
IMAGE := vpro/tomcat:dev

help:     ## Show this help.
	@sed -n 's/^##//p' $(MAKEFILE_LIST)
	@grep -E '^[/%a-zA-Z._-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

docker:  ## Builds the image locally
	docker build --build-arg CI_COMMIT_REF_NAME=`git branch --show-current` --build-arg CI_COMMIT_SHA=`git rev-parse HEAD` --build-arg PROJECT_VERSION=`git rev-parse HEAD`  -t $(IMAGE) .

dockertest: ## Builds test image locally
	(cd test ; docker build --build-arg CI_COMMIT_REF_NAME=`git branch --show-current` --build-arg CI_COMMIT_SHA=`git rev-parse HEAD`  --build-arg CLUSTERING=true -t vpro/test:latest . )

run:  ## Run the build image
	docker run -e CATALINA_DEBUG_EVAL='[[ $$POD_NAME == *-0 ]] && echo true || echo false' -e POD_NAME=test-0  -i $(IMAGE)

exec: ## Look around in the build image
	docker run -it --entrypoint /bin/bash -v /data:/data $(IMAGE)

exectest:
	docker run -it --entrypoint /bin/bash vpro/test:latest

access_logs:
	docker run -it --entrypoint /bin/bash -e CONTEXT=v1 -v $(PWD):/tmp -v /data:/data  $(IMAGE)
