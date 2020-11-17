# vpro-tomcat

Generic tomcat base image that:

1. Separates CATALINA_BASE
2. Prepares for a  proxy server that arranges https, and more customized tomcat configuration.

Use e.g. like so
```
FROM vpro-tomcat:latest
ARG PROJECT_VERSION=placeholder

ARG CONTEXT=v1
ARG TMP_WAR=/tmp/app.war
ADD target/api-server-${PROJECT_VERSION}.war ${TMP_WAR}

RUN (cd ${CATALINA_BASE}/webapps; mkdir ${CONTEXT} ; cd ${CONTEXT}; jar xf ${TMP_WAR} ; rm ${TMP_WAR})

```

