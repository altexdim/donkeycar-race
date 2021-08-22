#!/bin/bash

usage_sh () { echo >&2 "Usage: $0 -p PORT -i IMAGE_NAME"; exit 1; }
usage_ssh () { echo >&2 'Usage: ssh -T user@host -- -c <start_container|change_drive_mode> [-t IMAGE_TAG] [-r '\''"RUN_COMMAND"'\''] [-m <user|local>]'; exit 1; }

while getopts p:i: flag
do
    case "${flag}" in
        p) port=${OPTARG};;
        i) image=${OPTARG};;
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

echo Executing a command:
echo "docker run --rm --network=donkeycar -p \"127.0.0.1:$port:8887\" \"$image:$ext_image_tag\" bash -c \"$ext_run_command\""

