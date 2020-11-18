FROM tomcat:9.0-jdk8-adoptopenjdk-hotspot

ENV CATALINA_BASE=/usr/local/catalina-base

ARG JARS_TO_SCAN="log4j-taglib*.jar,\
log4j-web*.jar,\
log4javascript*.jar,\
slf4j-taglib*.jar,\
vpro-shared-swagger*.jar,\
swagger-ui*,\
jstl*.jar,\
svg*.jar,\
poms-thesaurus*.jar,\
flag-icon*.jar,\
media-domain*.jar,\
media-server*.jar,\
meeuw*.jar,\
extjs-*.jar"

ADD catalina_base ${CATALINA_BASE}/

RUN set -eux && \
  apt-get update && \
  apt-get -y install less && \
  for directory in 'webapps' 'logs' 'work' 'temp'; do \
      mkdir -p ${CATALINA_BASE}/$directory; \
  done && \
  chmod -R o-w ${CATALINA_BASE} && \
  chmod -R g=o ${CATALINA_BASE} && \
  (cd ${CATALINA_BASE} && ln -s logs log) && \
  for directory in 'logs' 'work' 'temp'; do \
       chgrp -R 0 ${CATALINA_BASE}/$directory && \
       chmod -R g=u ${CATALINA_BASE}/$directory; \
  done && \
  sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"  ${CATALINA_BASE}/conf/catalina.properties

WORKDIR $CATALINA_BASE

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG CONTEXT
ONBUILD ARG TMP_WAR=/tmp/app.war

ONBUILD ADD target/${NAME}-${PROJECT_VERSION}.war ${TMP_WAR}
ONBUILD RUN (cd ${CATALINA_BASE}/webapps && mkdir ${CONTEXT} && cd ${CONTEXT} && jar xf ${TMP_WAR} && rm ${TMP_WAR})

