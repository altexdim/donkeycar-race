# Objectives

1. To run/stop a docker container via ssh -T command in restricted mode
2. To change the driving mode from user to local (and back) for a donker car via ssh
3. To resrtict the access to the containers to only the Simulation

# Functional requirements

User params

* docker image tag:  
    ```
    eg: "v2"
    ```  
* run command:  
    ```
    eg: "cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py"
    ```  
* a command:  
    ```
    eg: "start_container|stop_container|change_drive_mode"
    ```

Admin params

+ local port for mapping host's tcp port to container's tcp/8887 port
+ docker image name: `eg: "altexdim/donkeycar_race2"`
+ docker container name: `eg: "donkeycar_altex"`
   
Example of the resulting command:
```
docker run --rm --network=donkeycar -p "127.0.0.1:$admin_defined_port:8887" "$user_docker_image:$image_tag" bash -c "$user_command"
```

# Plan

1. Write a script

[+] figure out how to pass user arguments inside the script
    ```$SSH_ORIGINAL_COMMAND```
[+] figure out how to restrict terminal access, meaning -T should be enforced, so no real terminal is allowed
    ```
    cat /home/testuser/.ssh/authorized_keys
    command="...",restrict
    ```
[-] hardening security of the script
    * kill a docker container after some time
    * kill a docker container after connection is lost
    * maybe implement a watchdog
    * killswitch to stop all the participants' containers

2. Configure the network and firewall
    [+] figure out how to enable internet access for the manually created docker bridge user-defined network
        ```docker network create donkeycar```
    [+] figure out how to restrict the access to the desired host/port in iptables
        * docker network inspect donkeycar - copy network address
        ```
        iptables -I DOCKER-USER 1 -s 93.184.216.34/32 -d 172.18.0.0/16 -j RETURN
        iptables -I DOCKER-USER 2 -s 172.18.0.0/16 -d 93.184.216.34/32 -j RETURN
        iptables -I DOCKER-USER 3 -s 172.18.0.0/16 -d 172.18.0.0/16 -j RETURN
        iptables -I DOCKER-USER 4 -s 172.18.0.0/16 -j REJECT --reject-with icmp-port-unreachable
        iptables -I DOCKER-USER 5 -d 172.18.0.0/16 -j REJECT --reject-with icmp-port-unreachable
        iptables -I DOCKER-USER 6 -j RETURN
        ```
    [-] hardening security of the donkeycar network
        * actually iptables is enough
3. Add ability to change driving mode
    [-] figure out which command to pass to websocket: eg {change_mode=local}
    [-] figure out how to send WS command in console
4. Installation
    [+] How to run docker console commands from non-root user
        ```sudo usermod -aG docker testuser```
    [+] Logs
        ```mkdir /home/testuser/logs```
    [+] General
        ```
        touch /home/testuser/.ssh/authorized_keys
        copy script to /home/testuser/bin/donkeycar-race.sh
        ```

# Output 

1. The example of adding a participant

    ```
    cat /home/testuser/.ssh/authorized_keys
    command="/home/testuser/bin/donkeycar-race.sh -p 18887 -i altexdim/donkeycar_race2 -n donkeycar_altex",restrict ssh-ed25519 AAAA...
    ```

2. The example of running a docker container

    ```
    ssh -T testuser@localhost -- -c start_container -t v2 -r '"cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py"'
    ```

3. The example of stopping a docker container

    ```ssh -T testuser@localhost -- -c stop_container```

4. The example of starting a car

    ```ssh -T testuser@localhost -- -c change_drive_mode -m local```

5. The example of stopping a car

    ```ssh -T testuser@localhost -- -c change_drive_mode -m user```
