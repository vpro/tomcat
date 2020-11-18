# npo-tomcat

Generic tomcat base image that:

1. Separates CATALINA_BASE
2. Prepares for a  proxy server that arranges https, and more customized tomcat configuration.

Use e.g. like so
```
ARG PROJECT_VERSION=5.20-SNAPSHOT
ARG NAME=media-server
ARG CONTEXT=ROOT

FROM npo-tomcat:dev

RUN apt-get -y install openssh-client sshpass

```

You can build this locally like so:
```
docker build -t npo-tomcat .
```

And use it like so:
```bash

$ cd ~/npo/media/trunk
~/npo/media/trunk$ (VERSION=$(mvn -q  -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive  exec:exec) ; docker build -t media:$VERSION --build-arg PROJECT_VERSION=$VERSION media-server)
```

