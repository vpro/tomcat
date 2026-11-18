#! /bin/bash

dir=$( dirname "${BASH_SOURCE[0]}")

JAVA_MAJOR_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)


# find out limit of current pod:
#limit=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`
# Substract 1.5G some for non heap useage
#heapsize=$((limit - 1500000000))

# memory options
# These can be set via environment variables (MaxRAMPercentage, GarbageCollectionOption, NativeMemoryTracking),
# but options already present in CATALINA_OPTS take precedence. A warning is printed if both are set explicitly.
# -XX:+UseContainerSupport is default, but lets be explicit, we target running in a container.

MaxRAMPercentage_explicit=${MaxRAMPercentage:+1}
if [[ -z "$MaxRAMPercentage" ]] ; then
  MaxRAMPercentage=75.0
fi
GarbageCollectionOption_explicit=${GarbageCollectionOption:+1}
if [[ -z "$GarbageCollectionOption" ]] ; then
  GarbageCollectionOption=-XX:+UseG1GC
  # GarbageCollectionOption=-XX:+UseZGC
fi
NativeMemoryTracking_explicit=${NativeMemoryTracking:+1}
if [[ -z "$NativeMemoryTracking" ]] ; then
  NativeMemoryTracking=summary
fi

if [[ ! "$CATALINA_OPTS" =~ -XX:\+Use[A-Za-z]*GC ]] ; then
  export CATALINA_OPTS="$CATALINA_OPTS ${GarbageCollectionOption}"
elif [[ -n "$GarbageCollectionOption_explicit" ]] ; then
  echo "WARNING: GarbageCollectionOption is set, but CATALINA_OPTS already contains a GC option; GarbageCollectionOption will be ignored." >&2
fi
if [[ "$CATALINA_OPTS" =~ (^|[[:space:]])-Xmx[0-9] ]] ; then
  if [[ -n "$MaxRAMPercentage_explicit" ]] ; then
    echo "WARNING: MaxRAMPercentage is set, but CATALINA_OPTS already sets -Xmx explicitly, which takes precedence; MaxRAMPercentage will be ignored." >&2
  fi
elif [[ "$CATALINA_OPTS" != *"-XX:MaxRAMPercentage="* ]] ; then
  export CATALINA_OPTS="$CATALINA_OPTS -XX:MaxRAMPercentage=${MaxRAMPercentage}"
  if [[ -n "$MaxRAMPercentage_explicit" ]] && [[ "$CATALINA_OPTS" =~ (^|[[:space:]])-Xms[0-9] ]] ; then
    echo "WARNING: MaxRAMPercentage is set, and CATALINA_OPTS also sets -Xms explicitly; if -Xms is larger than the resulting percentage-based max heap, it will override MaxRAMPercentage." >&2
  fi
elif [[ -n "$MaxRAMPercentage_explicit" ]] ; then
  echo "WARNING: MaxRAMPercentage is set, but CATALINA_OPTS already contains -XX:MaxRAMPercentage=; MaxRAMPercentage will be ignored." >&2
fi
if [[ "$CATALINA_OPTS" != *"-XX:NativeMemoryTracking="* ]] ; then
  export CATALINA_OPTS="$CATALINA_OPTS -XX:NativeMemoryTracking=${NativeMemoryTracking}"
elif [[ -n "$NativeMemoryTracking_explicit" ]] ; then
  echo "WARNING: NativeMemoryTracking is set, but CATALINA_OPTS already contains -XX:NativeMemoryTracking=; NativeMemoryTracking will be ignored." >&2
fi
if [[ "$CATALINA_OPTS" != *"-XshowSettings:vm"* ]] ; then
  export CATALINA_OPTS="$CATALINA_OPTS -XshowSettings:vm"
fi
if [[ "$CATALINA_OPTS" != *"UseContainerSupport"* ]] ; then
  export CATALINA_OPTS="$CATALINA_OPTS -XX:+UseContainerSupport"
fi



# Heap dumps may be quite large, if you need to create them on out of memory, start the pod with environment variable HeapDumpPath=/data (or so)
if [[ ! -z "$HeapDumpPath" ]] ; then
  mkdir -p "${HeapDumpPath}"
  chmod 775 "${HeapDumpPath}"
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
chmod 2775 /data/logs

# JMX
JMX_PORT=$($dir/jmx.sh)

# jmx settings
export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=localhost -Duser.country=NL -Duser.timezone=Europe/Amsterdam -Ddata.dir=/data"

# gc logging
mkdir -p ${CATALINA_LOGS}/gclogs/
chmod 2775 ${CATALINA_LOGS}/gclogs/
export CATALINA_OPTS="$CATALINA_OPTS -Xlog:gc*=info:file=${CATALINA_LOGS}/gclogs/%t-gc.log:time,uptime,tags,level:filecount=10,filesize=10M"

# crash logging
export CATALINA_OPTS="$CATALINA_OPTS -XX:ErrorFile=${CATALINA_LOGS}/hs_err_pid%p.log"

# enabled assertions on test.
if [ "$ENVIRONMENT" == "test" ] ; then
  CATALINA_OPTS="$CATALINA_OPTS -ea"
fi

if [[ $CATALINA_ARGS == *"jpda"* ]]; then
  # JPDA debugger  is arranged in catalina.sh
  export JPDA_ADDRESS=8000
  export JPDA_TRANSPORT=dt_socket
fi

# liliput to reduce cpu/memory load unless explicitly disabled (requires Java 25+, where it is no longer experimental)
if [[ "${DISABLE_COMPACT_HEADERS}" != "true" ]] && [ "$JAVA_MAJOR_VERSION" -ge 25 ] 2>/dev/null; then
  export CATALINA_OPTS="$CATALINA_OPTS -XX:+UseCompactObjectHeaders"
fi

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

if [ -z ${TOMCAT_ENCODED_SOLIDUS_HANDLING+x} ]; then
   export TOMCAT_ENCODED_SOLIDUS_HANDLING='passthrough'
fi

if [ -z ${TOMCAT_ACCESS_LOG_FILE_DATE_FORMAT+x} ]; then
  export TOMCAT_ACCESS_LOG_FILE_DATE_FORMAT='yyyy-MM-dd'
fi

if [ -z ${TOMCAT_CONNECTION_TIMEOUT+x} ]; then
  export TOMCAT_CONNECTION_TIMEOUT=20000
fi

if [ -z ${TOMCAT_MAX_THREADS+x} ]; then
  export TOMCAT_MAX_THREADS=400
fi

if [ -z ${TOMCAT_ASYNC_TIMEOUT+x} ]; then
  export TOMCAT_ASYNC_TIMEOUT=30000
fi

if [ -z ${TOMCAT_ACCEPT_COUNT+x} ]; then
  export TOMCAT_ACCEPT_COUNT=100
fi

if [ -z ${TOMCAT_SCHEME+x} ]; then
  export TOMCAT_SCHEME=https
fi

if [ -z ${TOMCAT_EXECUTOR+x} ]; then
  export TOMCAT_EXECUTOR=tomcat-virtual-thread-executor
fi
if [ -z ${TOMCAT_STUCK_THREAD_DETECTION_INTERRUPT_THREAD_THRESHOLD+x} ] ; then
  export TOMCAT_STUCK_THREAD_DETECTION_INTERRUPT_THREAD_THRESHOLD=-1
fi
if [ -z ${TOMCAT_STUCK_THREAD_DETECTION_THRESHOLD+x} ] ; then
  export TOMCAT_STUCK_THREAD_DETECTION_THRESHOLD=600
fi


# These variables may be used by tomcat clustering
if [ -r /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
  if [ -z "${KUBERNETES_NAMESPACE+x}" ]; then
    KUBERNETES_NAMESPACE=$(< /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    export KUBERNETES_NAMESPACE
  fi
  #When set, it appends a labelSelector to the pod-list request.
  if [ -z "${KUBERNETES_LABELS+x}" ]; then
    KUBERNETES_LABELS=application=$(hostname | sed 's/-[[:digit:]]*$//')
    export KUBERNETES_LABELS
  fi
fi
