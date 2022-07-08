#! /bin/bash

dir=$( dirname "${BASH_SOURCE[0]}")

# We used to default to log4j

# If applications are adapted this can be simplified.
# log4j 1
export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configuration=log4j.kibana.xml"

# So there _must_ be a log4j2.kibana.xml for now.
# log4j 2
if [[ -z "$LOG4J2" ]]; then
  export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configurationFile=file://${CATALINA_BASE}/conf/log4j2.kibana.xml"
else
	export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configurationFile=${LOG4J2}"
fi
export CATALINA_OPTS="$CATALINA_OPTS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap"


# system property kibana can used in log4j2.xml SystemPropertyArbiter to switch to logging more specific to kibana
export CATALINA_OPTS="$CATALINA_OPTS -Dkibana=true"


mkdir -p /data/logs

# JMX

JMX_PORT=$($dir/jmx.sh)

export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=localhost"

export CATALINA_OPTS="$CATALINA_OPTS -verbose:gc -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=5M -Xloggc:${CATALINA_BASE}/logs/gc.log"

# JPDA
export JPDA_ADDRESS=8000
export JPDA_TRANSPORT=dt_socket
