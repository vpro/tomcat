# a script to output the jmx port for the current server

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
echo $JMX_PORT
