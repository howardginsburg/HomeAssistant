# Home Automation and Video Surveillance

## Introduction

This tutorial covers off on how to setup a home automation system that leverages a security panel, video surveillance, and z-wave enabled devices.  The system is built on top of the UP Squared AI Vision X Developer Kit, which includes a Myriad X chip for video inferencing.  The system is built on top of Home Assistant, and uses Frigate for video surveillance.  The system is designed to be a DIY project, and is not intended to be a commercial product.

### Hardware

1. [UP Squared AI Vision X Developer Kit](https://up-board.org/upkits/up-squared-ai-vision-kit/) for the main hardware.  It also includes a Myriad X chip for video inferencing.
1. [Western Digital 2TB drive](https://www.amazon.com/gp/product/B06W55K9N6/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&psc=1) for storage.
1. [Qolsys IQ Panel 2](https://qolsys.com/iq-panel-2/) for the home security system.  Note, I already had this with several sensors.  I would recommend an open source route if you're building from sratch.
1. [Anpviz 4MP PoE IP Dome Cameras](https://www.amazon.com/dp/B07TJT1Z1H?ref=ppx_yo2ov_dt_b_product_details&th=1)
1. PoE Switch for powering the cameras.
1. [Aeotec Z-Stick 7 Plus](https://www.amazon.com/dp/B094NW5B68)

### Software

1. [Home Assistant](https://www.home-assistant.io/) for Home Automation.
1. [Frigate](https://frigate.video/) for Video Surveillance.
1. [Qolsys Gateway](https://github.com/XaF/qolsysgw) is the software that will interface with the Qolsys panel.
1. [AppDaemon](https://github.com/AppDaemon/appdaemon) which is the execution platform that will run the Qolsys Gateway software.
1. [Z-Wave JS](https://zwave-js.github.io/zwave-js-ui/) to recognize and manage Z-Wave devices.
1. [Mosquitto MQTT Broker](https://mosquitto.org/) for communication between Home Assistant, AppDaemon, Frigate, and Z-Wave.
1. [Portainer](https://www.portainer.io/) for managing and monitoring Docker containers.
1. [Tailscale](https://tailscale.com/) for remote access.

## UP Squared Setup

The instructions provided by UP are a bit dated, so I created a simplified version.

- The Wiki for the Up community can be found at https://github.com/up-board/up-community/wiki
- Full instructions for hardware setup can be found at https://github.com/up-board/up-community/wiki/Ubuntu_20.04.  Note, there is currently no kernel for Ubuntu 22.04 and beyond.

Note, for purposes of this tutorial, the hostname for my Upboard device is upboard.local.

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


### Setup External Drive

1. Plug in the external drive.
1. Find the drive
    - `sudo fdisk -l`
1. Create a directory to use as the mount.
    - `sudo mkdir /media/usb`
1. Mount the drive
    - `sudo mount /dev/sda1 /media/usb`
1. Retrieve the UUID of the drive
    - `sudo blkid`
1. Add the drive to /etc/fstab
    - `sudo nano /etc/fstab`
        - Add the following line to the end of the file, replacing `<YOURUID>`:
            - `UUID=<YOURUID> /media/usb auto defaults,nofail,x-systemd.automount 0 2`
1. Reboot
    - `sudo reboot`

## Anpviz Camera Setup

This next section will load the latest firmware onto the camera and configure it to run optimally with Frigate.

1. Download the latest firmware for the camera at from [Anpviz](https://anpvizsupport.com/download/u-series_c0030).  Make sure to select the firmware for camera IPC-D240W-S.
1. Plug in the camera to the PoE switch.
1. Find the camera IP address using your router's admin page.
1. Update your router to give the camera a static IP address.
1. Open the camera in a web browser at http://cameraipaddress and login with the default credentials. (admin:123456)
1. Select System -> Upgrade and select the firmware file you downloaded.
1. Select Camera -> Vieo and specify the following settings:
    - Stream Type: Main Stream
        - Status: Enable
        - Video Compression: H.264
        - Resolution: 2560x1440
        - Frame Rate: 15
        - Bit Rate Type: VBR
        - Quality: Good
        - Bit Rate: 3500
        - Frame Interval: 30
        - Customize QP: Disable
    - Stream Type: Sub Stream
        - Status: Enable
        - Video Compression: H.264
        - Resolution: 640x360
        - Frame Rate: 5
        - Bit Rate Type: VBR
        - Quality: Good
        - Bit Rate: 500
        - Frame Interval: 5
        - Customize QP: Disable

## Software Setup

### Qolsys Panel Preparation

1. Setup the Qolsys panel and sensors per the manufacturers [instructions](https://qolsys.com/wp-content/uploads/2021/04/IQ-Panel-Installation-Manual-2.6.0-FINAL-041921.pdf).
1. Follow the instructions for enabling wifi and generating a token on the [Qolsys plugin page](https://github.com/XaF/qolsysgw/blob/main/README.md#configuring-your-qolsys-iq-panel).

### Home Assistant

1. Create a file /opt/homeautomation/docker-compose.yaml file with the following contents:
```yaml
version: '3.9'
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - /opt/homeautomation/homeassistant:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    restart: unless-stopped
    privileged: true
    network_mode: host
```
2. Start the container with `docker compose up -d`.
3. Verify that Home Assistant is running by going to http://upboard.local:8123.
4. Complete the initial setup of Home Assistant.
5. Click on your User profile in the bottom left corner.
6. Generate a Long Lived Access Token and note it down.  We'll need this later to connect AppDaemon to Home Assistant.

### Home Assistant Community Store (HACS)

HACS provides us wth the Frigate integration for Home Assistant.
1. Run the following command to access the Home Assistant container:
  - `docker exec -it homeassistant bash`
2. Run the following commands to install HACS:
  - `wget -O - https://get.hacs.xyz | bash -`
3. Shut down the container with `docker-compose down`.
4. Start the container with `docker compose up -d`.
5. Go to Settings -> Integrations -> Add Integration.
6. Search for HACS and click on Configure.
7. Select all the checkboxes.
8. Click on Submit.
9. Follow the GitHub prompts to complete the setup.
10. Shut down the container with `docker-compose down`.

### MQTT

- AppDaemon uses MQTT to communicate with the Qolsys panel and Home Assistant.
- Frigate uses MQTT to communicate with Home Assistant.

1. Edit the docker-compose.yaml file and add the following to the services section:
```yaml
  mqtt:
    container_name: mqtt
    image: eclipse-mosquitto:latest
    volumes:
      - /opt/homeautomation/mosquitto/config:/mosquitto/config
      - /opt/homeautomation/mosquitto/data:/mosquitto/data
      - /opt/homeautomation/mosquitto/log:/mosquitto/log
    restart: unless-stopped
    network_mode: host
```
2. Create a file /opt/homeautomation/mosquitto/config/mosquitto.conf with the following contents:
```conf
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
listener 1883 0.0.0.0

## Authentication ##
allow_anonymous true
```
3. Start the container with `docker compose up -d`.
4. Log into Home Assistant
5. Open Settings -> Devices and Services -> Integrations -> Add Integration.
6. Search for MQTT and click on Configure.
7. Set the following values:
    - Broker: localhost
    - Port: 1883
8. Click on Submit.
9. Shut down the containers with `docker-compose down`.

### AppDaemon and Qolsys Gateway

AppDaemon allows for custom python jobs to run and interface with Home Assistant.  The Qolsys Gateway is an AppDaemon plugin that allows for the Qolsys panel to be integrated into Home Assistant.  It is possible to install the Qolsys Gateway from HACS, however at the time of this writing, it installs incorrectly so we will install it manually.

1. Edit the docker-compose.yaml file and add the following to the services section:
```yaml
  appdaemon:
    container_name: appdaemon
    image: acockburn/appdaemon:latest
    volumes:
      - /opt/homeautomation/appdaemon:/conf
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    network_mode: host
```
2. Create a file /opt/homeautomation/appdaemon/appdaemon.yaml with the following contents:
```yaml
appdaemon:
  latitude: 41.6204422
  longitude: -80.2939694
  elevation: 0
  time_zone: America/New_York
  plugins:
    HASS:
      type: hass
      ha_url: http://localhost:8123
      token: <Your Home Assistant Long Lived Access Token>
    MQTT:
      type: mqtt
      namespace: mqtt # We will need that same value in the apps.yaml configuration
      client_host: localhost # The IP address or hostname of the MQTT broker
      client_port: 1883 # The port of the MQTT broker, generally 1883
http:
  url: http://0.0.0.0:5050
admin:
api:
hadashboard:

```
3. Replace the latitude, longitude, and elevation with your values.
4. Replace the ha_url and token with the values from Home Assistant.
5. Create a file /opt/homeautomation/appdaemon/apps.yaml with the following contents:
```yaml
hello_world:
  module: hello
  class: HelloWorld

qolsys_panel:
  module: gateway
  class: QolsysGateway
  panel_host: <qolsys_panel_host_or_ip>
  panel_token: <qolsys_secure_token>
```
6. Replace the panel_host and panel_token with the values from the Qolsys panel.
7. Copy the files from [Qolsys Gateway](https://github.com/XaF/qolsysgw/tree/main/apps/qolsysgw) to /opt/homeautomation/appdaemon/apps/qolsysgw.
    - `mkdir /opt/homeautomation/appdaemon/apps/temp`
    - `cd /opt/homeautomation/appdaemon/apps/temp`
    - `wget https://github.com/XaF/qolsysgw/archive/refs/heads/main.zip`
    - `unzip main.zip`
    - `cp -r qolsysgw-main/apps/qolsysgw /opt/homeautomation/appdaemon/apps`
    - `rm -rf /opt/homeautomation/appdaemon/apps/temp`
8. Start the containers with `docker compose up -d`.
9. Verify that the sensors for the Qolsys gateway appear in Home Assistant.
10. Shut down the containers with `docker-compose down`.

### Frigate

1. Edit the docker-compose.yaml file and add the following to the services section:
```yaml
  frigate:
    container_name: frigate
    privileged: true # this may not be necessary for all setups
    restart: unless-stopped
    image: ghcr.io/blakeblackshear/frigate:stable
    shm_size: "64mb" # update for your cameras based on calculation above
    device_cgroup_rules:
      - "c 189:* rmw" # enables access to the Myriad X VPU
    volumes:
      - /dev/bus/usb:/dev/bus/usb # enables access to the Myriad X VPU
      - /etc/localtime:/etc/localtime:ro
      - /opt/homeautomation/frigate/config:/config
      - /opt/homeautomation/frigate/storage:/media/frigate
      - type: tmpfs # Optional: 1GB of memory, reduces SSD/SD Card wear
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    environment:
      FRIGATE_RTSP_PASSWORD: "password"
    network_mode: host
```
2. Create a file /opt/homeautomation/frigate/config/config.yml with the following contents.  Note, you should create an entry for each camera:
```yaml
# Camera configuration(s)
cameras:
  Front:
    ffmpeg:
      inputs:
        - path: rtsp://admin:123456@<CAMERA IP ADDRESS>:554/stream0
          roles:
            - record
        - path: rtsp://admin:123456@<CAMERA IP ADDRESS>:554/stream1
          roles:
            - detect
        output_args:
        record: preset-record-generic-audio-aac
    record:
      enabled: True
    snapshots:
      enabled: True
    detect:
      enabled: True


# Configuration for recording to save all motion for 7 days, but any events for 30.
record:
  enabled: True
  retain:
    days: 7
    mode: motion
  events:
    retain:
      default: 30
      mode: active_objects

# Objects we want to track during detection.
objects:
  track:
    - person
    - dog
    - cat

# URL for the MQTT server to communicate with Home Assistant.
mqtt:
  enabled: True
  host: localhost
  port: 1883

# Hardware acceleration for the UP Squared Vision AI Dev Kit which is running an Intel processor.
ffmpeg:
  hwaccel_args: preset-vaapi

# Configuration to use the OpenVino model with the Myriad VPU for inferencing.
detectors:
  ov:
    type: openvino
    device: MYRIAD
    model:
      path: /openvino-model/ssdlite_mobilenet_v2.xml

# Model configuration for the OpenVino model.
model:
  width: 300
  height: 300
  input_tensor: nhwc
  input_pixel_format: bgr
  labelmap_path: /openvino-model/coco_91cl_bkgr.txt

# General logging configuration.
logger:
  # Optional: default log level (default: shown below)
  default: info
```
3. Replace the name of your camera and rtsp url.
4. Start the container with `docker compose up -d`.
5. Open the Frigate UI at http://upboard.local:5000 and verify that your camera is working.
6. Follow the [instructions](https://docs.frigate.video/integrations/home-assistant) to integrate Frigate with Home Assistant.
  1. Home Assistant > HACS > Integrations > "Explore & Add Integrations" > Frigate
  1. Shut down the containers with `docker-compose down`.
  1. Start the containers with `docker compose up -d`.
  1. Home Assistant > HACS > Search > Frigate 
  1. Shut down the containers with `docker-compose down`.
  1. Start the containers with `docker compose up -d`.
  1. Home Assistant > Settings > Devices & Services > Add Integration > Frigate
  1. Enter http://localhost:5000 as the Frigate URL.
  1. Install the Frigate Card from HACS.
  1. Shut down the containers with `docker-compose down`.
  1. Start the containers with `docker compose up -d`.
  1. Home Assistant > Overview > Add Card > Frigate
7. Shut down the containers with `docker-compose down`.

### Z-Wave

1. Get the Z-Wave stick reference by running `ls /dev/serial/by-id/`.
1. Edit the docker-compose.yaml file and add the following to the services section.  Make sure to replace the stick reference with your own.
```yaml
zwave-js-ui:
    container_name: zwave-js-ui
    image: zwavejs/zwave-js-ui:latest
    restart: always
    tty: true
    stop_signal: SIGINT
    environment:
        - SESSION_SECRET=mysupersecretkey
        - ZWAVEJS_EXTERNAL_CONFIG=/usr/src/app/store/.config-db
        - TZ=America/New_York
    networks:
        - zwave
    devices:
        - '/dev/serial/by-id/insert_stick_reference_here:/dev/zwave'
    volumes:
        - /opt/homeautomation/zwave:/usr/src/app/store
    ports:
        - '8091:8091' # port for web interface
        - '3000:3000' # port for Z-Wave JS websocket server
```
1. Start the containers with `docker compose up -d`.
1. Open the Z-Wave UI at http://upboard.local:8091.
1. Select Settings -> Home Assistant and enable WS-Server.  Be sure to save!
1. Go to the Home Assistant UI at http://upboard.local:8123.
1. Select Settings -> Devices and Services -> Integrations -> Add Integration.
1. Search for Z-Wave and click on Submit.
1. Add any z-wave devices to your Home Assistant system by selecting Z-Wave when adding a new device.
1. Shut down the containers with `docker-compose down`.

### Portainer

Portainer is a web interface for managing Docker containers.  It is useful for monitoring the status of your containers and logs.  This is not
fool proof as Home Assistant and Portainer must both be up and running.  But, it's helpful in monitoring the status of all the other containers.

1. Edit the docker-compose.yaml file and add the following to the services section:
```yaml
  portainer:
    container_name: portainer
    image: portainer/portainer-ce
    restart: always
    ports:
      - 9000:9000
    #network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/homeautomation/portainer:/data
    command: --base-url="/portainer/"
```
1. Start the containers with `docker compose up -d`.
1. Open the Portainer UI at http://upboard.local:9000.
1. Create an admin user and password.
1. Select Local and Connect.
1. Under your profile, create an access token.
1. Home Assistant > HACS > Search > Portainer.
1. Home Assistant > Settings > Devices & Services > Add Integration > Portainer
  1. Use `upboard.local:9000` as the URL.
1. You can now create automations in Home Assistant to monitor your containers.

## Enable Remote Access via VPN and Proxy
1. Install [Tailscale](https://tailscale.com/kb/1039/install-ubuntu-2004).
2. From the Tailscale admin page,
  1. Disable Key Expiry.
3. From the Tailscale admin page -> Access Control
  1. Enable Funnel.
4. From your terminal, run `tailscale funnel --bg=true 8123`
5. Edit /opt/homeautomation/homeassistant/configuration.yaml and add the following to the end of the file:
```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```
6. Start the container with `docker compose up -d`.
7. Verify you can access Home Assistant at http://tailscale_full_domain_url.