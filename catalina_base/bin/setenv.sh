#! /bin/bash

dir=$( dirname "${BASH_SOURCE[0]}")

if [[ -z "$LOG4J2" ]]; then
  export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configurationFile=file://${CATALINA_BASE}/conf/log4j2.kibana.xml"
else
  # explicit configured for log4j2
  export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configurationFile=${LOG4J2}"
fi
# find out limit of current pod:
limit=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`
# Substract 1.5G some for non heap useage
heapsize=$((limit - 1500000000))

export CATALINA_OPTS="$CATALINA_OPTS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap"

# system property kibana can used in log4j2.xml SystemPropertyArbiter to switch to logging more specific to kibana
export CATALINA_OPTS="$CATALINA_OPTS -Dkibana=true"

# if libraries use java preferences api, avoid warnings in the log
export CATALINA_OPTS="$CATALINA_OPTS -Djava.util.prefs.userRoot=/data/prefs "

# This is unused, it is arranged in helm chart.
#export CATALINA_OUT_CMD="/usr/bin/rotatelogs -f $CATALINA_BASE/logs/catalina.out.%Y-%m-%d 86400"

CATALINA_LOGS=${CATALINA_BASE}/logs

mkdir -p /data/logs

# JMX
JMX_PORT=$($dir/jmx.sh)

# jmx settings
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=localhost"

# gc logging
export CATALINA_OPTS="$CATALINA_OPTS -verbose:gc -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=5M -Xloggc:${CATALINA_LOGS}/gc.log"

#
export CATALINA_OPTS="$CATALINA_OPTS -XX:ErrorFile=${CATALINA_LOGS}/hs_err_pid%p.log"

# JPDA debugger  is arranged in catalina.sh
export JPDA_ADDRESS=8000
export JPDA_TRANSPORT=dt_socket

# note that this doesn't do anything when using catalina.sh run
export CATALINA_PID=${CATALINA_BASE}/temp/tomcat.pid


