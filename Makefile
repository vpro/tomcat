

docker:
	docker build --build-arg CI_COMMIT_REF_NAME=`git branch --show-current` --build-arg CI_COMMIT_SHA=`git rev-parse HEAD` -t vpro/tomcat:latest .

run:
	docker run -i vpro/tomcat:latest

exec:
	docker run -it --entrypoint /bin/bash vpro/tomcat:latest
