#!/bin/bash
set -x #echo on

# vars
[ -z "$NUM_WORKERS" ] && NUM_WORKERS=2

# init swarm master
docker run -d --net "vic-container" --name manager-1 vmware/dinv:1.13

# get swarm master IP
SWARM_MASTER=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' manager-1)

docker -H $SWARM_MASTER swarm init

# get join token
SWARM_TOKEN=$(docker -H $SWARM_MASTER swarm join-token -q worker)
sleep 10

# run NUM_WORKERS workers with SWARM_TOKEN
for i in $(seq "${NUM_WORKERS}"); do

  # run new worker container
  docker run -d --name worker-${i} --hostname=worker-${i} \
    --net "vic-container" \
    vmware/dinv:1.13
  
  # add worker container to the cluster
  #for w in $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq))
  for w in $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' worker-${i})
  do

  docker -H $w:2375 swarm join --token ${SWARM_TOKEN} ${SWARM_MASTER}:2377
  done
 
done
 
# show swarm cluster
printf "\nLocal Swarm Cluster\n===================\n"

docker -H $SWARM_MASTER node ls
