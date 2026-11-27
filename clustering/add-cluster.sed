# No 'secure' in channelSendOptions: recent tomcats (seen in 11.0.29) then require a TLS channel, which is not configured
# ('TLS is not available for this channel'), so sessions would not be replicated at all. The EncryptInterceptor encrypts the messages.
s|<!--CLUSTERING-->|\
   <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster" channelSendOptions="async">\
      <Channel className="org.apache.catalina.tribes.group.GroupChannel">\
         <Interceptor className="org.apache.catalina.tribes.group.interceptors.EncryptInterceptor"\
                     encryptionKey="${SECURE_ENCRYPTION_KEY}" />\
         <Membership className="org.apache.catalina.tribes.membership.cloud.CloudMembershipService"  />\
       </Channel>\
   </Cluster>|
