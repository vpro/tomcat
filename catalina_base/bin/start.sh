#!/bin/bash
# Wrapper to  call catalina.sh in docker environment
# @author Michiel Meeuwissen
# 2022-09-02

export CATALINA_PID=/tmp/tomcat.pid
export CATALINA_LOGS=${CATALINA_BASE}/logs
export APPLICATION_OUT=${CATALINA_LOGS}/application.out


gdate() {
  date +%Y-%m-%dT%H:%M:%S.%3N
}

echo "$(gdate) Starting $0" >> ${APPLICATION_OUT}
trap stop SIGTERM


start() {
  # Call catalina.sh with arguments, and pipes output to a (rotated) file
  # (analogous to catalina.out, we call it 'application.out' to indicate that it is not arranged by catalina.sh itself)

  # TODO this is only tested with 'run', not with 'start'. If that would be a use case?
  ARGS=$([ "$CATALINA_ARGS" == "" ] && echo "jpda run" || echo "$CATALINA_ARGS")
  echo "$(gdate) Effective catalina arguments: '${ARGS}'" >> ${APPLICATION_OUT}
  catalina.sh ${ARGS} | (echo $! > ${CATALINA_PID}; /usr/bin/rotatelogs -L ${APPLICATION_OUT} -f  ${APPLICATION_OUT}.%Y-%m-%d 86400) &

   # Tail everything to stdout, so it will be picked up by kibana
   tail -F "${APPLICATION_OUT}" --pid $$  2>/dev/null & tailPid=$!

   # These log files of tomcats are rotated ending in log.yyyy-MM-dd
   # We want to most recent one to be linked to simply .log (that's handy with grep *log)
   # setup inotifywait in the background to arrange that.
   (
   while true
   do
     inotifywait -q -e create ${CATALINA_LOGS}/
     if compgen -G "$CATALINA_LOGS/catalina.log.*" > /dev/null; then
         ln -f $(ls -rt $CATALINA_LOGS/catalina.log.* | tail  -n1) $CATALINA_LOGS/catalina.log
     fi
     if compgen -G "$CATALINA_LOGS/localhost.log.*" > /dev/null; then
       ln -f $(ls -rt $CATALINA_LOGS/localhost.log.* | tail  -n1) $CATALINA_LOGS/localhost.log
     fi
   done
   ) &
   wait $tailPid
}

stop() {
   # Trapped and received SIGTERM on pid 1.
   # Send one to the java process too, so that it will be shut down gracefully
   local catalinaPid
   catalinaPid=$(cat ${CATALINA_PID})
   (echo "$(gdate) to kill"; pstree -C age -p -G -h  -t -a)  >> "${APPLICATION_OUT}"

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


