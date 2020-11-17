FROM tomcat:9.0-jdk8-adoptopenjdk-hotspot

ENV CATALINA_BASE=/usr/local/catalina-base

RUN set -eux && \
  apt-get update && \
  apt-get -y install less && \
  for directory in 'webapps' 'logs' 'work' 'temp'; do \
      mkdir -p ${CATALINA_BASE}/$directory; \
  done && \
  ln -s ${CATALINA_BASE}/logs ${CATALINA_BASE}/log && \
  for directory in 'logs' 'work' 'temp'; do \
       chgrp -R 0 ${CATALINA_BASE}/$directory && \
       chmod -R g=u ${CATALINA_BASE}/$directory; \
  done

ADD catalina_base ${CATALINA_BASE}/
WORKDIR $CATALINA_BASE

