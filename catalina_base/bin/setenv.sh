#! /bin/bash

dir=$( dirname "${BASH_SOURCE[0]}")


if [[ -z "$LOG4J2" ]]; then
  export LOG4J2="log4j2.xml"
fi
export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configurationFile=${LOG4J2}"


# find out limit of current pod:
#limit=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`
# Substract 1.5G some for non heap useage
#heapsize=$((limit - 1500000000))

if [[ -z "$MaxRAMPercentage" ]] ; then
  MaxRAMPercentage=75.0
fi

# memory options
# -XX:MaxRAMPercentage=${MaxRAMPercentage}
# -XX:+UseContainerSupport                      Default, but lets be explicit, we target running in a container.
export CATALINA_OPTS="$CATALINA_OPTS -XX:MaxRAMPercentage=${MaxRAMPercentage} -XshowSettings:vm -XX:+UseContainerSupport"



# Heap dumps may be quite large, if you need to create them on out of memory, start the pod with environment variable HeapDumpPath=/data (or so)
if [[ ! -z "$HeapDumpPath" ]] ; then
  mkdir -p "${HeapDumpPath}"
  export CATALINA_OPTS="$CATALINA_OPTS -XX:HeapDumpPath=${HeapDumpPath} -XX:+HeapDumpOnOutOfMemoryError"
fi

# system property kibana can used in log4j2.xml SystemPropertyArbiter to switch to logging more specific to kibana
export CATALINA_OPTS="$CATALINA_OPTS -Dkibana=true"

# if libraries use java preferences api and sync those, avoid warnings in the log
export CATALINA_OPTS="$CATALINA_OPTS -Djava.util.prefs.userRoot=/data/prefs "

# This is unused, it is arranged in helm chart.
#export CATALINA_OUT_CMD="/usr/bin/rotatelogs -f $CATALINA_BASE/logs/catalina.out.%Y-%m-%d 86400"

CATALINA_LOGS=${CATALINA_BASE}/logs

mkdir -p /data/logs

# JMX
JMX_PORT=$($dir/jmx.sh)



# jmx settings
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=localhost -Duser.country=NL -Duser.timezone=Europe/Amsterdam -Ddata.dir=/data"

# gc logging
mkdir -p ${CATALINA_LOGS}/gclogs/
export CATALINA_OPTS="$CATALINA_OPTS -XX:NativeMemoryTracking=summary -Xlog:gc*=info:file=${CATALINA_LOGS}/gclogs/%t-gc.log:time,uptime,tags,level:filecount=10,filesize=10M"

# crash logging
export CATALINA_OPTS="$CATALINA_OPTS -XX:ErrorFile=${CATALINA_LOGS}/hs_err_pid%p.log"

# enabled assertions on test.
if [ "$ENVIRONMENT" == "test" ] ; then
  CATALINA_OPTS="$CATALINA_OPTS -ea"
fi


# JPDA debugger  is arranged in catalina.sh
export JPDA_ADDRESS=8000
export JPDA_TRANSPORT=dt_socket


# The complete container is dedicated to tomcat, so lets also use its tmp dir
export CATALINA_TMPDIR=/tmp

# note that this doesn't do anything when using catalina.sh run
export CATALINA_PID=${CATALINA_TMPDIR}/tomcat.pid


if [ -z ${TOMCAT_RELAXED_CHARS+x} ]; then  # +x: trick to check if variable is set.
  export TOMCAT_RELAXED_CHARS=''
fi

if [ -z ${TOMCAT_RELAXED_QUERY_CHARS+x} ]; then
  #export TOMCAT_RELAXED_QUERY_CHARS='[]|{}^&#x5c;&#x60;&quot;&lt;&gt;'
  export TOMCAT_RELAXED_QUERY_CHARS="$TOMCAT_RELAXED_CHARS"
fi
if [ -z ${TOMCAT_RELAXED_PATH_CHARS+x} ]; then
  export TOMCAT_RELAXED_PATH_CHARS="$TOMCAT_RELAXED_CHARS"
fi

if [ -z ${TOMCAT_ACCESS_LOG_FILE_DATE_FORMAT+x} ]; then
  export TOMCAT_ACCESS_LOG_FILE_DATE_FORMAT='yyyy-MM-dd'
fi


