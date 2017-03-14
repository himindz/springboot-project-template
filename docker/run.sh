#!/bin/sh
# Remove existing containers
docker-compose stop
docker-compose rm -f

#start containers
docker-compose up -d

#attach to logs
docker-compose logs -f
