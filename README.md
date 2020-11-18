# npo-tomcat

Generic tomcat base image that:

1. Separates CATALINA_BASE
2. Prepares for a  proxy server that arranges https, and more customized tomcat configuration.



You can build this locally like so:
```
docker build -t npo-tomcat:dev .
```
Use e.g. like so
```
ARG PROJECT_VERSION=5.20-SNAPSHOT
ARG NAME=media-server
ARG CONTEXT=ROOT

FROM npo-tomcat:dev

RUN apt-get -y install openssh-client sshpass

```
which then can be build this way:
```bash
~/npo/media/trunk$ (VERSION=$(mvn -q  -Dexec.executable=echo -Dexec.args='${project.version}' -N  exec:exec) ; docker build -t media:$VERSION --build-arg PROJECT_VERSION=$VERSION media-server)
```

