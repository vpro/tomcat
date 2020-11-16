FROM tomcat:9.0-jdk8-adoptopenjdk-hotspot

ENV CATALINA_BASE=/usr/local/catalina-base

RUN set -eux && \
  apt-get update && \
  apt-get -y install less && \
  mkdir -p ${CATALINA_BASE}/webapps && \
  mkdir -p ${CATALINA_BASE}/logs && \
  mkdir -p ${CATALINA_BASE}/work && \
  ln -s ${CATALINA_BASE}/logs ${CATALINA_BASE}/log && \
  mkdir -p ${CATALINA_BASE}/temp && \
  chgrp -R 0 ${CATALINA_BASE}/logs && \
  chmod -R g=u ${CATALINA_BASE}/logs && \
  chgrp -R 0 ${CATALINA_BASE}/work && \
  chmod -R g=u ${CATALINA_BASE}/work && \
  chgrp -R 0 ${CATALINA_BASE}/temp && \
  chmod -R g=u ${CATALINA_BASE}/temp

ADD catalina_base ${CATALINA_BASE}/
WORKDIR $CATALINA_BASE

