# NVidia Jetson Xavier Setup

This section highlights the setup of the NVidia Jetson Xavier AGX.  This is the hardware that will run ZoneMinder.  The Jetson Xavier AGX is a powerful device that can run ZoneMinder and other services.

## Hardware
1. [Nvidia Jetson Xavier AGX](https://developer.nvidia.com/embedded/jetson-agx-xavier-developer-kit)
1. [NVME Drive](https://www.amazon.com/gp/product/B08GL575DB/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&th=1) - this is just an example of what I had.
1. (Optional) [Jumper Caps](https://www.amazon.com/dp/B077957RN7?psc=1&ref=ppx_yo2ov_dt_b_product_details)

## NVME Installation

Installing the NVME drive was pretty straight forward.  JetsonHacks has a great [tutorial](https://jetsonhacks.com/2018/10/18/install-nvme-ssd-on-nvidia-jetson-agx-developer-kit/).

## Auto Power-On

The [Carrier Board Specification](https://developer.nvidia.com/embedded/downloads#?search=Jetson%20AGX%20Xavier%20Developer%20Kit%20Carrier%20Board%20Specification) has a section on how to auto power on the device.  This is useful if you want to use the Jetson Xavier AGX in a remote location and have it power on when power is restored.

For the pins located at J508, place a jumper across pins 5 and 6.

![Image](/images/autopoweron.jpg)

## Jetson Xavier AGX Setup
1. Install Nvidia Jetson Linux using the [SDK Manager](https://developer.nvidia.com/sdk-manager).
1. Install the latest updates.
    1. `sudo apt-get update`
    1. `sudo apt-get upgrade`
1. Change hostname to 'nvidia'
    1. `hostnamectl set-hostname nvidia`
1. Mount NVME drive
    1. `lsblk`
    1. `sudo mkfs.ext4 /dev/nvme0n1` This will format the drive
    1. `sudo mkdir /mnt/nvme`
    1. `sudo mount /dev/nvme0n1 /mnt/nvme`
    1. `sudo chown -R $USER:$USER /mnt/nvme`
    1. `sudo chmod -R 777 /mnt/nvme`
    1. `sudo nano /etc/fstab`
        1. Add `/dev/nvme0n1 /mnt/nvme ext4 defaults 0 0`
1. Set nvidia container toolkit to be docker daemon default and set the storage location to be the NVME drive
    1. `sudo nvidia-ctk runtime configure --runtime=docker`
    1. `sudo nano /etc/docker/daemon.json`
        1. Add `"data-root": "/mnt/nvme/docker"`
    1. Your daemon.json file should look like this.
        ```json
        {
            "runtimes": {
                "nvidia": {
                    "path": "nvidia-container-runtime",
                    "runtimeArgs": []
                }
            },
            "data-root": "/mnt/nvme/docker"
        }
        ```
    1. `sudo systemctl daemon-reload`
    1. `sudo systemctl restart docker`
1. Install docker-compose
    1. `sudo apt-get install -y libffi-dev libssl-dev python3 python3-pip`
    1. `sudo pip3 install docker-compose`
1. Install jtop (Optional)
    This is a tool to monitor the Jetson Xavier AGX.
    1. Option 1:
        1. Install Pip
            1. `sudo apt-get install python3-pip`
        1. Install jtop
            1. `sudo -H pip3 install -U jetson-stats`
            1. `sudo reboot`
            1. Run jtop to see the stats of the Jetson Xavier AGX
            1. `sudo jtop`
    1. Option 2:
        1. Run the docker container.
            1. `sudo docker run --rm -it -v /run/jtop.sock:/run/jtop.sock rbonghi/jetson_stats:latest`
