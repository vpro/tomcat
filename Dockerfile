FROM tomcat:9-jdk8-openjdk-slim

LABEL maintainer=digitaal-techniek@vpro.nl

##############################################################

# Build ImageMagick v7

# not available in debian yet?

# Borrowed from: https://github.com/dooman87/imagemagick-docker
ARG IM_VERSION=7.1.0-29
ARG LIB_HEIF_VERSION=1.12.0
ARG LIB_AOM_VERSION=3.3.0
ARG LIB_WEBP_VERSION=1.2.2

# TODO I think the way to do this would be rather be a  multi-stage build: https://docs.docker.com/develop/develop-images/multistage-build/
# There is no need for cleaning up then, and it's easier to keep the layer small.
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y git make gcc pkg-config autoconf curl g++ \
    # libaom
    yasm cmake \
    # libheif
    libde265-0 libde265-dev libjpeg-turbo8 libjpeg-turbo8-dev x265 libx265-dev libtool \
    # libwebp
    libsdl1.2-dev libgif-dev \
    # IM
    libpng16-16 libpng-dev libjpeg-turbo8 libjpeg-turbo8-dev libgomp1 ghostscript libxml2-dev libxml2-utils libtiff-dev libfontconfig1-dev libfreetype6-dev fonts-dejavu liblcms2-2 liblcms2-dev \
    # Install manually to prevent deleting with -dev packages
    libxext6 && \
    # Building libwebp
    git clone https://chromium.googlesource.com/webm/libwebp && \
    cd libwebp && git checkout v${LIB_WEBP_VERSION} && \
    ./autogen.sh && ./configure --enable-shared --enable-libwebpdecoder --enable-libwebpdemux --enable-libwebpmux --enable-static=no && \
    make && make install && \
    ldconfig /usr/local/lib && \
    cd ../ && rm -rf libwebp && \
    # Building libaom
    git clone https://aomedia.googlesource.com/aom && \
    cd aom && git checkout v${LIB_AOM_VERSION} && cd .. && \
    mkdir build_aom && \
    cd build_aom && \
    cmake ../aom/ -DENABLE_TESTS=0 -DBUILD_SHARED_LIBS=1 && make && make install && \
    ldconfig /usr/local/lib && \
    cd .. && \
    rm -rf aom && \
    rm -rf build_aom && \
    # Building libheif
    curl -L https://github.com/strukturag/libheif/releases/download/v${LIB_HEIF_VERSION}/libheif-${LIB_HEIF_VERSION}.tar.gz -o libheif.tar.gz && \
    tar -xzvf libheif.tar.gz && cd libheif-${LIB_HEIF_VERSION}/ && ./autogen.sh && ./configure && make && make install && cd .. && \
    ldconfig /usr/local/lib && \
    rm -rf libheif-${LIB_HEIF_VERSION} && rm libheif.tar.gz && \
    # Building ImageMagick
    git clone https://github.com/ImageMagick/ImageMagick.git && \
    cd ImageMagick && git checkout ${IM_VERSION} && \
    ./configure --without-magick-plus-plus --disable-docs --disable-static --with-tiff && \
    make && make install && \
    ldconfig /usr/local/lib && \
    apt-get remove --autoremove --purge -y gcc make cmake curl g++ yasm git autoconf pkg-config libpng-dev libjpeg-turbo8-dev libde265-dev libx265-dev libxml2-dev libtiff-dev libfontconfig1-dev libfreetype6-dev liblcms2-dev libsdl1.2-dev libgif-dev && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /ImageMagick

##############################################################

# Configure Tomcat image

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

COPY rds-ca-2019-root.der $JAVA_HOME/jre/lib/security

# This makes ${USER.HOME} /
ENV HOME /

# Handy, on a new shell you'll be in the directory of interest
WORKDIR $CATALINA_BASE

# - Create the necessary dirs in catalina_base, with the needed permissions
# - Create a symlink  logs -> log (if no deployment needed to app cluster we'll simply let it log to logs directly)
# - set the jars to scan in catalian.properties
# - make the mount points and fill with example content which can be used when docker image is ran locally
# - install some useful tools
# -   rsync: avoid warnings for oc rsync
# -   curl: I forgot when this is needed
# -   dnsutils: for debugging it's usefull to have tools like 'host' available.
# -   less: just for debugging
# -   procps: just for debugging. 'ps'.
# -   netcat: just for debugging. 'nc'.
# -   apache2-utils: we use rotatelogs to rotate catalina.out
RUN set -eux && \
  apt-get update && \
  apt-get -y install less procps curl rsync dnsutils  netcat apache2-utils  vim-tiny && \
  keytool -importcert -alias rds-root -keystore ${JAVA_HOME}/jre/lib/security/cacerts -storepass changeit -noprompt -trustcacerts -file $JAVA_HOME/jre/lib/security/rds-ca-2019-root.der && \
  mkdir -p /data/logs  && \
  mkdir /conf && \
  for directory in 'webapps' 'work' 'temp'; do \
      mkdir -p ${CATALINA_BASE}/$directory && \
      rm -rf ${CATALINA_HOME}/$directory; \
  done && \
  rm -rf ${CATALINA_HOME}/webapps.dist && \
  chmod -R o-w ${CATALINA_HOME} && \
  chmod -R g=o ${CATALINA_HOME} && \
  chmod -R o-w ${CATALINA_BASE} && \
  chmod -R g=o ${CATALINA_BASE} && \
  (cd ${CATALINA_BASE} && ln -s logs log && ln -s /data/logs logs) && \
  for directory in 'logs' 'work' 'temp'; do \
       chgrp -R 0 ${CATALINA_BASE}/$directory && \
       chmod -R g=u ${CATALINA_BASE}/$directory; \
  done && \
  sed -E -i "s|^(tomcat.util.scan.StandardJarScanFilter.jarsToScan[ \t]*=)(.*)$|\1${JARS_TO_SCAN}|g"  ${CATALINA_BASE}/conf/catalina.properties && \
  mkdir ${CATALINA_BASE}/lib && \
  (cd ${CATALINA_BASE}/lib ; curl -O 'https://repo1.maven.org/maven2/io/github/devatherock/jul-jsonformatter/1.1.0/jul-jsonformatter-1.1.0.jar' ; curl -O 'https://repo1.maven.org/maven2/com/googlecode/json-simple/json-simple/1.1.1/json-simple-1.1.1.jar') && \
  echo '#this file is hidden in openshift\nenv=localhost' > /conf/application.properties

COPY rds-ca-2019-root.pem /conf


# Have a workable shell
SHELL ["/bin/bash", "-c"]

ENV TZ=Europe/Amsterdam
ENV HISTFILE=/data/.bash_history
ENV PSQL_HISTORY=/data/.pg_history

RUN echo "dash dash/sh boolean false" | debconf-set-selections &&  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash ; exit 0 && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
  dpkg-reconfigure --frontend noninteractive tzdata

# With bearable key bindings:
COPY inputrc /etc
# And a nicer bash prompt
COPY bashrc /.bashrc

VOLUME "/data" "/conf"

# note that this is unused in helm, it then uses container.command
CMD ["catalina.sh", "jpda", "run"]
#CMD ["catalina.sh", "run"]

# We run always with a user named 'application' with uid '1001'
RUN addgroup  --system --gid 1001 application && \
    adduser --system --uid 1001 application --gid 1001 --disabled-password --no-create-home --home / && \
    adduser application root

# The onbuild commands to install the application when this image is overlaid

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG LABEL
ONBUILD ARG CONTEXT

ONBUILD ADD target/${NAME}*.war /tmp/app.war
ONBUILD RUN (\
     if [ -z "$CONTEXT" ] ; then \
        CONTEXT=ROOT; \
     fi && \

     cd ${CATALINA_BASE}/webapps && \
     mkdir ${CONTEXT} && \
     cd ${CONTEXT} && \
     jar xf /tmp/app.war && \
     rm /tmp/app.war \
     )

ONBUILD LABEL version="${PROJECT_VERSION}"
ONBUILD LABEL name="${LABEL}"
ONBUILD LABEL maintainer=digitaal-techniek@vpro.nl

# We need regular security patches. E.g. on every build of the application
ONBUILD RUN apt-get update && apt-get -y upgrade

#ONBUILD USER 1001
