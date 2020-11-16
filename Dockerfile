FROM tomcat:9.0-jdk8-adoptopenjdk-hotspot

ENV CATALINA_BASE=/usr/local/catalina-base/
 
RUN set -eux && \
  apt-get update && \
  apt-get -y install less && \
  mkdir -p ${CATALINA_BASE} && 
  
ADD catalina_base/* ${CATALINA_BASE}
 