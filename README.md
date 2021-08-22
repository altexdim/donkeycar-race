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

# Step by step installation guide for the administrator
    
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

# Step by step guide for adding a new participant for the administrator

- [ ] Request all the necessary information from the participant
  - the SSH public key 
  - the docker image name from the dockerhub (pre-build container images are stored there)
- [ ] Add the participant to the SSH authentication file
    ```
    vim /home/dockeruser/.ssh/authorized_keys
    command="/home/dockeruser/bin/donkeysim-race.sh -p 18887 -i altexdim/donkeycar_race2 -n donkeysim_altex",restrict ssh-ed25519 AAAA...
    ```
  In this example:
  - `18887` is the local tcp port on the `dockerhost` to be able to change drive mode. Just use any free port.
  - `altexdim/donkeycar_race2` is the example of the image name provided from the participant
  - `donkeysim_altex` is the container name to refer to using docker command. You can choose any name you like for this particular participant. This will be used to start and stop the container. This will also restrict the usage of this container to only one instance at a time.
  - `restrict` pay extra attention to that argument, it's required to disallow shell access to the `dockerhost`
  - `/home/dockeruser/bin/donkeysim-race.sh` is our management script from the current repository

# Step by step guide for removing a participant for the administrator

- [ ] Remove the participant's SSH key from the SSH authentication file
    ```
    vim /home/dockeruser/.ssh/authorized_keys
    # REMOVE THIS LINE >>> command="...",restrict ssh-ed25519 AAAA...
    ```

# Step by step guide for participant to set everything up before the race

  - [ ] Prepare your SSH public key to access the `dockerhost` machine to manage you container
    ```
    ssh-keygen -t ed25519 -C "your_email@example.com" -f /home/myusername/.ssh/donkeysim_race
    ls -la /home/myusername/.ssh/donkeysim_race*
    # Output:
    # -rw------- 1 myusername myusername 464 Aug 22 23:18 /home/altex/.ssh/donkeysim_race
    # -rw-r--r-- 1 myusername myusername 104 Aug 22 23:18 /home/altex/.ssh/donkeysim_race.pub
    ```
    Where: 
    - `your_email@example.com` is you email address
    - `myusername` is your local username on your PC
    - `/home/myusername/.ssh/donkeysim_race` is your secure SSH private key
    - `/home/myusername/.ssh/donkeysim_race.pub` is your open SSH public key
  - [ ] Kindly ask the administrator to add your SSH public key to the system
    - Provide the following details
      - The content of your SSH public key: `/home/myusername/.ssh/donkeysim_race.pub`
      - Your docker container image name on the DockerHub: `myusername/donkeysim_race`
  - [ ] Kindly ask the administrator to provide you the username, the hostname, and the port to connect to
    You'll be provided with:
    - `dockeruser` is the dockeruser
    - `dockerhost` is the docker host domain name or ip address 
    - `dockerport` is the port number for the SSH access
    - Test that it's working: `ssh -T dockeruser@dockerhost -p dockerport`
  - [ ] Kindly ask the administrator to provide you with the hostname or IP address of the Simulation, as well as the port
    - Example: `simulation.host:9091`
    - Where:
      - `simulation.host` is the hostname or IP address of the Simulation
      - `9091` is the port number of the Simulation
    This IP address you'll be using when creating your docker container image.
  - [ ] Upload your docker container to the DockerHub, and remember you tag for the image you want to use.
    Use https://github.com/connected-autonomous-mobility/diyrobocar_docker_agent_pln as a general guidance on how to build you own docker container and to upload your docker image.
    - Also keep in mind the address of the Simulation (ie `simulation.host:9091`). Make sure you set in correctly in your config files before building the container locally and before uploading it to the DockerHub.
    - Also keep in mind that you don't have to activate autostart for you model if you provide the DonkeyCar compatible WebSocket API exposed in you container on the `tcp/8887` port. You'll be able to use a separate SSH command to start you car.  

# How to race guide for participant

  - [ ] To start the container

    ```
    ssh -T dockeruser@dockerhost -p 22 -- -c start_container -t v2 -r '"cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py"'
    ```
    Where:
    - `dockeruser` is the dockeruser provided by the administrator
    - `dockerhost` is the dockerhost provided by the administrator
    - `22` is the SSH port number provided by the administrator
    - `v2` is the Docker Image Tag which you used when uploading the docker image to the DockerHub
    - `cd /root/myrace/ && python3 /root/myrace/manage.py drive --model /root/myrace/models/mypilot_circuit_launch_19.h5 --myconfig=myconfig-trnm-local.py` is the example of the command you use inside you docker container to launch a model.
    - Keep in mind double quotes `-r '"<run_command>"'` - they are required. It's also not allowed to use any quotes inside the run_command otherwise it could fail to run.
    - Keep in mind that starting a docker container should not start a car automaticaly as we provide a separate SSH command to start a car.

  - [ ] After the race you have to stop your container as soon as possible. Prepare this command in advance in a separate linux console for easy access.

    ```
    ssh -T dockeruser@dockerhost -p 22 -- -c stop_container
    ```

  - [ ] When you hear "Ready, set, go!" you can run your car with that command

    ```
    ssh -T dockeruser@dockerhost -p 22 -- -c change_drive_mode -m local
    ```

    What it will do is 
    - It will send the following message
      ```
      {"angle":0,"throttle":0,"drive_mode":"local","recording":false}'
      ```
      to your container's `tcp/8887` port via WebSocket protocol
      using the URL `ws://127.0.0.1:8887/wsDrive`
    - As a reaction to that WebSocket message your car will start moving (if you are using the DonkeyCar framework, or if you implemented your WebSocket server on the `tcp/8887` port of your docker container)

  - [ ] (Optional) To stop you car you can use the following command

    ```
    ssh -T dockeruser@dockerhost -p 22 -- -c change_drive_mode -m local_angle
    ```
    or
    ```
    ssh -T dockeruser@dockerhost -p 22 -- -c change_drive_mode -m user
    ```
    
    It will send the following message
      ```
      {"angle":0,"throttle":0,"drive_mode":"local_angle","recording":false}'
      ```
      or
      ```
      {"angle":0,"throttle":0,"drive_mode":"user","recording":false}'
      ```
      to your container's `tcp/8887` port via WebSocket protocol
      using the URL `ws://127.0.0.1:8887/wsDrive`

# Troubleshooting

1. If a container doesn't see ```host.docker.internal``` host, then add ```--add-host=host.docker.internal:host-gateway``` to the docker run command
