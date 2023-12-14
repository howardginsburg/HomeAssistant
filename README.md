# HomeAssistant and ZoneMinder on Nvidia Jetson Xavier AGX

This project is an attempt to run Home Assistant and Zoneminder on a Nvidia Jetson Xavier AGX.  The goal is to have a single device that can run Home Assistant, ZoneMinder, and other supporting services.  The Jetson Xavier AGX is a powerful device that can run multiple docker containers at the same time.  This allows for a single device to run multiple services.

## Hardware
1. [Nvidia Jetson Xavier AGX](https://developer.nvidia.com/embedded/jetson-agx-xavier-developer-kit)
1. [NVME Drive](https://www.amazon.com/gp/product/B08GL575DB/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&th=1) - this is just an example of what I had.
1. (Optional) [USB Webcam](https://www.amazon.com/WEDOKING-Microphone-Streaming-Computer-Portable/dp/B08HZ5GNF9) 
1. (Optional) [Jumper Caps](https://www.amazon.com/dp/B077957RN7?psc=1&ref=ppx_yo2ov_dt_b_product_details)

### Auto Power-On

The [Carrier Board Specification](https://developer.nvidia.com/embedded/downloads#?search=Jetson%20AGX%20Xavier%20Developer%20Kit%20Carrier%20Board%20Specification) has a section on how to auto power on the device.  This is useful if you want to use the Jetson Xavier AGX in a remote location and have it power on when power is restored.

For the pins located at J508, place a jumper across pins 5 and 6.

![Image](/images/autopoweron.jpg)

### Jetson Xavier AGX Setup
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

## Software Setup

Most of the software setup is done using docker containers.  This allows for easy setup and configuration.  The docker-compose file is located in the [docker-compose.yaml](/docker-compose.yml) folder.

1. Copy the [docker-compose.yml](/docker-compose.yml) file to /mnt/nvme

### Zoneminder
Unfortunately there are no good docker based options for Zoneminder, so we will have a do a manual install.  This follows the [docs](https://zoneminder.readthedocs.io/en/stable/installationguide/ubuntu.html#easy-way-ubuntu-18-04-bionic) on Zoneminder with a few tweaks to work on Ubuntu 20.04.

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
1. `sudo nano /etc/mysql/my.cnf`
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
1.  `chown -R www-data:www-data /mnt/nvme/zoneminder`
We need to change the port that Apache listens on to 81.  This is because the swag/letsencrypt container requires port 80.
1.  `sudo nano /etc/apache2/ports.conf`
    change the Listen port to 81.
1. `sudo nano /etc/apache2/sites-enabled/000-default.conf`
    change <VirtualHost *:80> to <VirtualHost *:81>
1. `sudo systemctl restart apache2`

#### Zoneminder Configuration
1.  Verify ZoneMinder is running at http://nvidia.local:81/zm
1.  Under 'Options -> Storage' add the add storage path `/mnt/nvme/zoneminder`
1.  Under 'Options -> Users' change the password for the admin user
1.  Under 'Options -> Users' add a new user for Home Assistant.  Select all menu options to View/Enable including API.  This user will be used by Home Assistant to access ZoneMinder.
1.  Under 'Options -> System' enable the 'OPT_USE_AUTH' option.  This will require all users to login before accessing ZoneMinder.

### MQTT Broker

HomeAssistant and Zoneminder communicate using MQTT.  This is a lightweight messaging protocol that is easy to setup and use.  The docker-compose file includes a MQTT broker.

1. Create a mosquitto configuration file
    1. `sudo mkdir /mnt/nvme/mosquitto/config`
    1. Copy the contents of the [mosquitto.conf](/mnt/nvme/mosquitto/config/mosquitto.conf) to the new folder.

### Home Assistant

1. Create the Home Assistant configuration file
    1. `sudo mkdir /mnt/nvme/docker/homeassistant/config`
    1. Copy the contents of the [configuration.yaml](/mnt/nvme/homeassistant/configuration.yaml) to the new folder.
    1. Edit the configuration.yaml file and change the password for the ZoneMinder user.

### DuckDNS

We will use [DuckDNS](https://www.duckdns.org/) to create a free domain name that will point to our home network.  This will allow us to access Home Assistant and ZoneMinder from outside our home network.

1. Create a DuckDNS account
1. Create a domain name
1. Create a token
1. Edit the docker-compose file edit the DuckDNS section
    1. `sudo nano /mnt/nvme/docker-compose.yml`
    1. Replace the domain name with your domain name
    1. Replace the token with your token
    
### Sample Webcam (Optional)

The docker-compose file includes a sample usb webcam.  This is useful for testing ZoneMinder.  If you don't want to use this as part of your setup, you can remove the v4l2rtspserver section from the docker-compose file.

You can also manually run the container by running:
1. `sudo docker run --device=/dev/video0 -p 8554:8554 -it mpromonet/v4l2rtspserver`

### Enable Port Forwarding

1. Enable port forwarding on your router for ports 22 (SSH), 80 (HTTP for ZoneMinder), 443, and 8123 (HTTP for HomeAssistant).  This will allow you to access Home Assistant and ZoneMinder from outside your home network.  It's recommended that you select different port numbers for the external ports.  I used 2222 for SSH, 8080 for ZoneMinder, and 8123 for Home Assistant.  This will help prevent unwanted access to your devices.

### Setup the CRON job to copy the SSL certificates to the /ssl folder

1. `sudo mkdir /mnt/nvme/ssl`
1. Copy the [ssl.sh](/mnt/nvme/ssl.sh) file to new folder
1. Edit ssl.sh and replace the domain name with your domain name
1. `sudo crontab -e`
1. Add the following line to the crontab file
    1. `0 */1 * * * /mnt/nvme/ssl.sh`

### Get the first set of SSL certificates

1. Edit the docker-compose file and update the 'url' and 'email' fields in the swag section.
    1. `sudo nano /mnt/nvme/docker-compose.yml`
    1. Replace the domain name with your domain name
    1. Replace the email with your email address
1. `sudo docker-compose up swag`
1. Press Ctrl-C to stop the container
1. `sudo bash /mnt/nvme/ssl.sh`


## Running The Platform

1. Zoneminder is already running, so you can access it at http://<your duckdns domain>:81/zm
1. All other services are defined in the docker-compose file.  To start them, switch to the /mnt/nvme directory where you copied the file and run:
    1. `sudo docker-compose up -d`
1. Home Assistant is running at https://<your duckdns domain>:8123

## Helpful Commands

# Shutdown the docker containers

1. `sudo docker-compose down`

# Remove all Docker containers and images

1. `sudo docker rm -f $(sudo docker ps -aq) `
1. `sudo docker rmi -f $(sudo docker image ls -aq)`
