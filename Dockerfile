FROM tomcat:10.1.39-jre21-temurin-jammy
LABEL maintainer=digitaal-techniek@vpro.nl
LABEL org.opencontainers.image.description="This tomcat image is used by poms and vpro statefull set deployments"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ENV CATALINA_BASE=/usr/local/catalina-base

# used in add-cluster.sed
# generate one like this:
# od  -vN "32" -An -tx1             /dev/urandom | tr -d " \n"
ENV SECURE_ENCRYPTION_KEY=""

# Jars containing web resources (like web-fragments) and TLD's, which we use here and there.
ARG JARS_TO_SCAN="log4j-taglib*.jar,\
log4j-web*.jar,\
log4javascript*.jar,\
slf4j-taglib*.jar,\
log4j-taglib*.jar,\
vpro-shared-swagger*.jar,\
vpro-shared-monitoring*.jar,\
spring-web*.jar,\
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

ARG CI_COMMIT_SHA
ARG CI_COMMIT_REF_NAME
ARG CI_COMMIT_TITLE
ARG CI_COMMIT_TIMESTAMP

# This makes ${USER.HOME} /
ENV HOME=/
# Handy, on a new shell you'll be in the directory of interest
WORKDIR $CATALINA_BASE


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
# -   file: used by mediatools, generally useful
# -   unzip: to unzip the war  on build

COPY eu-central-1-bundle.pem /tmp
COPY importcerts.sh /tmp

RUN  keytool -list -cacerts > /tmp/cacerts.before && \
     bash -e /tmp/importcerts.sh && \
    keytool -list -cacerts > /tmp/cacerts.after

# avoid warnings about that from debconf
ARG DEBIAN_FRONTEND=noninteractive

# conf/Catalina/localhost Otherwise 'Unable to create directory for deployment: [/usr/local/catalina-base/conf/Catalina/localhost]'

# reinstall libc-bin  to avoid segmentation fault on arm?

RUN set -eux && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install less ncal procps curl rsync dnsutils  netcat apache2-utils  vim-tiny psmisc inotify-tools gawk file unzip && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /conf && \
  chmod 755 /conf


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
RUN echo "dash dash/sh boolean false" | debconf-set-selections &&  dpkg-reconfigure   dash && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
  dpkg-reconfigure  tzdata && \
  mkdir -p /scripts


# With bearable key bindings:
COPY inputrc /etc
# And a nicer bash prompt
COPY bashrc /.bashrc
# ' Failed to source defaults.vim' (even an empty vi config file like that avoid it)
COPY exrc /.exrc

# Clean up default /etc/bash.bashrc a bit (no call to groups)
COPY bash.bashrc /etc/bash.bashrc

# A script that can parse our access logs
COPY parse_tomcat_access_logs.pl /scripts


# some files which might be needed during build
ADD clustering /tmp/clustering

RUN mkdir -p /data /data/logs && \
  chmod 2775 /data /data/logs

VOLUME "/data" "/conf"

# note that this is unused in helm, it then uses container.command
CMD ["/usr/local/catalina-base/bin/start.sh"]
#CMD ["catalina.sh", "run"]

# We want to split off catalina base, default it's catalina_home
ADD catalina_base ${CATALINA_BASE}/

RUN echo Catalina base: ${CATALINA_BASE} && \
  rm -rf ${CATALINA_HOME}/webapps.dist && \
  chmod -R o-w ${CATALINA_HOME} && \
  chmod -R g=o ${CATALINA_HOME} && \
  chmod -R o-w ${CATALINA_BASE} && \
  chmod -R g=o ${CATALINA_BASE} && \
  mkdir -p  ${CATALINA_BASE}/conf/Catalina/localhost && \
  chmod 755 ${CATALINA_BASE}/conf/Catalina/localhost && \
  for directory in 'webapps' 'work'; do \
      mkdir -p ${CATALINA_BASE}/$directory && \
      rm -rf ${CATALINA_HOME}/$directory; \
  done && \
  chmod 755 ${CATALINA_BASE}/webapps && \
  chmod 775 ${CATALINA_BASE}/work && \
  (cd ${CATALINA_HOME} && rm -rf temp && rm -rf logs) && \
  (cd ${CATALINA_BASE} && ln -s /data/logs logs) && \
  sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"  ${CATALINA_BASE}/conf/catalina.properties && \
  mkdir ${CATALINA_BASE}/lib && \
  echo '#this file is hidden in openshift\nenv=localhost' > /conf/application.properties && \
  (echo -e "vpro/tomcat git version=${CI_COMMIT_SHA}\t${CI_COMMIT_REF_NAME}\t${CI_COMMIT_TIMESTAMP}\t${CI_COMMIT_TITLE}") > /DOCKER.BUILD && \
  (echo -n "vpro/tomcat build time=" ; date -Iseconds) >> /DOCKER.BUILD



# The onbuild commands to install the application when this image is overlaid

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG CONTEXT
ONBUILD ENV CONTEXT=${CONTEXT}

# Link to use in 404 page of tomcat
ONBUILD ARG DOCLINK
ONBUILD ENV DOCLINK=${DOCLINK}




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
     chmod 755 ${CONTEXT} && \
     cd ${CONTEXT} && \
     unzip -q /tmp/app.war && \
     rm /tmp/app.war &&\
     (cd ${CATALINA_BASE} && rm -r work && mkdir /data/work && chmod 2775 /data/work && ln -s /data/work work) && \
     if [ "$CLUSTERING" == "true" ] ; then  \
         cp -f /tmp/clustering/context.xml ${CATALINA_BASE}/conf/context.xml && \
         sed -E -i -f /tmp/clustering/add-cluster.sed  ${CATALINA_BASE}/conf/server.xml && \
         if [ "$COPY_TESTS" == "true" ] ; then cp /tmp/clustering/test-clustering.jspx .; fi ; \
     fi && \
     rm -rf /tmp/* \
     )


ONBUILD LABEL version="${PROJECT_VERSION}"

# We need regular security patches. E.g. on every build of the application
ONBUILD RUN apt-get update && apt-get -y upgrade && \
  apt-get clean && rm -rf /var/lib/apt/lists/* && \
  ( if [ "$JARS_TO_SCAN" != 'UNSET' ] ; then sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"   ${CATALINA_BASE}/conf/catalina.properties ; fi ) && \
  for errorfile in ${CATALINA_BASE}/errorpages/*.html  ; do \
    sed -E -i "s|class='doclink' href='(.*?)'|class='doclink' href='${DOCLINK:-https://wiki.vpro.nl/}'|g" ${errorfile} && \
    ( if [ "$CONTEXT" != 'ROOT' ] ; then sed -E -i "s|class='home' href='(.*?)'|class='home' href='/${CONTEXT}'|g" ${errorfile} ; fi ) ; \
  done && \
  (echo "${NAME} version=${PROJECT_VERSION}") >> /DOCKER.BUILD && \
  (echo -e "${NAME} git version=${CI_COMMIT_SHA}\t${CI_COMMIT_REF_NAME}\t${CI_COMMIT_TIMESTAMP}\t${CI_COMMIT_TITLE}") >> /DOCKER.BUILD && \
  (echo -n "${NAME} build time=" ; date -Iseconds) >> /DOCKER.BUILD


