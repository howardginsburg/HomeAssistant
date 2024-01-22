# Home Automation and Video Surveillance with an UP Squared Vision AI Developer Kit

The goal of this project is to integrate security sensors that are monitored by a Qolsys IQ Panel 2 and standalone RTSP cameras integrated into Home Assistant.

## Software

Docker and Docker Compose will be what we use to run the software.
- Home Assistant
- Mosquitto MQTT Broker
- AppDaemon
- Qolsys Gateway for AppDaemon
- Frigate

## Hardware

- [UP Squared Vision AI Vision X Developer Kit](https://up-board.org/upkits/up-squared-ai-vision-kit/) - runs an Intel Atom X7 processor and a Intel Movidius Myriad X VPU for scoring machine learning models at the edge.  Frigate is able to leverage the Myriad VPU as it supports the Openvino framework.
- [Qolsys IQ Panel 2](https://qolsys.com/iq-panel-2/) - this is a security system that supports Z-Wave and Zigbee.  It also has a built-in camera and microphone.
- RTSP cameras

## Hardware Setup

### UP Squared Vision AI Developer Kit

1. Follow the [instructions](/UpSquared%20Vision%20AI/UpSquared%20AI.md) to setup the UP Squared Vision AI Developer Kit.

### Prepare the Qolsys Panel

1. Setup the Qolsys panel and sensors per the manufacturers [instructions](https://qolsys.com/wp-content/uploads/2021/04/IQ-Panel-Installation-Manual-2.6.0-FINAL-041921.pdf).
1. Follow the instructions for enabling wifi and generating a token on the [Qolsys plugin page](https://github.com/XaF/qolsysgw/blob/main/README.md#configuring-your-qolsys-iq-panel).


## Software Setup

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
2. Start the container with `docker-compose up -d`.
3. Verify that Home Assistant is running by going to http://<servername>:8123.
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
4. Start the container with `docker-compose up -d`.
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
3. Start the container with `docker-compose up -d`.
4. Log into Home Assistant
5. Open Settings -> Devices and Services -> Integrations -> Add Integration.
6. Search for MQTT and click on Configure.
7. Set the following values:
    - Broker: localhost
    - Port: 1883
8. Click on Submit.
9. Shut down the containers with `docker-compose down`.

### AppDaemon and Qolsys Gateway

AppDaemon allows for custom python jobs to run and interface with Home Assistant.  The Qolsys Gateway is an AppDaemon plugin that allows for the Qolsys panel to be integrated into Home Assistant.

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
8. Start the containers with `docker-compose up -d`.
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
    #devices:
      #- /dev/bus/usb:/dev/bus/usb # passes the USB Coral, needs to be modified for other versions
      #- /dev/apex_0:/dev/apex_0 # passes a PCIe Coral, follow driver instructions here https://coral.ai/docs/m2/get-started/#2a-on-linux
      #- /dev/dri/renderD128 # for intel hwaccel, needs to be updated for your hardware
    device_cgroup_rules:
      - "c 189:* rmw"
    volumes:
      - /dev/bus/usb:/dev/bus/usb
      - /etc/localtime:/etc/localtime:ro
      - /opt/homeautomation/frigate/config/config.yml:/config/config.yml
      - /opt/homeautomation/frigate/storage:/media/frigate
      - type: tmpfs # Optional: 1GB of memory, reduces SSD/SD Card wear
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    # ports:
    #   - "5000:5000"
    #   - "8554:8554" # RTSP feeds
    #   - "8555:8555/tcp" # WebRTC over tcp
    #   - "8555:8555/udp" # WebRTC over udp
    environment:
      FRIGATE_RTSP_PASSWORD: "password"
    network_mode: host
```
2. Create a file /opt/homeautomation/frigate/config/config.yml with the following contents:
```yaml
# Camera configuration(s)
cameras:
  Vision_AI_Dev_Kit:
    ffmpeg:
      inputs:
        - path: rtsp://192.168.175.2:8900/live
          roles:
            - detect
            - record
    record:
      enabled: True
    snapshots:
      enabled: True
    detect:
      enabled: True
      width: 1920 #1280
      height: 1080 #720


# Configuration for recording only active objects.
record:
  enabled: True
  retain:
    days: 0
    mode: active_objects
  events:
    retain:
      default: 10
      mode: active_objects

# Objects we want to track during detection.
objects:
  track:
    - person

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
4. Start the container with `docker-compose up -d`.
5. Open the Frigate UI at http://<servername>:5000 and verify that your camera is working.
6. Follow the [instructions](https://docs.frigate.video/integrations/home-assistant) to integrate Frigate with Home Assistant.
  1. Home Assistant > HACS > Integrations > "Explore & Add Integrations" > Frigate
  1. Shut down the containers with `docker-compose down`.
  1. Start the containers with `docker-compose up -d`.
  1. Home Assistant > HACS > Search > Frigate 
  1. Shut down the containers with `docker-compose down`.
  1. Start the containers with `docker-compose up -d`.
  1. Home Assistant > Settings > Devices & Services > Add Integration > Frigate
  1. Enter http://localhost:5000 as the Frigate URL.
  1. Install the Frigate Card from HACS.
  1. Shut down the containers with `docker-compose down`.
  1. Start the containers with `docker-compose up -d`.
  1. Home Assistant > Overview > Add Card > Frigate

## Enable Remote Access via VPN and Proxy
1. Install [Tailscale](https://tailscale.com/kb/1039/install-ubuntu-2004).
2. From the Tailscale admin page,
  1. Disable Key Expiry.
3. From the Tailscale admin page -> Access Control
  1. Enable Funnel.
4. From your terminal, run `tailscale funnel 8123`
5. Edit /opt/homeautomation/homeassistant/configuration.yaml and add the following to the end of the file:
```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```
6. Start the container with `docker-compose up -d`.

## Portainer
1. Edit the docker-compose.yaml file and add the following to the services section:
```yaml
  portainer:
    container_name: portainer
    image: portainer/portainer-ce:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/homeautomation/portainer:/data
    restart: unless-stopped
    network_mode: host
```
2. Edit the /opt/homeautomation/homeassistant/configuration.yaml file and add the following to the end of the file:
```yaml
panel_iframe:
  portainer:
    title: "Portainer"
    url: "http://<your server name>:9000/#/containers"
    icon: mdi:docker
    require_admin: true
```
3. Make sure to change the server name.
4. Start the container with `docker-compose up -d`.
5. Access Portainer at http://<your server name>:9000 and go through the initial setup.
6. Log into Home Assistant and verify that the Portainer link is available.
7. Shut down the containers with `docker-compose down`.