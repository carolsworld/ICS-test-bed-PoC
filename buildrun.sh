#!/bin/bash

# This script is only usable on Linux with Docker installed.

# Environment configuration
client_amount=$1
client_name=flwr-client
server_name=flwr-server
network_name=flwr-network
client_image_name=flwr-client:1.0
server_image_name=flwr-server:1.0

# Download the CIFAR-10 dataset
python3 -c "from torchvision.datasets import CIFAR10; CIFAR10('./data', download=True)"

# Creates the network if it doesn't exist
docker network create $network_name

# Skip Docker image build if -s or --skip-build is passed as an argument
if [[ $* != *-s* ]] && [[ $* != *--skip-build* ]]
then

    # Rebuild the Docker image for server
    echo "Rebuilding server Docker image..."
    mv Dockerfile-server Dockerfile
    docker build -t $server_image_name .
    mv Dockerfile Dockerfile-server
    echo "Server Docker image has been rebuilt."

    # Rebuild the Docker image for client
    echo "Rebuilding client Docker image..."
    mv Dockerfile-client Dockerfile
    docker build -t $client_image_name .
    mv Dockerfile Dockerfile-client
    echo "Client Docker image has been rebuilt."

    # Deletes hanging (previous) image(s)
    echo "Cleaning up..."
    docker image prune --filter dangling=true -f

    # Deletes exisitng containers
    docker rm $server_name
    for i in $(seq 1 $client_amount)
    do
        docker rm "$client_name-$i"
    done

fi

# Creates containers and connects them to the fl_network
docker create --name $server_name --network $network_name $server_name:1.0
for i in $(seq 1 $client_amount)
do
    docker create --name "$client_name-$i" --network $network_name flwr-client:1.0
done

echo "All FL nodes have been created and connected to the fl_network."

# Starts the containers
docker start $server_name
sleep 3
for i in $(seq 1 $client_amount)
do
    docker start "$client_name-$i"
done