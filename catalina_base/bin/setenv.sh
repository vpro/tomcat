export CATALINA_OPTS="$CATALINA_OPTS -Dlog4j.configuration=log4j.kibana.xml -Dlog4j.configurationFile=file://${CATALINA_BASE}/conf/log4j2.kibana.xml -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap  -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=3000 -Dcom.sun.management.jmxremote.rmi.port=3000 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=localhost"

export JPDA_ADDRESS=8000
export JPDA_TRANSPORT=dt_socket
