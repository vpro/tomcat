#!/bin/bash

export CATALINA_PID=${CATALINA_BASE}/temp/tomcat.pid
export CATALINA_OUT=${CATALINA_BASE}/logs/catalina.out
trap stop SIGTERM

function start() {
  touch ${CATALINA_OUT}
   (catalina.sh $([ "$CATALINA_ARGS" == "" ] && echo "jpda run" || echo "$CATALINA_ARGS") & echo $! > "${CATALINA_PID}") | /usr/bin/rotatelogs -e -L ${CATALINA_OUT} -f ${CATALINA_OUT}.%Y-%m-%d 86400 &

   tail -F ${CATALINA_OUT} & wait $!
}

stop(){
   catalinaPid=$(cat ${CATALINA_PID})
   echo "$(date +'%F %T,%3N') killing $catalinaPid" | tee -a "$CATALINA_OUT"
   kill -SIGTERM $catalinaPid
   exit
}

start


