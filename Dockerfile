FROM tomcat:9-jdk8-openjdk-slim

LABEL maintainer=digitaal-techniek@vpro.nl
ENV CATALINA_BASE=/usr/local/catalina-base

# Jars containing web resources and TLD's, which we use here and there.
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


# We want to split off catalina base, default it's catalina_home
ADD catalina_base ${CATALINA_BASE}/

# This makes ${USER.HOME} /
ENV HOME /

# Handy, on a new shell you'll be in the direcctory of interest
WORKDIR $CATALINA_BASE


# - Create the necessary dirs in catalina_base, with the needed permissions
# - Create a symlink  logs -> log (if no deployment needed to app cluster we'll simply let it log to logs directly)
# - set the jars to scan in catalian.properties
# - make the mount points and fill with example content which can be used when docker image is ran locally
RUN set -eux && \
  apt-get update && \
  apt-get -y install less && \
  for directory in 'webapps' 'logs' 'work' 'temp'; do \
      mkdir -p ${CATALINA_BASE}/$directory && \
      rm -rf ${CATALINA_HOME}/$directory; \
  done && \
  rm -rf ${CATALINA_HOME}/webapps.dist && \
  chmod -R o-w ${CATALINA_HOME} && \
  chmod -R g=o ${CATALINA_HOME} && \
  chmod -R o-w ${CATALINA_BASE} && \
  chmod -R g=o ${CATALINA_BASE} && \
  (cd ${CATALINA_BASE} && ln -s logs log) && \
  for directory in 'logs' 'work' 'temp'; do \
       chgrp -R 0 ${CATALINA_BASE}/$directory && \
       chmod -R g=u ${CATALINA_BASE}/$directory; \
  done && \
  sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"  ${CATALINA_BASE}/conf/catalina.properties && \
  mkdir /conf && \
  mkdir /data && \
  echo '#this file is hidden in openshift\nenv=localhost' > /conf/application.properties


VOLUME "/data" "/conf"

# The onbuild commands to install the application when this image is overlaid

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG CONTEXT
ONBUILD ARG TMP_WAR=/tmp/app.war

ONBUILD ADD target/${NAME}*.war ${TMP_WAR}
ONBUILD RUN (\
     if [ -z "$CONTEXT" ] ; then \
        CONTEXT=ROOT; \
     fi && \
     cd ${CATALINA_BASE}/webapps && \
     mkdir ${CONTEXT} && \
     cd ${CONTEXT} && \
     jar xf ${TMP_WAR} && \
     rm ${TMP_WAR} \
     )

ONBUILD LABEL version="${PROJECT_VERSION}"
ONBUILD LABEL name="${NAME}"
ONBUILD LABEL maintainer=digitaal-techniek@vpro.nl

