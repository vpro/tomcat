FROM tomcat:10.1.20-jdk21-temurin-jammy
LABEL maintainer=digitaal-techniek@vpro.nl

ENV CATALINA_BASE=/usr/local/catalina-base

# used in add-cluster.sed
# od  -vN "32" -An -tx1             /dev/urandom | tr -d " \n"
ENV SECURE_ENCRYPTION_KEY="caec93ecb662c5b49c04723b3e8b0f33da64eaefeb3f426b22fe512687dc1a2a"

# Jars containing web resources and TLD's, which we use here and there.
ARG JARS_TO_SCAN="log4j-taglib*.jar,\
log4j-web*.jar,\
log4javascript*.jar,\
slf4j-taglib*.jar,\
log4j-taglib*.jar,\
vpro-shared-swagger*.jar,\
swagger-ui*,\
jstl*.jar,\
jakarta.servlet.jsp.jstl*.jar,\
svg*.jar,\
poms-thesaurus*.jar,\
flag-icon*.jar,\
media-domain*.jar,\
media-server*.jar,\
image-domain*.jar, \
poms-shared*.jar,\
meeuw*.jar,\
extjs-*.jar"

# Link to use in 404 page of tomcat
ARG CI_COMMIT_SHA
ARG CI_COMMIT_REF_NAME
ARG CI_COMMIT_TITLE
ARG CI_COMMIT_TIMESTAMP



# This makes ${USER.HOME} /
ENV HOME /
# Handy, on a new shell you'll be in the directory of interest
WORKDIR $CATALINA_BASE

COPY rds-ca-2019-root.der $JAVA_HOME/lib/security

# - Create the necessary dirs in catalina_base, with the needed permissions
# - set the jars to scan in catalian.properties
# - make the mount points and fill with example content which can be used when docker image is ran locally
# - install some useful tools
# -   rsync: avoid warnings for oc rsync
# -   curl: I forgot when this is needed, usefull for debugging. curl http://localhost:8080
# -   dnsutils: for debugging it's usefull to have tools like 'host' available.
# -   less, ncal: just for debugging, inspecting log files
# -   procps: just for debugging. 'ps'.
# -   psmisc: just for debugging. 'pstree'
# -   netcat: just for debugging. 'nc'.
# -   apache2-utils: we use rotatelogs to rotate catalina.out


# conf/Catalina/localhost Otherwise 'Unable to create directory for deployment: [/usr/local/catalina-base/conf/Catalina/localhost]'
RUN set -eux && \
  apt-get update && apt-get -y upgrade && \
  apt-get -y install less ncal procps curl rsync dnsutils  netcat apache2-utils  vim-tiny psmisc inotify-tools gawk && \
  keytool -importcert -alias rds-root -keystore ${JAVA_HOME}/lib/security/cacerts -storepass changeit -noprompt -trustcacerts -file $JAVA_HOME/lib/security/rds-ca-2019-root.der && \
  mkdir -p /conf


COPY rds-ca-2019-root.pem /conf

# Have a workable shell
SHELL ["/bin/bash", "-c"]

ENV TZ=Europe/Amsterdam
ENV PGTZ=Europe/Amsterdam
ENV HISTFILE=/data/.bash_history
ENV PSQL_HISTORY=/data/.pg_history
ENV PSQL_EDITOR=/usr/bin/vi
ENV LESSHISTFILE=/data/.lesshst

# 'When invoked as an interactive shell with the name sh, Bash looks for the variable ENV, expands its value if it is defined, and uses the expanded value as the name of a file to read and execute'
ENV ENV=/.binbash
COPY binbash /.binbash

# - Setting up timezone and stuff
# - We run always with a user named 'application' with uid '1001'
RUN echo "dash dash/sh boolean false" | debconf-set-selections &&  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
  dpkg-reconfigure --frontend noninteractive tzdata


# With bearable key bindings:
COPY inputrc /etc
# And a nicer bash prompt
COPY bashrc /.bashrc
# ' Failed to source defaults.vim' (even an empty vi config file like that avoid it)
COPY exrc /.exrc

# some files which might be needed during build
ADD clustering /tmp/clustering

VOLUME "/data" "/conf"

# note that this is unused in helm, it then uses container.command
CMD ["/usr/local/catalina-base/bin/start.sh"]
#CMD ["catalina.sh", "run"]

# We want to split off catalina base, default it's catalina_home
ADD catalina_base ${CATALINA_BASE}/

RUN  mkdir -p /data/logs  && \
  echo Catalina base: ${CATALINA_BASE} && \
  for directory in 'webapps' 'work'; do \
      mkdir -p ${CATALINA_BASE}/$directory && \
      rm -rf ${CATALINA_HOME}/$directory; \
  done && \
  rm -rf ${CATALINA_HOME}/webapps.dist && \
  chmod -R o-w ${CATALINA_HOME} && \
  chmod -R g=o ${CATALINA_HOME} && \
  chmod -R o-w ${CATALINA_BASE} && \
  chmod -R g=o ${CATALINA_BASE} && \
  mkdir -p  ${CATALINA_BASE}/conf/Catalina/localhost && \
  (cd ${CATALINA_BASE} && ln -s /data/logs logs) && \
  for directory in 'work'; do \
    mkdir -p ${CATALINA_BASE}/$directory && \
    chgrp -R 0 ${CATALINA_BASE}/$directory && \
    chmod -R g=u ${CATALINA_BASE}/$directory; \
  done && \
  sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"  ${CATALINA_BASE}/conf/catalina.properties && \
  mkdir ${CATALINA_BASE}/lib && \
  echo '#this file is hidden in openshift\nenv=localhost' > /conf/application.properties && \
  addgroup  --system --gid 1001 application && \
  adduser --system --uid 1001 application --gid 1001 --disabled-password --no-create-home  --home / && \
  adduser application root && \
  (echo -e "vpro/tomcat git version=${CI_COMMIT_SHA}\t${CI_COMMIT_REF_NAME}\t${CI_COMMIT_TIMESTAMP}\t${CI_COMMIT_TITLE}") > /DOCKER.BUILD && \
  (echo -n "vpro/tomcat build time=" ; date -Iseconds) >> /DOCKER.BUILD

# The onbuild commands to install the application when this image is overlaid

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG CONTEXT
ONBUILD ARG DOCLINK

ONBUILD ARG JARS_TO_SCAN=UNSET
ONBUILD ARG CLUSTERING
ONBUILD ARG COPY_TESTS
ONBUILD ARG CI_COMMIT_REF_NAME
ONBUILD ARG CI_COMMIT_SHA
ONBUILD ARG CI_COMMIT_TITLE
ONBUILD ARG CI_COMMIT_TIMESTAMP
ONBUILD ADD target/*${PROJECT_VERSION}.war /tmp/app.war


# if clustering, it also makes some sense to have a peristent work dir (to write sessions in)
ONBUILD RUN (\
     if [ -z "$CONTEXT" ] ; then \
        CONTEXT=ROOT; \
     fi && \
     cd ${CATALINA_BASE}/webapps && \
     mkdir -p ${CONTEXT} && \
     cd ${CONTEXT} && \
     jar xf /tmp/app.war && \
     rm /tmp/app.war &&\
     if [ "$CLUSTERING" == "true" ] ; then  \
         (cd ${CATALINA_BASE} && rm -r work && mkdir /data/work && ln -s /data/work work) && \
         cp -f /tmp/clustering/context.xml ${CATALINA_BASE}/conf/context.xml && \
         sed -E -i -f /tmp/clustering/add-cluster.sed  ${CATALINA_BASE}/conf/server.xml && \
         if [ "$COPY_TESTS" == "true" ] ; then cp /tmp/clustering/test-clustering.jspx .; fi ; \
     fi && \
     rm -rf /tmp/* \
     )

ONBUILD LABEL version="${PROJECT_VERSION}"
ONBUILD LABEL maintainer=digitaal-techniek@vpro.nl

# We need regular security patches. E.g. on every build of the application
ONBUILD RUN apt-get update && apt-get -y upgrade && \
  ( if [ "$JARS_TO_SCAN" != 'UNSET' ] ; then sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"   ${CATALINA_BASE}/conf/catalina.properties ; fi ) && \
  for errorfile in ${CATALINA_BASE}/errorpages/*.html  ; do \
    sed -E -i "s|class='doclink' href='(.*?)'|class='doclink' href='${DOCLINK:-https://wiki.vpro.nl/}'|g" ${errorfile} && \
    ( if [ "$CONTEXT" != 'ROOT' ] ; then sed -E -i "s|class='home' href='(.*?)'|class='home' href='/${CONTEXT}'|g" ${errorfile} ; fi ) ; \
  done && \
  (echo "${NAME} version=${PROJECT_VERSION}") >> /DOCKER.BUILD && \
  (echo -e "${NAME} git version=${CI_COMMIT_SHA}\t${CI_COMMIT_REF_NAME}\t${CI_COMMIT_TIMESTAMP}\t${CI_COMMIT_TITLE}") >> /DOCKER.BUILD && \
  (echo -n "${NAME} build time=" ; date -Iseconds) >> /DOCKER.BUILD

