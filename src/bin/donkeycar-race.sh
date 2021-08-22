#!/bin/bash

usage_sh () { echo >&2 "Usage: $0 -p <PORT> -i <IMAGE_NAME> -n <CONTAINER_NAME>"; exit 1; }
usage_ssh () { echo >&2 'Usage: ssh -T user@host -- -c <start_container|stop_container|change_drive_mode> [-t IMAGE_TAG] [-r '\''"RUN_COMMAND"'\''] [-m <user|local|local_angle>]'; exit 1; }

while getopts p:i:n: flag
do
    case "${flag}" in
        p) port=${OPTARG};;
        i) image=${OPTARG};;
        n) conainer_name=${OPTARG};;
        [?]) usage_sh;;
    esac
done

if [ -z "$port" ]
then
    echo "Port variable is not set"
    usage_sh
fi
if [ -z "$image" ]
then
    echo "Image variable is not set"
    usage_sh
fi
if [ -z "$conainer_name" ]
then
    echo "Name variable is not set"
    usage_sh
fi

(
    echo "===="
    echo -n "Date: "
    date
    echo "Command: $0 $@"
    echo "Remote command: $SSH_ORIGINAL_COMMAND"
    echo "----"
)  | tee -a ~/logs/donkeycar-race-$conainer_name.log

COMMAND_ARRAY=()
while read line; do
  COMMAND_ARRAY+=("$line")
done < <(xargs -n 1 <<< "$SSH_ORIGINAL_COMMAND")

COMMAND_ARRAY_LEN=${#COMMAND_ARRAY[@]}
for (( i=0; i<$COMMAND_ARRAY_LEN; i++ )); do
    case "${COMMAND_ARRAY[$i]}" in
        "-c")
        ((i++))
        ext_command="${COMMAND_ARRAY[$i]}"
        ;;
        "-t")
        ((i++))
        ext_image_tag="${COMMAND_ARRAY[$i]}"
        ;;
        "-r") 
        ((i++))
        ext_run_command="${COMMAND_ARRAY[$i]}"
        ;;
        "-m") 
        ((i++))
        ext_mode="${COMMAND_ARRAY[$i]}"
        ;;
        [?]) usage_ssh;;
    esac
done

echo "Original command: '$SSH_ORIGINAL_COMMAND'"
echo "Port: $port"
echo "Image: $image"
echo "Container name: $conainer_name"
echo "Command: $ext_command"

case "${ext_command}" in
    start_container)
        if [ -z "$ext_image_tag" ]
        then
            echo "Image tag must be set for $ext_command"
            usage_ssh
        fi
        if [ -z "$ext_run_command" ]
        then
            echo "Run command must be set for $ext_command"
            usage_ssh
        fi

        echo "Image tag: $ext_image_tag"
        echo "Container run command: '$ext_run_command'"
    ;;

    stop_container)
        echo "Stop container"
    ;;

    change_drive_mode)
        if [ -z "$ext_mode" ]
        then
            echo "Mode must be set for $ext_command"
            usage_ssh
        fi

        echo "Mode: $ext_mode"
    ;;

    *) usage_ssh;;
esac

case "${ext_command}" in
    start_container)
        echo "Start container"
        echo Executing a command:
        set -x
        docker run --rm --name "$conainer_name" --network=donkeycar --add-host=host.docker.internal:host-gateway -p "127.0.0.1:$port:8887" "$image:$ext_image_tag" bash -c "$ext_run_command"
    ;;

    stop_container)
        echo "Stop container"
        echo Executing a command:
        set -x
        docker kill "$conainer_name"
    ;;

    change_drive_mode)
        if [ "$ext_mode" != "user" -a "$ext_mode" != "local" -a "$ext_mode" != "local_angle" ]
        then
            echo "Wrong mode: $ext_mode"
            usage_ssh
        fi

        echo "Change drive mode to $ext_mode"
        echo Executing a command:
        set -x
        echo '{"angle":0,"throttle":0,"drive_mode":"'"$ext_mode"'","recording":false}' | websocat "ws://127.0.0.1:$port/wsDrive"
    ;;

    *) usage_ssh;;
esac
