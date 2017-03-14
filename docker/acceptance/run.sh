#!/bin/sh
START_TIME=$SECONDS
#set environment variables
export DOCKER_HOST_IP=$(docker-machine ip $(docker-machine active))

export CI_STAGE="ACCEPTANCE"
export CI_APPLICATION_IP=$DOCKER_HOST_IP
APP_IP="8080"

#Remove existing containers
docker-compose down
#start containers
docker-compose up -d

while [ -z ${APP_STARTED} ]; do
  echo "Waiting for app to start..."
  if [ "$(curl --silent ${DOCKER_HOST_IP}:${APP_IP}/_actuator/health 2>&1 | grep -q '\"status\":\"UP\"'; echo $?)" = 0 ]; then
      APP_STARTED=true;
  fi
  sleep 2
done

#run tests
cd ../..
mvn verify

#tear down
cd -
docker-compose down -v
echo "Total time: $(($SECONDS - $START_TIME))"
