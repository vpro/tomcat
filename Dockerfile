FROM tomcat:9-jdk8-openjdk-slim

LABEL maintainer=digitaal-techniek@vpro.nl

##############################################################

# Build ImageMagick v7
# Borrowed from: https://github.com/dooman87/imagemagick-docker

ARG IM_VERSION=7.0.11-2
ARG LIB_HEIF_VERSION=1.11.0
ARG LIB_AOM_VERSION=2.0.2

RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y git make gcc pkg-config autoconf curl g++ \
    # libaom
    yasm cmake \
    # libheif
    libde265-0 libde265-dev libjpeg62-turbo libjpeg62-turbo-dev x265 libx265-dev libtool \
    # IM
    libpng16-16 libpng-dev libjpeg62-turbo libjpeg62-turbo-dev libwebp6 libwebp-dev libgomp1 libwebpmux3 libwebpdemux2 ghostscript libxml2-dev libxml2-utils && \
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
    ./configure --without-magick-plus-plus --disable-docs --disable-static && \
    make && make install && \
    ldconfig /usr/local/lib && \
    apt-get remove --autoremove --purge -y gcc make cmake curl g++ yasm git autoconf pkg-config libpng-dev libjpeg62-turbo-dev libwebp-dev libde265-dev libx265-dev libxml2-dev && \
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

# Handy, on a new shell you'll be in the direcctory of interest
WORKDIR $CATALINA_BASE


# - Create the necessary dirs in catalina_base, with the needed permissions
# - Create a symlink  logs -> log (if no deployment needed to app cluster we'll simply let it log to logs directly)
# - set the jars to scan in catalian.properties
# - make the mount points and fill with example content which can be used when docker image is ran locally
RUN set -eux && \
  apt-get update && \
  apt-get -y install less procps curl && \
  keytool -importcert -alias rds-root -keystore ${JAVA_HOME}/jre/lib/security/cacerts -storepass changeit -noprompt -trustcacerts -file $JAVA_HOME/jre/lib/security/rds-ca-2019-root.der && \
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
  mkdir ${CATALINA_BASE}/lib && \
  (cd ${CATALINA_BASE}/lib ; curl -O 'https://repo1.maven.org/maven2/io/github/devatherock/jul-jsonformatter/1.1.0/jul-jsonformatter-1.1.0.jar' ; curl -O 'https://repo1.maven.org/maven2/com/googlecode/json-simple/json-simple/1.1.1/json-simple-1.1.1.jar') && \
  echo '#this file is hidden in openshift\nenv=localhost' > /conf/application.properties

COPY rds-ca-2019-root.pem /conf

VOLUME "/data" "/conf"


#CMD ["catalina.sh", "run"]
CMD ["catalina.sh", "jpda", "run"]

# The onbuild commands to install the application when this image is overlaid

ONBUILD ARG PROJECT_VERSION
ONBUILD ARG NAME
ONBUILD ARG CONTEXT
ONBUILD ARG TMP_WAR=/tmp/app.war
ONBUILD ARG LABEL=${NAME}

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
ONBUILD LABEL name="${LABEL}"
ONBUILD LABEL maintainer=digitaal-techniek@vpro.nl

