.DEFAULT_GOAL := docker
IMAGE := vpro/tomcat:dev

help:     ## Show this help.
	@sed -n 's/^##//p' $(MAKEFILE_LIST)
	@grep -E '^[/%a-zA-Z._-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

docker:  ## Builds the image locally
	docker build --build-arg CI_COMMIT_REF_NAME=`git branch --show-current` --build-arg CI_COMMIT_SHA=`git rev-parse HEAD` --build-arg PROJECT_VERSION=`git rev-parse HEAD`  -t $(IMAGE) .

dockertest: ## Builds test image locally
	(cd test ; docker build --build-arg CI_COMMIT_REF_NAME=`git branch --show-current` --build-arg CI_COMMIT_SHA=`git rev-parse HEAD`  --build-arg CLUSTERING=true -t vpro/test:latest . )

run:  ## Run the build image
	docker run -i $(IMAGE)

exec: ## Look around in the build image
	docker run -it --entrypoint /bin/bash $(IMAGE)

exectest:
	docker run -it --entrypoint /bin/bash vpro/test:latest
