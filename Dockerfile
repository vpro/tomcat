FROM tomcat:9.0.69-jdk17-temurin-jammy
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
jakarta.servlet.jsp.jstl*.jar,\
svg*.jar,\
poms-thesaurus*.jar,\
flag-icon*.jar,\
media-domain*.jar,\
media-server*.jar,\
meeuw*.jar,\
extjs-*.jar"


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
  apt-get -y install less ncal procps curl rsync dnsutils  netcat apache2-utils  vim-tiny psmisc inotify-tools && \
  keytool -importcert -alias rds-root -keystore ${JAVA_HOME}/lib/security/cacerts -storepass changeit -noprompt -trustcacerts -file $JAVA_HOME/lib/security/rds-ca-2019-root.der && \
  mkdir -p /conf


COPY rds-ca-2019-root.pem /conf

# Have a workable shell
SHELL ["/bin/bash", "-c"]

ENV TZ=Europe/Amsterdam
ENV HISTFILE=/data/.bash_history
ENV PSQL_HISTORY=/data/.pg_history
ENV LESSHISTFILE=/data/.lesshst

# - Setting up timezone and stuff
# - We run always with a user named 'application' with uid '1001'
RUN echo "dash dash/sh boolean false" | debconf-set-selections &&  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
  dpkg-reconfigure --frontend noninteractive tzdata


# With bearable key bindings:
COPY inputrc /etc
# And a nicer bash prompt
COPY bashrc /.bashrc


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
  # I think we were not using this/it was not working
  #(cd ${CATALINA_BASE}/lib ; curl -O 'https://repo1.maven.org/maven2/io/github/devatherock/jul-jsonformatter/1.2.0/jul-jsonformatter-1.2.0.jar' ; curl -O 'https://repo1.maven.org/maven2/com/googlecode/json-simple/json-simple/1.1.1/json-simple-1.1.1.jar') && \
  echo '#this file is hidden in openshift\nenv=localhost' > /conf/application.properties && \
  addgroup  --system --gid 1001 application && \
  adduser --system --uid 1001 application --gid 1001 --disabled-password --no-create-home  --home / && \
  adduser application root && \
  (echo -n vpro/tomcat= ; date -Iseconds) > /DOCKER.BUILD


# The onbuild commands to install the application when this image is overlaid

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG CONTEXT

ONBUILD ADD target/*${PROJECT_VERSION}.war /tmp/app.war
ONBUILD RUN (\
     if [ -z "$CONTEXT" ] ; then \
        CONTEXT=ROOT; \
     fi && \
     cd ${CATALINA_BASE}/webapps && \
     mkdir -p ${CONTEXT} && \
     cd ${CONTEXT} && \
     jar xf /tmp/app.war && \
     rm /tmp/app.war \
     )

ONBUILD LABEL version="${PROJECT_VERSION}"
ONBUILD LABEL maintainer=digitaal-techniek@vpro.nl

# We need regular security patches. E.g. on every build of the application
ONBUILD RUN apt-get update && apt-get -y upgrade && \
   (echo -n ${NAME}.${PROJECT_VERSION}= ; date -Iseconds) >> /DOCKER.BUILD && \
   ln -sf /bin/bash /bin/sh

