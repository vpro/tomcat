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
ARG NAME=media-server

FROM npo-tomcat:dev

RUN apt-get -y install openssh-client sshpass

```
which then can be build this way:
```bash
~/npo/media/trunk$ docker build -t media-server media-server
```

