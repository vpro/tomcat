#!/bin/bash

export CATALINA_PID=${CATALINA_BASE}/temp/tomcat.pid
export APPLICATION_OUT=${CATALINA_BASE}/logs/application.out
trap stop SIGTERM
var tailpid

function start() {
  # Call catalina.sh which arguments, and pipes output to a file
  # (analogous to catalina.out)

   (catalina.sh $([ "$CATALINA_ARGS" == "" ] && echo "jpda run" || echo "$CATALINA_ARGS") & echo $! > "${CATALINA_PID}") | /usr/bin/rotatelogs -L ${APPLICATION_OUT} -f  ${APPLICATION_OUT}.%Y-%m-%d 86400 &

   tail -F ${APPLICATION_OUT} 2>/dev/null & tailpid=$!
   wait $tailpid
}

stop(){
   catalinaPid=$(cat ${CATALINA_PID})
   echo "$(date -Iseconds) SIGTERM Killing catalina $catalinaPid" | tee -a "${APPLICATION_OUT}"
   kill -SIGTERM $catalinaPid
   # Waiting for it to end
   tail -f /dev/null --pid $catalinaPid
   # killing tail too
   kill -9 $tailpid
   exit
}

start


