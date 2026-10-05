# Home Automation and Video Surveillance

## Introduction

This tutorial covers off on how to setup a home automation system that leverages a security panel, video surveillance, and z-wave enabled devices.  The system is built on top of the UP Squared AI Vision X Developer Kit, which includes a Myriad X chip for video inferencing.  The system is built on top of Home Assistant, and uses Frigate for video surveillance.  The system is designed to be a DIY project, and is not intended to be a commercial product.

### MYRIAD Update 7/9/2025

Intel [discontinued](https://www.intel.com/content/www/us/en/support/articles/000090446/boards-and-kits/neural-compute-sticks.html) support for the Neural Compute Stick 2 (NCS2) which uses Myriad X chip.  As a result, Frigate removed [support](https://github.com/blakeblackshear/frigate/discussions/12855) for Myriad devices all together.  The UP Squared AI Vision X Developer Kit does have an Intel GPU, so we can use that for video inferencing.

### HDD to SSD

I originally used a Western Digital 2TB HDD for storage.  Eventually, the drive failed and I replaced it with an SSD for speed of copying files and reliability.

### Deployment update: September 29, 2026

The deployment now runs Frigate **0.18.0**, upgraded from 0.17.2, with go2rtc providing main-stream live video for all four cameras. Application-owned log files remain independent of Docker's console logs.

| Component | Verified deployment |
|---|---|
| Frigate | `ghcr.io/blakeblackshear/frigate:0.18.0` |
| Home Assistant | `homeassistant/home-assistant:2026.9` |
| Mosquitto | `eclipse-mosquitto:2.1.2-alpine` |
| AppDaemon | `acockburn/appdaemon:4.4.2` |
| Z-Wave JS UI | `zwavejs/zwave-js-ui:11.23` |
| Portainer | `portainer/portainer-ce:2.45.0` |
| Host | Intel Atom E3950, approximately 8 GB RAM, Ubuntu 20.04.6, UP-specific 5.4 kernel |
| Storage | Internal eMMC for the OS/Docker; external 2 TB SSD for recordings |

Only Frigate was upgraded during this maintenance; the other image versions were already deployed. These are dated, verified versions, not floating recommendations to always install `latest`. The host OS/kernel was not upgraded. The Ubuntu instructions below describe the existing installation, not a recommendation to start a new deployment on an unsupported OS.

Completed changes:

- Pinned Frigate to 0.18.0 and increased shared memory from 86 MB to 256 MB.
- Added HD live streams while retaining direct-to-camera recording inputs and low-resolution detection.
- Preserved camera firmware, G.711 audio, recording retention, and GPU acceleration.
- Added bounded Docker console logs, host-managed application file rotation, and explicit system journal limits.
- Added bounded Prometheus host/container metrics and provisioned Grafana dashboards for troubleshooting.
- Backed up configuration, logs, and the pre-upgrade Frigate database; retained the 0.17.2 image for rollback.
- Removed only approved, unused old Docker images to provide upgrade space. No volumes or camera footage were manually deleted.

Examples use placeholders instead of deployed credentials, camera addresses, or device identifiers. Keep real credentials, databases, backups, and generated logs out of Git.

## Hardware

1. [UP Squared AI Vision X Developer Kit](https://up-board.org/upkits/up-squared-ai-vision-kit/) for the main hardware.  It also includes a Myriad X chip for video inferencing. Note, Myriad X support discontinued in Frigate.  We will use the Intel GPU instead.
1. [SanDisk 2TB SSD drive](https://www.amazon.com/dp/B08HN37XC1?ref_=ppx_hzod_title_dt_b_fed_asin_title_0_0&th=1) for storage.
1. [Qolsys IQ Panel 2](https://qolsys.com/iq-panel-2/) for the home security system.  Note, I already had this with several sensors.  I would recommend an open source route if you're building from sratch.
1. [Anpviz 4MP PoE IP Dome Cameras](https://www.amazon.com/dp/B07TJT1Z1H?ref=ppx_yo2ov_dt_b_product_details&th=1)
1. PoE Switch for powering the cameras.
1. [Aeotec Z-Stick 7 Plus](https://www.amazon.com/dp/B094NW5B68)

## Software

1. [Home Assistant](https://www.home-assistant.io/) for Home Automation.
1. [Frigate](https://frigate.video/) for Video Surveillance.
1. [Qolsys Gateway](https://github.com/XaF/qolsysgw) is the software that will interface with the Qolsys panel.
1. [AppDaemon](https://github.com/AppDaemon/appdaemon) which is the execution platform that will run the Qolsys Gateway software.
1. [Z-Wave JS](https://zwave-js.github.io/zwave-js-ui/) to recognize and manage Z-Wave devices.
1. [Mosquitto MQTT Broker](https://mosquitto.org/) for communication between Home Assistant, AppDaemon, Frigate, and Z-Wave.
1. [Portainer](https://www.portainer.io/) for managing and monitoring Docker containers.
1. [Tailscale](https://tailscale.com/) for remote access.
1. [Prometheus](https://prometheus.io/) with [Node Exporter](https://github.com/prometheus/node_exporter) and [cAdvisor](https://github.com/google/cadvisor) for bounded host and container metrics.
1. [Grafana](https://grafana.com/) for provisioned host, hardware, and container dashboards.

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

### Host and Container Monitoring

The deployed monitoring stack uses pinned images and stores its configuration in this repository:

| Component | Image | Purpose |
|---|---|---|
| Prometheus | `prom/prometheus:v3.6.0` | Time-series collection and retention |
| Grafana | `grafana/grafana:12.2.0` | Dashboards on port 3001 |
| Node Exporter | `prom/node-exporter:v1.9.1` | Host CPU, memory, storage, network, pressure, temperature, and power-domain metrics |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.52.1` | Per-container CPU, memory, storage, and network metrics |

Prometheus scrapes every 30 seconds. Data is retained for at most 14 days and has a hard 2 GiB limit; whichever limit is reached first wins. Prometheus uses a named volume rather than the external Frigate recording disk. Grafana data uses a separate named volume. Docker console output remains bounded by the shared `json-file` rotation policy.

The repository includes:

- `docker-compose.monitoring.yml`: standalone or additive monitoring services.
- `monitoring/prometheus/prometheus.yml`: scrape jobs for Prometheus, Node Exporter, and cAdvisor.
- `monitoring/grafana/provisioning/`: automatic Prometheus datasource and dashboard provisioning.
- `monitoring/grafana/dashboards/upboard-health.json`: host utilization, filesystem, network, disk, and container overview.
- `monitoring/grafana/dashboards/upboard-hardware.json`: per-core CPU usage/frequency, CPU temperatures, throttling, RAPL power domains, pressure stalls, OOM events, disk latency, filesystem state, and network errors.

1. Copy the versioned monitoring configuration from this repository into the deployment directory:

    ```bash
    cd <PATH_TO_THIS_REPOSITORY>
    sudo mkdir -p /opt/homeautomation/monitoring
    sudo cp -a monitoring/. /opt/homeautomation/monitoring/
    ```

2. Edit `/opt/homeautomation/docker-compose.yml`. Add the following definitions beneath the existing `services:` key. Keep the existing `x-logging` anchor because these services reuse `*default-logging`:

    ```yaml
      prometheus:
        container_name: prometheus
        logging: *default-logging
        image: prom/prometheus:v3.6.0
        restart: unless-stopped
        command:
          - --config.file=/etc/prometheus/prometheus.yml
          - --storage.tsdb.path=/prometheus
          - --storage.tsdb.retention.time=14d
          - --storage.tsdb.retention.size=2GB
          - --web.enable-lifecycle
        ports:
          - "127.0.0.1:9090:9090"
        volumes:
          - /opt/homeautomation/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
          - prometheus-data:/prometheus
        networks:
          - monitoring
        depends_on:
          - node-exporter
          - cadvisor

      grafana:
        container_name: grafana
        logging: *default-logging
        image: grafana/grafana:12.2.0
        restart: unless-stopped
        environment:
          GF_USERS_ALLOW_SIGN_UP: "false"
        ports:
          - "3001:3000"
        volumes:
          - grafana-data:/var/lib/grafana
          - /opt/homeautomation/monitoring/grafana/provisioning/datasources/prometheus.yml:/etc/grafana/provisioning/datasources/prometheus.yml:ro
          - /opt/homeautomation/monitoring/grafana/provisioning/dashboards/dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml:ro
          - /opt/homeautomation/monitoring/grafana/dashboards:/var/lib/grafana/dashboards:ro
        networks:
          - monitoring
        depends_on:
          - prometheus

      node-exporter:
        container_name: node-exporter
        logging: *default-logging
        image: prom/node-exporter:v1.9.1
        restart: unless-stopped
        command:
          - --path.procfs=/host/proc
          - --path.sysfs=/host/sys
          - --path.rootfs=/rootfs
          - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)
        pid: host
        volumes:
          - /proc:/host/proc:ro
          - /sys:/host/sys:ro
          - /:/rootfs:ro,rslave
          - /run/udev/data:/run/udev/data:ro
        networks:
          - monitoring

      cadvisor:
        container_name: cadvisor
        logging: *default-logging
        image: gcr.io/cadvisor/cadvisor:v0.52.1
        restart: unless-stopped
        privileged: true
        devices:
          - /dev/kmsg:/dev/kmsg
        volumes:
          - /:/rootfs:ro
          - /var/run:/var/run:ro
          - /sys:/sys:ro
          - /var/lib/docker:/var/lib/docker:ro
          - /dev/disk:/dev/disk:ro
        networks:
          - monitoring
    ```

3. Add the following top-level definitions at the end of `docker-compose.yml`. They must align with `services:` rather than being nested beneath it:

    ```yaml
    volumes:
      prometheus-data:
      grafana-data:

    networks:
      monitoring:
    ```

4. Validate the combined Compose file and start only the monitoring services:

    ```bash
    cd /opt/homeautomation
    docker compose config --quiet
    docker compose up -d prometheus grafana node-exporter cadvisor
    ```

As an alternative to editing the main file, copy `docker-compose.monitoring.yml` beside it and use both files:

```bash
cd /opt/homeautomation
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d prometheus grafana node-exporter cadvisor
```

Open Grafana at `http://upboard.local:3001`. The initial credentials are `admin` / `admin`; change the password immediately. User sign-up is disabled. Prometheus binds only to `127.0.0.1:9090`, while Grafana is exposed on the LAN.

Verify the deployment:

```bash
# All three jobs should return a value of 1.
curl -fsSG --data-urlencode 'query=up' http://127.0.0.1:9090/api/v1/query

# Confirm both retention limits.
curl -fsS http://127.0.0.1:9090/api/v1/status/flags

# Confirm Grafana and cAdvisor health.
curl -fsS http://127.0.0.1:3001/api/health
docker inspect --format '{{.State.Health.Status}}' cadvisor

# Review persistent volume usage and remaining host storage.
docker system df -v
df -h /
```

This stack helps distinguish sustained CPU, memory, temperature, disk, network, and container problems before an incident. Locally stored metrics cannot prove a sudden loss of input power: collection stops at the reset, and the final samples may not be flushed. UPS/voltage telemetry or remote Prometheus storage is required for direct power evidence. Intel i915 GPU utilization is not currently exported on the deployed UP-specific 5.4 kernel; RAPL uncore energy is only a power-domain proxy, not GPU utilization.


### Setup External Drive

1. Plug in the external drive.
1. Find the drive
    - `sudo lsblk`
1. Format the drive
    - `sudo mkfs.ext4 /dev/sda1` 
        - Note, replace `/dev/sda1` with the correct drive identifier.
1. Create a directory to use as the mount.
    - `sudo mkdir /media/external`
1. Mount the drive
    - `sudo mount /dev/sda1 /media/external`
1. Retrieve the UUID of the drive
    - `sudo blkid`
1. Add the drive to /etc/fstab
    - `sudo nano /etc/fstab`
        - Add the following line to the end of the file, replacing `<YOURUID>`:
            - `UUID=<YOURUID> /media/external auto defaults,nofail,x-systemd.automount 0 2`
1. Reboot
    - `sudo reboot`

## Anpviz Camera Setup

The four IPC-D240W-S cameras have the following inspected settings. Firmware and video settings were left unchanged during the Frigate upgrade.

**Do not choose firmware by the IPC-D240W-S product name alone.** Front, SideDoor, and Back use the MCF26 V3.3.0.6 firmware family; Side uses 40E-V3 V3.4.0.10. Firmware was reviewed using the [manufacturer's catalog](https://anpvizsupport.com/download/u-series_c0030), but no update was applied. Confirm the exact hardware family with the manufacturer before any future update.

1. Plug in the camera to the PoE switch.
1. Find the camera IP address using your router's admin page.
1. Use a DHCP reservation for a stable address. Reservations and credential changes remain separate configuration tasks.
1. Open the camera in a web browser at http://cameraipaddress and log in with its administrator credentials.
1. Under Camera -> Video, check the following tested baseline:
    - Stream Type: Main Stream
        - Status: Enable
        - Video Compression: H.264
        - Resolution: 2560x1440
        - Frame Rate: 15
        - Bit Rate Type: VBR
        - Quality: Best
        - Bit Rate: 5120 kbps
        - Frame Interval: 30
        - Customize QP: Disable
    - Stream Type: Sub Stream
        - Status: Enable
        - Video Compression: H.264
        - Resolution: 640x360
        - Frame Rate: 5
        - Bit Rate Type: VBR
        - Quality: Best
        - Bit Rate: 512 kbps
        - Frame Interval: 5
        - Customize QP: Disable

### Camera audio

Keep the camera encoder on **G.711 mu-law (PCMU), 8 kHz, 64 kbps**. Frigate converts this audio to AAC for recordings using `preset-record-generic-audio-aac`. go2rtc can also produce AAC on demand for live clients; this is software conversion, not camera-native AAC.

A temporary native-AAC test on Front using **Frigate 0.17.2 / FFmpeg 7** caused RTSP/AAC parsing problems and an approximately two-minute recording gap. G.711 was restored and verified. Native AAC has **not** been retested on 0.18.0 / FFmpeg 8 and is not required for HD live video.

Changing the main-stream GOP from 30 to 15 or reducing bitrate may be worth a controlled future test, but neither change was applied.

## Software Setup

### Qolsys Panel Preparation

1. Setup the Qolsys panel and sensors per the manufacturers [instructions](https://qolsys.com/wp-content/uploads/2021/04/IQ-Panel-Installation-Manual-2.6.0-FINAL-041921.pdf).
1. Follow the instructions for enabling wifi and generating a token on the [Qolsys plugin page](https://github.com/XaF/qolsysgw/blob/main/README.md#configuring-your-qolsys-iq-panel).

### Home Assistant

1. Create `/opt/homeautomation/docker-compose.yml` with the following contents. Run Compose commands from `/opt/homeautomation`. All later service examples belong under this same `services` mapping and reuse the logging anchor:
```yaml
version: '3.9'
x-logging: &default-logging
  # Console logging is separate from application-owned log files.
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  homeassistant:
    container_name: homeassistant
    logging: *default-logging
    image: homeassistant/home-assistant:2026.9
    volumes:
      - /opt/homeautomation/homeassistant:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    restart: unless-stopped
    privileged: true
    network_mode: host
```
2. Start the container with `docker compose up -d homeassistant`.
3. Verify that Home Assistant is running by going to http://upboard.local:8123.
4. Complete the initial setup of Home Assistant.
5. Click on your User profile in the bottom left corner.
6. Generate a Long Lived Access Token and note it down.  We'll need this later to connect AppDaemon to Home Assistant.

Keep Home Assistant's normal file logging enabled; do **not** set `HA_DISABLE_LOG_FILE=true`. Its files remain in `/opt/homeautomation/homeassistant` and are managed by the host rotation policy below. The existing Compose `version` key is accepted but produces an obsolete-key warning in Compose v2.

### Home Assistant Community Store (HACS)

HACS provides us wth the Frigate integration for Home Assistant.
1. Run the following command to access the Home Assistant container:
  - `docker exec -it homeassistant bash`
2. Run the following commands to install HACS:
  - `wget -O - https://get.hacs.xyz | bash -`
3. Restart only Home Assistant with `docker compose restart homeassistant`.
4. Wait for Home Assistant to become available.
5. Go to Settings -> Integrations -> Add Integration.
6. Search for HACS and click on Configure.
7. Select all the checkboxes.
8. Click on Submit.
9. Follow the GitHub prompts to complete the setup.
10. Leave the service running while configuring the remaining components.

### MQTT

- AppDaemon uses MQTT to communicate with the Qolsys panel and Home Assistant.
- Frigate uses MQTT to communicate with Home Assistant.

1. Edit `docker-compose.yml` and add the following to the services section:
```yaml
  mqtt:
    container_name: mqtt
    logging: *default-logging
    image: eclipse-mosquitto:2.1.2-alpine
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
3. Start the container with `docker compose up -d mqtt`.
4. Log into Home Assistant
5. Open Settings -> Devices and Services -> Integrations -> Add Integration.
6. Search for MQTT and click on Configure.
7. Set the following values:
    - Broker: localhost
    - Port: 1883
8. Click on Submit.
9. Leave MQTT running for the other services.

Keep `log_dest file /mosquitto/log/mosquitto.log`; do not redirect the primary broker log to Docker stdout. Host logrotate reopens this file using SIGHUP after rotation. Anonymous MQTT access remains part of the existing deployment, not a security recommendation; authentication and network restrictions are still outstanding.

### AppDaemon and Qolsys Gateway

AppDaemon allows for custom python jobs to run and interface with Home Assistant.  The Qolsys Gateway is an AppDaemon plugin that allows for the Qolsys panel to be integrated into Home Assistant.  It is possible to install the Qolsys Gateway from HACS, however at the time of this writing, it installs incorrectly so we will install it manually.

1. Edit `docker-compose.yml` and add the following to the services section:
```yaml
  appdaemon:
    container_name: appdaemon
    logging: *default-logging
    image: acockburn/appdaemon:4.4.2
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
8. Start AppDaemon with `docker compose up -d appdaemon`.
9. Verify that the sensors for the Qolsys gateway appear in Home Assistant.
10. Leave AppDaemon running. Its existing stdout/stderr logging is bounded by Docker's separate console policy; no new application file destination was introduced.

### Frigate

1. Edit `docker-compose.yml` and add the following to the services section:
```yaml
  frigate:
    container_name: frigate
    logging: *default-logging
    privileged: true # this may not be necessary for all setups
    restart: unless-stopped
    image: ghcr.io/blakeblackshear/frigate:0.18.0
    shm_size: "256mb"
    # Legacy USB passthrough was retained; detection uses the Intel GPU, not Myriad.
    device_cgroup_rules:
      - "c 189:* rmw" # enables access to the Myriad X VPU
    volumes:
      - /dev/bus/usb:/dev/bus/usb # enables access to the Myriad X VPU.  Shouldn't need this if you're using the Intel GPU.
      - /etc/localtime:/etc/localtime:ro
      - /opt/homeautomation/frigate/config:/config
      - /media/external/frigate/storage:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    network_mode: host
```
2. Create `/opt/homeautomation/frigate/config/config.yml`. This four-camera example uses the 0.18 configuration shape. Replace every camera address and credential placeholder locally; URL-encode credentials containing reserved URL characters. An environment variable named `FRIGATE_RTSP_PASSWORD` does not automatically replace a password written literally in an RTSP URL.
```yaml
version: 0.18-0

cameras:
  Front:
    ffmpeg:
      inputs:
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<FRONT_CAMERA_IP>:554/stream0"
          roles: [record]
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<FRONT_CAMERA_IP>:554/stream1"
          roles: [detect]
    live:
      streams:
        Main stream (4 MP): Front
  SideDoor:
    ffmpeg:
      inputs:
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<SIDEDOOR_CAMERA_IP>:554/stream0"
          roles: [record]
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<SIDEDOOR_CAMERA_IP>:554/stream1"
          roles: [detect]
    live:
      streams:
        Main stream (4 MP): SideDoor
  Back:
    ffmpeg:
      inputs:
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<BACK_CAMERA_IP>:554/stream0"
          roles: [record]
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<BACK_CAMERA_IP>:554/stream1"
          roles: [detect]
    live:
      streams:
        Main stream (4 MP): Back
  Side:
    ffmpeg:
      inputs:
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<SIDE_CAMERA_IP>:554/stream0"
          roles: [record]
        - path: "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<SIDE_CAMERA_IP>:554/stream1"
          roles: [detect]
    live:
      streams:
        Main stream (4 MP): Side

go2rtc:
  streams:
    Front:
      - "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<FRONT_CAMERA_IP>:554/stream0#backchannel=0"
      - "ffmpeg:Front#audio=aac"
    SideDoor:
      - "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<SIDEDOOR_CAMERA_IP>:554/stream0#backchannel=0"
      - "ffmpeg:SideDoor#audio=aac"
    Back:
      - "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<BACK_CAMERA_IP>:554/stream0#backchannel=0"
      - "ffmpeg:Back#audio=aac"
    Side:
      - "rtsp://<CAMERA_USERNAME>:<CAMERA_PASSWORD>@<SIDE_CAMERA_IP>:554/stream0#backchannel=0"
      - "ffmpeg:Side#audio=aac"
  webrtc:
    candidates:
      - "<FRIGATE_LAN_IP>:8555"
      # Optional: add a reachable Tailscale address when using that network.
      # - "<FRIGATE_VPN_IP>:8555"

# Existing retention was preserved, not resized for the available disk.
record:
  enabled: true
  continuous:
    days: 20
  motion:
    days: 20
  alerts:
    retain:
      days: 20
      mode: motion
  detections:
    retain:
      days: 20
      mode: motion

detect:
  enabled: true
  width: 640
  height: 360
  fps: 5

snapshots:
  enabled: true

objects:
  track:
    - person

# URL for the MQTT server to communicate with Home Assistant.
mqtt:
  enabled: true
  host: upboard.local
  port: 1883

# Hardware acceleration for the UP Squared Vision AI Dev Kit which is running an Intel processor.
ffmpeg:
  hwaccel_args: preset-vaapi
  output_args:
    record: preset-record-generic-audio-aac

# Inference remains on the Intel GPU.
detectors:
  ov:
    type: openvino
    device: GPU

# Model configuration for the OpenVino model.
model:
  path: /openvino-model/ssdlite_mobilenet_v2.xml
  width: 300
  height: 300
  input_tensor: nhwc
  input_pixel_format: bgr
  labelmap_path: /openvino-model/coco_91cl_bkgr.txt

# General logging configuration.
logger:
  # Optional: default log level (default: shown below)
  default: info

# Existing trusted-network settings; access hardening is still outstanding.
auth:
  enabled: false

# Disable TLS on the Frigate UI.
tls:
  enabled: false
```
3. Verify that each `live.streams` value exactly matches its go2rtc stream name: Front, SideDoor, Back, and Side.
4. Validate Compose with `docker compose config --quiet`, then start only Frigate with `docker compose up -d --no-deps frigate`.
5. Open http://upboard.local:5000 and verify live video, detection, new recordings, and audio for each camera. Refresh existing browser tabs after an upgrade.
6. Follow the [instructions](https://docs.frigate.video/integrations/home-assistant) to integrate Frigate with Home Assistant.
  1. Home Assistant > HACS > Integrations > "Explore & Add Integrations" > Frigate
  1. Restart only Home Assistant when HACS requests it: `docker compose restart homeassistant`.
  1. Home Assistant > HACS > Search > Frigate 
  1. Restart only Home Assistant when required.
  1. Home Assistant > Settings > Devices & Services > Add Integration > Frigate
  1. Enter http://localhost:5000 as the Frigate URL.
  1. Install the Frigate Card from HACS.
  1. Reload the frontend or restart Home Assistant when required.
  1. Home Assistant > Overview > Add Card > Frigate
7. Leave the services running; avoid `docker compose down` for routine single-service changes.

#### Live video, detection, and audio are separate

- **Recording:** direct camera main streams, H.264, 2560x1440 at 15 FPS. Recording was not rerouted through go2rtc.
- **Detection:** camera substreams, 640x360 at 5 FPS, with OpenVINO GPU inference and VAAPI decoding.
- **Live video:** go2rtc main streams, 2560x1440 at 15 FPS. Video is passed through, not transcoded. AAC audio conversion is available on demand.
- **Smart Streaming:** active panes use HD video; idle panes can show lower-resolution detection snapshots, and offscreen panes may not stream. Continuous Streaming is a browser/camera-group preference and was not enabled globally.

All four restreams and browser playback were verified. New recordings contained valid, non-silent AAC audio, and database integrity checks passed. The reported shared-memory minimum was 162 MB; the configured 256 MB provides headroom.

Frigate 0.18 includes FFmpeg 8 and go2rtc 1.9.14 in this image. Intel GPU utilization reporting may be inaccurate on the old 5.4 kernel even while GPU inference and decoding work. Do not interpret a displayed 0% utilization as proof that acceleration is disabled.

See the [0.18.0 release notes](https://github.com/blakeblackshear/frigate/releases/tag/v0.18.0), [restream documentation](https://docs.frigate.video/configuration/restream/), and [live-view documentation](https://docs.frigate.video/configuration/live/).

#### Recording retention

Let Frigate manage recording expiration and its database. **Do not enable the old `deleterecordings.sh` cron workaround** or manually delete recording directories behind Frigate's back. The legacy cron entry was already disabled and was left disabled.

The existing 20-day continuous/motion/alert/detection policy remains unchanged. The 2 TB recording drive was nearly full; observed usage was approximately 95 GB/day and retained history approximately 18.7 days. Those are measurements, not a guaranteed retention window.

A future change to roughly 14-16 days of continuous and motion retention would provide more headroom. Almost every recorded segment registered motion, so reducing continuous retention alone while leaving motion at 20 days would save little. Export important footage before shortening retention: older recordings will expire sooner. Longer alert/detection retention can be considered separately.

#### Safe upgrades and rollback

1. Read release notes and check space on both `/` and `/media/external`. Docker images and the database use the internal disk; recordings use the external SSD.
1. Retain/tag the currently running image before pulling a replacement. During this upgrade, the old image was retained as `ghcr.io/blakeblackshear/frigate:0.17.2`.
1. Make a timestamped backup under `/opt/homeautomation/backups`, accessible only to the administrator (directory mode 0700). Save the original Compose file and Frigate configuration before editing.
1. Use SQLite's backup API for a live database, or stop **only Frigate** before copying its complete configuration/database directory, including any WAL files. Do not simply copy a live database file.
1. Pin the intended image tag, validate Compose and the new Frigate schema, and recreate only Frigate with `docker compose up -d --no-deps frigate`. Pull the new image before the outage when possible.
1. Verify health, camera processing rates, fresh recordings, decoded audio, HD playback, and database integrity. The 0.17.2-to-0.18.0 upgrade caused recording gaps of approximately 72-80 seconds; downtime must be expected.

Frigate migrated the configuration marker from `0.17-0` to `0.18-0`. For rollback, stop Frigate and restore the matching pre-upgrade configuration/database and old image together. Preserve recording files; do not run an old image against a migrated database without checking compatibility.

Remove only explicitly identified unused images when reclaiming space. Keep running images and rollback images, and do not use broad volume-pruning commands. The images removed during this upgrade were Frigate 0.13.1 and the unused Home Assistant 2024.7, 2024.12, and 2025.1 images.

### Z-Wave

1. Get the Z-Wave stick reference by running `ls /dev/serial/by-id/`.
1. Edit `docker-compose.yml` and add the following under `services`. Replace the stick reference and session-secret placeholder locally.
```yaml
  zwave-js-ui:
    container_name: zwave-js-ui
    logging: *default-logging
    image: zwavejs/zwave-js-ui:11.23
    restart: unless-stopped
    tty: true
    stop_signal: SIGINT
    environment:
        - SESSION_SECRET=<YOUR_RANDOM_SESSION_SECRET>
        - ZWAVEJS_EXTERNAL_CONFIG=/usr/src/app/store/.config-db
        - TZ=America/New_York
    devices:
        - '/dev/serial/by-id/insert_stick_reference_here:/dev/zwave'
    volumes:
        - /opt/homeautomation/zwave:/usr/src/app/store
    network_mode: host
```
1. Start Z-Wave JS UI with `docker compose up -d zwave-js-ui`.
1. Open the Z-Wave UI at http://upboard.local:8091.
1. Select Settings -> Home Assistant and enable WS-Server.  Be sure to save!
1. Go to the Home Assistant UI at http://upboard.local:8123.
1. Select Settings -> Devices and Services -> Integrations -> Add Integration.
1. Search for Z-Wave and click on Submit.
1. Add any z-wave devices to your Home Assistant system by selecting Z-Wave when adding a new device.
1. Keep driver file logging enabled (`zwave.logToFile: true`). The deployed driver log level remains `debug`; this maintenance did not change verbosity. Native daily files remain under `/opt/homeautomation/zwave/logs`, supplemented by the host size-rotation policy below.

### Portainer

Portainer is a web interface for managing Docker containers.  It is useful for monitoring the status of your containers and logs.  This is not
fool proof as Home Assistant and Portainer must both be up and running.  But, it's helpful in monitoring the status of all the other containers.

1. Edit `docker-compose.yml` and add the following to the services section:
```yaml
  portainer:
    container_name: portainer
    logging: *default-logging
    image: portainer/portainer-ce:2.45.0
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/homeautomation/portainer:/data
    command: --base-url="/portainer/"
```
1. Start Portainer with `docker compose up -d portainer`.
1. Open the Portainer UI at http://upboard.local:9000.
1. Create an admin user and password.
1. Select Local and Connect.
1. Under your profile, create an access token.
1. Home Assistant > HACS > Search > Portainer.
1. Home Assistant > Settings > Devices & Services > Add Integration > Portainer
  1. Use `upboard.local:9000` as the URL.
1. You can now create automations in Home Assistant to monitor your containers.

## Logging and Rotation

Application-owned logs stay in their existing bind-mounted folders under `/opt/homeautomation`; Docker/Portainer is **not** their replacement log store. The temporary experiment with redirecting Home Assistant, Mosquitto, and Z-Wave logs to Docker was reversed. Home Assistant's file-disable override was removed, Mosquitto's file destination restored, and Z-Wave's `logToFile` restored to `true`.

| Logs | Owner and retention |
|---|---|
| Mosquitto file | Host logrotate: daily or above 10 MiB; 3 archives plus the active file; reopen with SIGHUP |
| Home Assistant file | Host logrotate: daily or above 10 MiB; 3 compressed archives plus the active file |
| Z-Wave driver files | Native daily files with existing seven-day retention; host rotation above 10 MiB, with 3 archives per dated filename |
| Home Assistant crash log | Host rotation above 1 MiB; 3 compressed archives plus the active file |
| All six containers' stdout/stderr | Docker `json-file`: 10 MiB per file, 3 files total per container, approximately 30 MiB per container |
| Persistent system journal | systemd-journald: 512 MiB target maximum and 14-day retention |

AppDaemon, Frigate, and Portainer retain their existing console logging. The Docker limits are a separate safeguard; they do not rotate files written inside bind mounts.

### Application file rules

Create `/etc/logrotate.d/homeautomation` on the **host**, owned by root and not writable by other users:

```conf
/opt/homeautomation/mosquitto/log/mosquitto.log {
    daily
    maxsize 10M
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    su root root
    create 0600
    olddir archive
    createolddir 0700 root root
    postrotate
        running=$(/usr/bin/docker inspect --format '{{.State.Running}}' mqtt) || exit 1
        if [ "$running" = true ]; then
            /usr/bin/docker exec mqtt kill -HUP 1
        fi
    endscript
}

# Keep host rotation separate from Home Assistant's restart-time .log.1 file.
/opt/homeautomation/homeassistant/home-assistant.log {
    daily
    maxsize 10M
    rotate 3
    copytruncate
    compress
    missingok
    notifempty
    su root root
    olddir log-archive
    createolddir 0700 root root
}

# Preserve the daily filenames managed by Z-Wave itself.
/opt/homeautomation/zwave/logs/zwavejs_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].log {
    size 10M
    rotate 3
    copytruncate
    compress
    missingok
    notifempty
    su root root
    olddir archive
    createolddir 0700 root root
    lastaction
        /usr/bin/find /opt/homeautomation/zwave/logs/archive -maxdepth 1 -type f -name 'zwavejs_*.log.*.gz' -mtime +7 -delete
    endscript
}

# The crash handler keeps its file open and cannot reopen on signal.
/opt/homeautomation/homeassistant/home-assistant.log.fault {
    size 1M
    rotate 3
    copytruncate
    compress
    missingok
    notifempty
    su root root
}
```

Important behavior:

- `create 0600` preserves the existing Mosquitto log's ownership when creating its replacement. SIGHUP reopens the file without restarting the broker. `delaycompress` leaves the newest archive uncompressed until a later rotation.
- Home Assistant and Z-Wave use `copytruncate` to preserve their open file descriptors. There is a small potential log-loss window between copying and truncating; this is not a lossless logging transport.
- Home Assistant's separate restart-time `.log.1` is not replaced by the host archive directory.
- Z-Wave's rotated archives are separate from its native daily-file index. The cleanup hook prunes archives matching `-mtime +7` during subsequent size rotations; it is not a continuously enforced seven-day deadline. Native seven-day cleanup still manages the original daily files.
- File sizes are **rotation thresholds, not filesystem quotas**. Logs can exceed them between checks, and old oversized archives can remain until normal retention removes them.

### Host scheduler and traditional system logs

Keep the existing policies in `/etc/logrotate.conf`, but add `maxsize 10M` **before its existing** `include /etc/logrotate.d` line. Do not add a second include. Existing per-package archive counts and schedules remain unchanged; the inherited maximum-size check lets large traditional system logs rotate sooner.

Create `/etc/systemd/system/logrotate.timer.d/override.conf`:

```ini
[Timer]
OnCalendar=
OnCalendar=*-*-* *:0/5:00
AccuracySec=30s
```

This changes the host's existing `logrotate.timer` from daily to every five minutes, with up to 30 seconds of scheduling accuracy. The timer starts `logrotate.service`, which runs `/usr/sbin/logrotate /etc/logrotate.conf`. No additional container or continuously running custom script is needed.

After creating the files, validate and activate:

```bash
sudo logrotate --debug /etc/logrotate.conf
sudo systemd-analyze verify /lib/systemd/system/logrotate.timer
sudo systemctl daemon-reload
sudo systemctl enable logrotate.timer
sudo systemctl restart logrotate.timer
sudo systemctl start logrotate.service
sudo systemctl list-timers logrotate.timer --all --no-pager
sudo systemctl show logrotate.service --property=Result --property=ExecMainStatus
```

`--debug` validates without rotating files. Starting the service applies normal rules; it does not force every log to rotate.

### System journal

Create `/etc/systemd/journald.conf.d/60-log-limits.conf`:

```ini
[Journal]
SystemMaxUse=512M
SystemMaxFileSize=32M
SystemKeepFree=2G
RuntimeMaxUse=64M
RuntimeMaxFileSize=16M
MaxRetentionSec=14day
```

Apply and inspect:

```bash
sudo systemctl restart systemd-journald.service
journalctl --disk-usage
```

These limits can remove older journal history. During the maintenance, approximately 4 GiB of journal usage was reduced to approximately 152 MiB; that was a point-in-time result, not the configured target. Camera recordings are unrelated to the journal.

If immediate archive reclamation is intended, the following additionally rotates the active journal and vacuums archived journals. This deletes older journal history; do not run it merely as a read-only check:

```bash
sudo journalctl --rotate --vacuum-size=512M
```

### Applying Docker's separate console limits

The shared `x-logging` anchor in `docker-compose.yml` must be referenced by **each of the six services**. A container restart alone does not apply a changed logging driver configuration: the container must be recreated.

Validate Compose, then recreate **one service at a time**, checking readiness before proceeding. For example, with its existing image already present:

```bash
docker compose config --quiet
docker compose up -d --no-deps --no-build --pull never mqtt
```

Repeat for the remaining services during an approved maintenance window. Expect brief service interruptions and a recording gap when Frigate is recreated. Do not use `docker compose down` or pull unrelated images just to apply logging limits.

Verify the running settings:

```bash
docker inspect --format '{{.Name}} {{json .HostConfig.LogConfig}}' \
  homeassistant portainer mqtt appdaemon frigate zwave-js-ui
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Each container should report `json-file` with `max-size: 10m` and `max-file: 3`. Also verify application files are being written, Z-Wave's `/health` endpoint returns success, and Frigate is producing fresh recordings for every camera.

The deployed policies were tested in isolation for below-threshold behavior, exact 10 MiB/1 MiB rotation thresholds, preservation of archived contents, three-archive retention, and expired Z-Wave archive cleanup. All services were checked after the rollout. Protected backups of the original configuration and logs remain under `/opt/homeautomation/backups`; these one-time backups are not a recurring backup strategy.

## Outstanding Follow-up

The following were assessed but **not changed**:

- **Recording storage:** resize retention for available capacity, considering continuous and motion retention together. Log rotation does not resolve the nearly full recording SSD.
- **Access protection:** enable/use Frigate's authenticated interface and restrict unauthenticated port 5000 to trusted integrations. Enabling Frigate authentication alone does not protect port 5000. MQTT authentication, camera credentials, unused camera services/P2P, and network restrictions need a coordinated review.
- **Detection relevance:** consider motion masks, meaningful zones, and evidence-based person-filter tuning. Person-only tracking and the existing detection resolution/rate were preserved.
- **Reliability:** monitor the upgraded FFmpeg/VAAPI path over a longer period before declaring the earlier decoder crashes resolved. Keep working GPU acceleration enabled.
- **Recovery:** schedule consistent configuration/database backups, keep an off-machine copy, and test restoration.
- **Host maintenance:** plan OS/kernel support separately. No OS, kernel, or camera firmware upgrade was performed.

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