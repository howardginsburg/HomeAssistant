# UP Squared AI Vision X Developer Kit

The [UP Squared Vision AI Vision X Developer Kit](https://up-board.org/upkits/up-squared-ai-vision-kit/) runs an Intel Atom X7 processor and a Intel Movidius Myriad X VPU for scoring machine learning models at the edge.  This device should be able to run Home Assistant and also Frigate for object detection.  Frigate can take advantage of the VPU for scoring models.

## Setup

The instructions provided by UP are dated, and getting everything you need to get OpenVino running is made tricky.  After doing a trials of installing, I created these instructions, and copied a few of the setup scripts to make things as streamlined as possible.

- The Wiki for the Up community can be found at https://github.com/up-board/up-community/wiki
- Full instructions for hardware setup can be found at https://github.com/up-board/up-community/wiki/Ubuntu_20.04.  Note, there is currently no kernel for Ubuntu 22.04 and beyond.

### Ubuntu Installation

1. Download the [Ubuntu 20.04 Desktop](https://releases.ubuntu.com/20.04.4/ubuntu-20.04.4-desktop-amd64.iso) ISO, burn it to a thumbdrive, and perform a minimal installation.
1. Run latest updates
    - `sudo apt update`
    - `sudo apt upgrade`
1. Install the UP kernel
    - `sudo add-apt-repository ppa:up-division/5.4-upboard`
    - `sudo apt update`
    - `sudo apt-get autoremove --purge 'linux-.*generic'` (Select No when prompted to Abort kernel removal)
    - `sudo apt-get install linux-generic-hwe-18.04-5.4-upboard`
    - `sudo apt dist-upgrade -y`
    - `sudo update-grub`
    - `sudo reboot`
1. Enable SSH
    - SSH
        - `sudo apt install openssh-server`
    - Enable root login
        - `sudo passwd root`
        - `sudo nano /etc/ssh/sshd_config`
            - Change the following line:
                `#PermitRootLogin prohibit-password`
            - To
                `PermitRootLogin yes`
        - `sudo service ssh restart`

### Docker Setup

1. Remove old versions of Docker
    - `for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done`
1. Add Dockers Apt repository
    - `sudo apt-get update`
    - `sudo apt-get install ca-certificates curl gnupg`
    - `sudo install -m 0755 -d /etc/apt/keyrings`
    - `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg`
    - `sudo chmod a+r /etc/apt/keyrings/docker.gpg`
    - ``` bash

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        ```
    - `sudo apt-get update`
    - `sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
