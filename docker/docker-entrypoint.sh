#!/bin/sh
if [[ -n "$JAVA_NAMING_PROVIDER_URL" ]]; then
  JAVA_OPTS="$JAVA_OPTS -Djava.naming.provider.url=$JAVA_NAMING_PROVIDER_URL"
fi

exec java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -jar /app.jar
exec "$@"
