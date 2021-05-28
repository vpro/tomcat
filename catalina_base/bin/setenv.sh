#! /bin/bash

# log4j 1
export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configuration=log4j.kibana.xml"
# log4j 2
export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configurationFile=file://${CATALINA_BASE}/conf/log4j2.kibana.xml"

export CATALINA_OPTS="$CATALINA_OPTS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap"


# JMX
if [[ -z "$JMX_PORT" ]]; then
   JMX_PORT=3000
fi
# Since it is hard, if not impossible, to tunnel jmx to different ports on localhost, it is handier if different environment have different port numbers
if [[ "$POD_NAMESPACE" == *acc ]]; then
	JMX_PORT=$((JMX_PORT + 100))
fi
if [[ "$POD_NAMESPACE" == *test ]]; then
	JMX_PORT=$((JMX_PORT + 200))
fi


export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=localhost"

# JPDA
export JPDA_ADDRESS=8000
export JPDA_TRANSPORT=dt_socket
