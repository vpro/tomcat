#!/bin/bash

export CATALINA_PID=${CATALINA_BASE}/temp/tomcat.pid
export APPLICATION_OUT=${CATALINA_BASE}/logs/application.out
trap stop SIGTERM

var tailpid

function start() {
  # Call catalina.sh whith arguments, and pipes output to a file
  # (analogous to catalina.out, we call it 'application.out' to indicate that it is not arranged by catalina.sh itself)

  # TODO this is only tested with 'run', not with 'start'. If that would be a use case?

   (catalina.sh $([ "$CATALINA_ARGS" == "" ] && echo "jpda run" || echo "$CATALINA_ARGS") & echo $! > "${CATALINA_PID}") | /usr/bin/rotatelogs -L ${APPLICATION_OUT} -f  ${APPLICATION_OUT}.%Y-%m-%d 86400 &

  # Tail everying to stdout, so it will be picked up by kibana
   tail -F ${APPLICATION_OUT} 2>/dev/null & tailpid=$!
   wait $tailpid
}

stop(){
   # Trapped and received SIGTERM on pid 1.
   # Send one to the java process too, so that it will be shut down gracefully
   catalinaPid=$(cat ${CATALINA_PID})
   echo "$(date -Iseconds) SIGTERM Killing catalina $catalinaPid" >> "${APPLICATION_OUT}"
   kill -SIGTERM $catalinaPid
   # Waiting for it to end
   tail -f /dev/null --pid $catalinaPid
   # killing tail too
   echo "$(date -Iseconds) Process $catalinaPid has disappeared" >> "${APPLICATION_OUT}"
   kill -9 $tailpid
   echo "$(date -Iseconds) Ready"
   exit
}

start


