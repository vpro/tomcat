s|<!--CLUSTERING-->|\
   <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster" channelSendOptions="async,secure">\
      <Channel className="org.apache.catalina.tribes.group.GroupChannel">\
         <Interceptor className="org.apache.catalina.tribes.group.interceptors.EncryptInterceptor"\
                     encryptionKey="${SECURE_ENCRYPTION_KEY}" />\
         <Membership className="org.apache.catalina.tribes.membership.cloud.CloudMembershipService"  />\
       </Channel>\
   </Cluster>|
