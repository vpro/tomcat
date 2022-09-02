#!/bin/bash
# Wrapper to  call catalina.sh in docker environment
# @author Michiel Meeuwissen
# 2022-09-02


export CATALINA_PID=${CATALINA_BASE}/temp/tomcat.pid
export APPLICATION_OUT=${CATALINA_BASE}/logs/application.out
trap stop SIGTERM

function start() {
  # Call catalina.sh with arguments, and pipes output to a (rotated) file
  # (analogous to catalina.out, we call it 'application.out' to indicate that it is not arranged by catalina.sh itself)

  # TODO this is only tested with 'run', not with 'start'. If that would be a use case?
  ARGS=$([ "$CATALINA_ARGS" == "" ] && echo "jpda run" || echo "$CATALINA_ARGS")
  echo "$(date -Iseconds) Effective catalina arguments: '${ARGS}'" >> ${APPLICATION_OUT}
  (catalina.sh ${ARGS} & echo $! > "${CATALINA_PID}") | /usr/bin/rotatelogs -L ${APPLICATION_OUT} -f  ${APPLICATION_OUT}.%Y-%m-%d 86400 &

  # Tail everything to stdout, so it will be picked up by kibana
   tail -F "${APPLICATION_OUT}" --pid $$  2>/dev/null & tailPid=$!
   wait $tailPid
}

function stop() {
   # Trapped and received SIGTERM on pid 1.
   # Send one to the java process too, so that it will be shut down gracefully
   local catalinaPid
   catalinaPid=$(cat ${CATALINA_PID})
   echo "$(date -Iseconds) SIGTERM Killing catalina $catalinaPid" >> "${APPLICATION_OUT}"
   kill -SIGTERM $catalinaPid
   # Waiting for it to end, tail provides handy feature to do that.
   tail -f /dev/null --pid $catalinaPid

   echo "$(date -Iseconds) Process $catalinaPid has disappeared" >> "${APPLICATION_OUT}"
   echo "$(date -Iseconds) Ready"

   ps aux
   exit 0
}

start


