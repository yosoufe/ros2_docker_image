#!/bin/bash
function usage
{
    echo "usage: ./scripts.sh [[-b ] | [-r]]"
    echo "-b | --build          Build ros dev docker image"
    echo "-r | --run            Run ros dev docker image"
    echo "-p | --push           Push ros dev docker image"
    echo "-h | --help           This message"
}

IMAGE_NAME=yosoufe/rosdev
CONTAINER_NAME=ros2

build_image(){
    docker build -t $IMAGE_NAME .
}

run_image(){
    docker run \
        --name $CONTAINER_NAME \
        --runtime=nvidia \
        --gpus all \
        --net host \
        --cap-add NET_ADMIN \
        --rm \
        -it \
        -v /etc/passwd:/etc/passwd:ro \
        -v /etc/group:/etc/group:ro \
        -v /etc/shadow:/etc/shadow:ro \
        -u $(id -u):$(id -g) \
        -e DISPLAY \
        -v ${HOME}:${HOME}\
        $IMAGE_NAME 
}

exec_image(){
    docker exec \
        -it \
        $CONTAINER_NAME \
        bash
}

push_image(){
    docker push $IMAGE_NAME
}


if [ "$#" -lt 1 ]; then
    usage
fi

BUILD=false
RUN=false
PUSH=false

# Iterate through command line inputs
while [ "$1" != "" ]; do
    case $1 in
        -b | --build )          BUILD=true
                                ;;
        -r | --run )            RUN=true
                                ;;
        -br | -rb )             BUILD=true
                                RUN=true
                                ;;
        -p | --push )           PUSH=true
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

set -x

if [ "$BUILD" = true ] ; then
    build_image
fi

if [ "$RUN" = true ] ; then
    if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        run_image
    else
        exec_image
    fi
fi

if [ "$PUSH" = true ] ; then
    push_image
fi


set +x