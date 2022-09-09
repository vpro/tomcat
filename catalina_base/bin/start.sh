#!/bin/bash
# Wrapper to  call catalina.sh in docker environment
# @author Michiel Meeuwissen
# 2022-09-02


export CATALINA_PID=${CATALINA_BASE}/temp/tomcat.pid
export APPLICATION_OUT=${CATALINA_BASE}/logs/application.out
trap stop SIGTERM

gdate() {
  date +%Y-%m-%dT%H:%M:%S.%3N
}

start() {
  # Call catalina.sh with arguments, and pipes output to a (rotated) file
  # (analogous to catalina.out, we call it 'application.out' to indicate that it is not arranged by catalina.sh itself)

  # TODO this is only tested with 'run', not with 'start'. If that would be a use case?
  ARGS=$([ "$CATALINA_ARGS" == "" ] && echo "jpda run" || echo "$CATALINA_ARGS")
  echo "$(gdate) Effective catalina arguments: '${ARGS}'" >> ${APPLICATION_OUT}
  catalina.sh ${ARGS} | (echo $! > ${CATALINA_PID}; /usr/bin/rotatelogs -L ${APPLICATION_OUT} -f  ${APPLICATION_OUT}.%Y-%m-%d 86400) &

   # Tail everything to stdout, so it will be picked up by kibana
   tail -F "${APPLICATION_OUT}" --pid $$  2>/dev/null & tailPid=$!
   wait $tailPid
}

stop() {
   # Trapped and received SIGTERM on pid 1.
   # Send one to the java process too, so that it will be shut down gracefully
   local catalinaPid
   catalinaPid=$(cat ${CATALINA_PID})
   (echo "$(gdate) to kill"; ps x -o pid,command)  >> "${APPLICATION_OUT}"

   echo "$(gdate) SIGTERM Killing catalina $catalinaPid" >> "${APPLICATION_OUT}"
   kill -SIGTERM $catalinaPid
   echo "$(gdate) Waiting for it." >> "${APPLICATION_OUT}"
   # Waiting for it to end, tail provides handy feature to do that.
   tail -f /dev/null --pid "$catalinaPid" 2>/dev/null
   echo "$(gdate) Process $catalinaPid has disappeared. Killing all other processes too"

   # kill all other processes (except pid 1, which is us, and we simply can gracefully exit)
   ps -o pid= x |  grep  -v "^\s*$$$" | xargs kill 2> /dev/null
   echo "$(gdate) Ready"

   exit 0
}

start


