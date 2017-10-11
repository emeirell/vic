#!/bin/bash

## USER-DEFINED VARIABLES
# Number of swarm workers desired
NUM_WORKERS=3
# name of routable (external) network
# this needs to be defined on your VCH using the '--container-network' option
# use 'docker network ls' to list available external networks
CONTAINER_NET=routable

## Advanced Variables - YOU PROBABLY DONT NEED TO MODIFY BEYOND THIS POINT
# Docker Container Host (DCH) image to use 
# see https://hub.docker.com/r/vmware/dch-photon/tags/ for list of available Docker Engine versions
DCH_IMAGE="vmware/dch-photon:17.06"
# name of swarm master node
NAME_MASTER="manager1"
# name of the docker volume for the swarm master
VOL_MASTER="registrycache"
# Worker node prefix
WORKER_PREFIX="worker"

#########################################################
## NO NEED TO MODIFY BEYOND THIS POINT
# pull the image
docker pull $DCH_IMAGE

# create a docker volume for the master image cache
docker volume create --opt Capacity=10GB --name $VOL_MASTER
# create and run the master instance
docker run -d -v $VOL_MASTER:/var/lib/docker \
  --net $CONTAINER_NET \
  --name $NAME_MASTER --hostname=$NAME_MASTER \
  $DCH_IMAGE
# get the master IP
SWARM_MASTER=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $NAME_MASTER)
# create the new swarm on the master
docker -H $SWARM_MASTER:2375 swarm init

# get the join token
SWARM_TOKEN=$(docker -H $SWARM_MASTER:2375 swarm join-token -q worker)
sleep 10

# run $NUM_WORKERS workers and use $SWARM_TOKEN to join the swarm
for i in $(seq "${NUM_WORKERS}"); do

  # create docker volumes for each worker to be used as image cache
  docker volume create  --opt Capacity=10GB --name $WORKER_PREFIX${i}-vol
  # run new worker container
  docker run -d -v $WORKER_PREFIX${i}-vol:/var/lib/docker \
    --net $CONTAINER_NET \
    --name $WORKER_PREFIX${i} --hostname=$WORKER_PREFIX${i}  \
    $DCH_IMAGE  
  # wait for daemon to start
  sleep 10

  # join worker to the swarm
  for w in $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $WORKER_PREFIX${i}); do
    docker -H $w:2375 swarm join --token ${SWARM_TOKEN} ${SWARM_MASTER}:2377
  done
 
done
 
# display swarm cluster information
printf "\nLocal Swarm Cluster\n=========================\n"

docker -H $SWARM_MASTER node ls

printf "=========================\nMaster available at DOCKER_HOST=$SWARM_MASTER:2375\n\n"
