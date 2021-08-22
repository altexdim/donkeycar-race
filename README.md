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
+ docker container name: `eg: "donkeysim_altex"`
   
Example of the resulting command:
```
docker run --rm --network=donkeysim -p "127.0.0.1:$admin_defined_port:8887" "$user_docker_image:$image_tag" bash -c "$user_command"
```

# Plan

1. Write a script

    - [x] figure out how to pass user arguments inside the script
        ```$SSH_ORIGINAL_COMMAND```
    - [x] figure out how to restrict terminal access, meaning -T should be enforced, so no real terminal is allowed
        ```
        cat /home/dockeruser/.ssh/authorized_keys
        command="...",restrict
        ```
    - [ ] hardening security of the script
        * kill a docker container after some time
        * kill a docker container after connection is lost
        * maybe implement a watchdog
        * killswitch to stop all the participants' containers

2. Configure the network and firewall
    - [x] figure out how to enable internet access for the manually created docker bridge user-defined network
        ```docker network create donkeysim```
    - [x] figure out how to restrict the access to the desired host/port in iptables
        * find out and copy the network address for the newly created network
        ```docker network inspect donkeysim```
        * add firewall rules
        ```
        # 93.184.216.34 - is just an example here, this is supposed to be the Sim ip address
        # 172.18.0.0/16 - this is our donkeysim network
        iptables -I DOCKER-USER 1 -s 93.184.216.34/32 -d 172.18.0.0/16 -j RETURN
        iptables -I DOCKER-USER 2 -s 172.18.0.0/16 -d 93.184.216.34/32 -j RETURN
        iptables -I DOCKER-USER 3 -s 172.18.0.0/16 -d 172.18.0.0/16 -j RETURN
        iptables -I DOCKER-USER 4 -s 172.18.0.0/16 -j REJECT --reject-with icmp-port-unreachable
        iptables -I DOCKER-USER 5 -d 172.18.0.0/16 -j REJECT --reject-with icmp-port-unreachable
        iptables -I DOCKER-USER 6 -j RETURN
        ```
      * dont forget to save the rules so they'll be there after restart ```service iptables save```
        
    - [ ] hardening security of the donkeysim network
        * actually iptables is enough
3. Add ability to change driving mode
    - [x] figure out which command to pass to websocket: eg {change_mode=local}
      ```
      {"angle":0,"throttle":0,"drive_mode":"local_angle","recording":false}
      
      ```
    - [x] figure out how to send WS command in console
      ```
      echo '{"angle":0,"throttle":0,"drive_mode":"local_angle","recording":false}' | websocat ws://127.0.0.1:8887/wsDrive
      
      ```
4. Installation details
    - [x] How to run docker console commands from non-root user
        ```sudo usermod -aG docker dockeruser```
    - [x] Logs
        ```mkdir /home/dockeruser/logs```
    - [x] General
        ```
        touch /home/dockeruser/.ssh/authorized_keys
        copy script to /home/dockeruser/bin/donkeysim-race.sh
        ```
# Step by step installation for the administrator
    
- [ ] Add a local linux user on the docker host machine.
  Note that it's needed only one local linux user to run all the participans' containers.
  There's no need to add as many local linux users as the number of participants.
  - `dockeruser` is used in the examples throughout this document. 
  - `dockerhost` is used as a reference to the docker host machine in this document.
- [ ] (Optional) It would be also a wise idea to disable login by password (so the only option for the authentication is a public key) in `/etc/sshd/sshd.conf`, and to change the SSH port from
  the default `22` to something random like `28974`.
- [ ] Add a local linux user to the docker group to be able to run docker commands for that user.
  ``` 
  # "dockeruser" - is the local linux user on the dockerhost host
  sudo usermod -aG docker dockeruser
  ```
- [ ] Create the SSH authentication file for that user
  ``` 
  mkdir /home/dockeruser/.ssh/
  chmod 600 /home/dockeruser/.ssh/
  touch /home/dockeruser/.ssh/authorized_keys
  chmod 600 /home/dockeruser/.ssh/authorized_keys
  ```
- [ ] Create a folder for logs
  ```
  mkdir /home/dockeruser/logs/
  ```
- [ ] Put the `src/bin/donkeysim-race.sh` file from this repository to the bin folder for the local user 
  ```
  mkdir /home/dockeruser/bin/
  # git clone {this_repo}  
  # cp {this_repo}/src/bin/donkeysim-race.sh /home/dockeruser/bin/donkeysim-race.sh
  chmod +x /home/dockeruser/bin/donkeysim-race.sh
  ```
- [ ] Add a user-defined bridge network called `donkeysim` for the docker
  ```
  docker network create donkeysim
  ```
- [ ] Inspect the `donkeysim` network for IP address and network mask
  ```
  docker network inspect donkeycar | grep Subnet
  # Output: "Subnet": "172.18.0.0/16",
  ```
- [ ] Add the firewall rules for the docker network
    ```
    # Sim ip: 93.184.216.34 - is just an example here, this is supposed to be the Simulator ip address
    # Donkersim net: 172.18.0.0/16 - this is our donkeysim network
    iptables -I DOCKER-USER 1 -s 93.184.216.34/32 -d 172.18.0.0/16 -j RETURN
    iptables -I DOCKER-USER 2 -s 172.18.0.0/16 -d 93.184.216.34/32 -j RETURN
    iptables -I DOCKER-USER 3 -s 172.18.0.0/16 -d 172.18.0.0/16 -j RETURN
    iptables -I DOCKER-USER 4 -s 172.18.0.0/16 -j REJECT --reject-with icmp-port-unreachable
    iptables -I DOCKER-USER 5 -d 172.18.0.0/16 -j REJECT --reject-with icmp-port-unreachable
    iptables -I DOCKER-USER 6 -j RETURN
    ```
- [ ] Save the firewall rules
    ```
    # (optional) mkdir /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ```
    Note that on Ubuntu it's needed to instal the additional packege to restore the firewall rules on stratup
    ```
    # sudo apt-get install iptables-persistent
    ```

# Output 

1. The example of adding a participant

    ```
    # open up the ssh authentication config for the user dockeruser
    vim /home/dockeruser/.ssh/authorized_keys
    # add the line like this:
    command="/home/dockeruser/bin/donkeysim-race.sh -p 18887 -i altexdim/donkeycar_race2 -n donkeysim_altex",restrict ssh-ed25519 AAAA...
    ```

2. The example of running a docker container

    ```
    ssh -T dockeruser@localhost -- -c start_container -t v2 -r '"cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py"'
    ```

3. The example of stopping a docker container

    ```ssh -T dockeruser@dockerhost -- -c stop_container```

4. The example of starting a car

    ```ssh -T dockeruser@dockerhost -- -c change_drive_mode -m local```

5. The example of stopping a car

    ```ssh -T dockeruser@localhost -- -c change_drive_mode -m user```

# Troubleshooting

1. If a container doesn't see ```host.docker.internal``` host, then add ```--add-host=host.docker.internal:host-gateway``` to the docker run command
