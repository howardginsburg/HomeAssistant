# Attempt 3 - Home Assistant and ZoneMinder

After learning that T-Mobile does not support port forwarding, my next attempt was to try setting up a VPN to get remote access.

## Hardware
1. [Raspberry Pi 4](https://www.amazon.com/Raspberry-Pi-Computer-Suitable-Workstation/dp/B0899VXM8F)
1. [Nvidia Jetson Xavier AGX](https://developer.nvidia.com/embedded/jetson-agx-xavier-developer-kit)
1. [NVME Drive](https://www.amazon.com/gp/product/B08GL575DB/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&th=1) - this is just an example of what I had.
1. (Optional) [USB Webcam](https://www.amazon.com/WEDOKING-Microphone-Streaming-Computer-Portable/dp/B08HZ5GNF9) 
1. (Optional) [Jumper Caps](https://www.amazon.com/dp/B077957RN7?psc=1&ref=ppx_yo2ov_dt_b_product_details)

### Hardware Setup

1. Follow the [instructions](https://www.home-assistant.io/installation/raspberrypi) to install Home Assistant OS on a Raspberry Pi 4.
1. Follow the Jetson Xavier AGX [setup](/Nvidia%20Jetson%20Xavier%20AGX.md) instructions.

## Software Setup

### Home Assistant Setup

1. Log into Home Assistant at http://homeassistant.local:8123
1. Click on your user name in the bottom left corner.
1. Enable "Advanced Mode".
1. Refresh your browser.

#### SSH Addon

1. From Settings -> Addons, install Advanced SSH Terminal addon.
1. Under configuration, set the Options yaml to be:
```yaml
ssh:
  username: hassio
  password: <yourpassword>
  authorized_keys: []
  sftp: false
  compatibility_mode: false
  allow_agent_forwarding: false
  allow_remote_port_forwarding: false
  allow_tcp_forwarding: false
zsh: true
share_sessions: false
packages: []
init_commands: []
```
1. Under Info, select 'Show in sidebar'.
1. Start the addon and check the logs to verify it's running.

#### Studio Code Addon

1. From Settings -> Addons, install Studio Code Server addon.
1. Under Info, select 'Show in sidebar'.

## Setup Remote Access

This will allow you to access Home Assistant from outside your home network.  We will use Tailscale for this approach.

### Create a Tailscale Account

1. Sign into [Tailscale](https://login.tailscale.com/login) using your Google account.

### Install Tailscale on Home Assistant

1. Add the Tailscale Addon.
1. Under Info, select 'Start on boot', 'Watchdog', and 'Auto Update'.
1. Start the addon.
1. In the logs, you'll see a URL to authorize the device.  Copy this URL and paste it into a browser.
1. From the Tailscale admin page,
  1. Authorize the device.
  1. Disable Key Expiry.
1. From the Tailscale Addon, open the Web UI and select 'Stop Advertising Exit Node'.

### Install Home Assistant and Tailscale on your phone

1. Install the Tailscale app on your phone and login.
1. Select your homeassistant device to get the tailscale ip address for it.
1. Make sure Tailscale is 'Active'.
1. Install the Home Assistant app on your phone.
1. Open the Home Assistant app and login.  The url should be the https://<tailscaleip>:8123.

## Qolsys IQ Panel 2 Integration

1. Follow the [instructions](/Qolsys.md) to integrate the Qolsys IQ Panel 2 with Home Assistant.

