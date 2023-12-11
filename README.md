# HomeAssistant

This project is an attempt to run Home Assistant on a Nvidia Jetson Xavier AGX.  The goal is to have a single device that can run Home Assistant, ZoneMinder, and other services.  The Jetson Xavier AGX is a powerful device that can run multiple docker containers at the same time.  This allows for a single device to run multiple services.

## Hardware
1. [Nvidia Jetson Xavier AGX](https://developer.nvidia.com/embedded/jetson-agx-xavier-developer-kit)
1. [NVME Drive](https://www.amazon.com/gp/product/B08GL575DB/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&th=1) - this is just an example of what I had.
1. (Optional) USB Webcam 

## Software
### Jetson Xavier AGX
1. Install Nvidia Jetson Linux using the [SDK Manager](https://developer.nvidia.com/sdk-manager).
1. Install the latest updates.
```console
sudo apt-get update
sudo apt-get upgrade
```
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

### Zoneminder
This follows the [docs](https://zoneminder.readthedocs.io/en/stable/installationguide/ubuntu.html#easy-way-ubuntu-18-04-bionic) on Zoneminder with a few tweaks to work on Ubuntu 20.04.
1. `sudo apt-get install tasksel`
1. `sudo tasksel install lamp-server`
1. `sudo -i`
1. `add-apt-repository ppa:iconnor/zoneminder-1.36`
1. `apt-get update`
1. `apt-get upgrade`
1. `apt-get dist-upgrade`
1. `apt-get install zoneminder`
1. `rm /etc/mysql/my.cnf`  (this removes the current symbolic link)
1. `cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/my.cnf`
1. `nano /etc/mysql/my.cnf`
    under '[mysqld]' add `sql_mode = NO_ENGINE_SUBSTITUTION`
1. `systemctl restart mysql`
1.  `mysql -e "drop database zm;"`
1.  `mysql -uroot -p < /usr/share/zoneminder/db/zm_create.sql`
1.  `mysql -e "ALTER USER 'zmuser'@localhost IDENTIFIED BY 'zmpass';"`
1.  `mysql -e "GRANT ALL PRIVILEGES ON zm.* TO 'zmuser'@'localhost' WITH GRANT OPTION;"`
1.  `mysql -e "FLUSH PRIVILEGES ;"`
1.  `chmod 740 /etc/zm/zm.conf`
1.  `chown root:www-data /etc/zm/zm.conf`
1.  `chown -R www-data:www-data /usr/share/zoneminder/`
1.  `a2enmod cgi`
1.  `a2enmod rewrite`
1.  `a2enconf zoneminder`
1.  `systemctl enable zoneminder`
1.  `systemctl start zoneminder`
1.  `systemctl reload apache2`
1.  `mkdir /mnt/nvme/zoneminder`
1.  `add storage path /mnt/nvme/zoneminder`
1.  `chown -R www-data:www-data /mnt/nvme/zoneminder`
1.  Verify ZoneMinder is running at http://nvidia.local/zm

## Home Assistant
1. Copy the [docker-compose.yml](/docker-compose.yml) file to the NVME drive
    1. `sudo nano /mnt/nvme/docker-compose.yml`
    1. Copy the contents of the docker-compose.yml file in this repo to the file you just created.
    1. Optional: If you don't want to use a USB webcam, comment the lines in the docker-compose.yml for v4l2rtspserver.
1. Create a mosquitto configuration file
    1. `sudo mkdir /mnt/nvme/docker/mosquitto`
    1. `sudo nano /mnt/nvme/docker/mosquitto/mosquitto.conf`
    1. Copy the contents of the [mosquitto.conf](/mosquitto/mosquitto.conf) file in this repo to the file you just created.
1. Start Home Assistant
    1. `cd /mnt/nvme/docker/homeassistant`
    1. `sudo docker-compose up -d`
1. Open Home Assistant
    1. Open a browser and go to `http://nvidia:8123`


sudo docker run --device=/dev/video0 -p 8554:8554 -it mpromonet/v4l2rtspserver

## Helpful Commands
# Remove all Docker containers and images
1. `sudo docker rm -f $(sudo docker ps -aq) `
1. `sudo docker rmi -f $(sudo docker image ls -aq)`
