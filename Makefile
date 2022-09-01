

docker:
	docker build -t vpro/tomcat:latest .

run:
	docker run -i vpro/tomcat:latest

exec:
	docker run -it --entrypoint /bin/bash vpro/tomcat:latest
