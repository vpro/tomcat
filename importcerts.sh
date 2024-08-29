

CERTS=$(grep 'END CERTIFICATE' /tmp/eu-central-1-bundle.pem | wc -l) ;
for N in $(seq 0 $(($CERTS - 1))); do
        cat /tmp/eu-central-1-bundle.pem | awk "n==$N { print }; /END CERTIFICATE/ { n++ }" |
             keytool -noprompt -trustcacerts -cacerts -importcert -alias "eu_central-$N"
done;
