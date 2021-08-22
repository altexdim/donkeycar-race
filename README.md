# Objectives

1. To run/stop a docker container via ssh -T command in restricted mode. 
2. To change the driving mode from user to local (and back) for a donker car via ssh -T command in restricted mode.
3. To resrtict the access to the containers to only the Simulation

# Functional requirements

User params
    - docker image tag: eg: "v2"
    - run command: eg: "cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py"
    - a command: eg: "start_container|change_drive_mode"

example of resulting command
    docker run -it --rm --network donkeycar -p "$admin_defined_port:8887" "$user_docker_image" bash -c "$user_command"


Admin params
    - local port for mapping host's tcp port to container's tcp/8887 port
    - docker image name: eg: "altexdim/donkeycar_race2"
    
# Plan

1. Write a script
    + figure out how to pass user arguments inside the script
    + figure out how to restrict terminal access, meaning -T should be enforced, so no real terminal is allowed
    - hardening security of the script
2. Configure the network and firewall
    - figure out how to enable internet access for the manually created docker bridge user-defined network
    - figure out how to restrict the access to the desired host/port in iptables
    - hardenint security of the donkeycar network
3. Add ability to change driving mode
    - figure out which command to pass to websocket: eg {change_mode=local}
    - figure out how to send WS command in console
4. Installation
    + how to run docker console commands from non-root user

# Output 

1. The example of set up

cat /home/testuser/.ssh/authorized_keys

command="/home/testuser/bin/donkeycar-race.sh -p 18887 -i altexdim/donkeycar_race2",no-port-forwarding,no-x11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA...

<CTRL+C> for abort

2. The example of running a docker container

ssh -T testuser@localhost -- -c start_container -t v2 -r "cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py"

3. The example of starting a car

ssh -T testuser@localhost -- -c change_drive_mode -m local

4. The example of stopping a car

ssh -T testuser@localhost -- -c change_drive_mode -m user
