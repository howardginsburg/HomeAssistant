# Home Assistant on Raspberry Pi w/Port Forwarding

After learning how hard it was to manually run Home Assistant, I decided to try the Home Assistant OS image on a Raspberry Pi 4.  This is much easier to setup and maintain.  I also decided to use the Nginx Proxy Manager addon to handle the SSL certificates and reverse proxy.  This is much easier to setup and maintain than the previous solution.  Since we were able to get ZoneMinder working on the Xavier, we will continue to use that.

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


#### Setup Remote Access

This will allow you to access Home Assistant from outside your home network.  I followed [this](https://www.youtube.com/watch?v=kmiJ_OjbeGg) video on YouTube.

##### DuckDNS Addon

The DuckDNS Addon will automatically update your DuckDNS domain name with your external IP address.  This will allow you to access Home Assistant from outside your home network.  It relies on LetsEncrypt to generate the SSL certificates.  Note, there is a LetsEncrypt Addon, but it is not needed as the DuckDNS Addon can do this for us.

1. Add the DuckDNS Addon
1. Your addon YAML should look like:
```yaml
domains:
  - <yoursubdomain>.duckdns.org
token: <yourduckdnstoken>
aliases: []
lets_encrypt:
  accept_terms: true
  algo: secp384r1
  certfile: fullchain.pem
  keyfile: privkey.pem
seconds: 300
```
1. On the Info section, enable 'Start on boot' and 'Watchdog'.
1. Start the addon.
1. Check the logs to make sure it's working and there are no errors.

##### Nginx Proxy Manager Addon

1. Add the NGINX Home Assistant SSL proxy addon.
1. On the Configuration tab, your addon YAML should look like:
```yaml
domain: <yoursubdomain>.duckdns.org
hsts: max-age=31536000; includeSubDomains
certfile: fullchain.pem
keyfile: privkey.pem
cloudflare: false
customize:
  active: true
  default: nginx_proxy_default*.conf
  servers: nginx_proxy/*.conf
```
1. Select to 'Start on boot'.
1. Select 'Watchdog'.
1. Start the addon.
1. Check the logs to make sure it's working and there are no errors.

##### Home Assistant Configuration

1. Select Settings -> Network
1. Under the Home Assistant URL, set the Internet URL to be https://<yoursubdomain>.duckdns.org

##### Additional Configuration

1. Open Studio Code Server from the left sidebar.
1. Open the configuration.yaml file.
1. Add the following:
```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```
1. Open Developer Tools -> TAML and select to Restart Home Assistant.
1. OpenStudio Code Server from the left sidebar.
1. Create a new file /share/nginx_proxy_default_fix_ingress.conf
1. Add the following contents
```nginx
location /api {
proxy_connect_timeout 60;
proxy_read_timeout 60;
proxy_send_timeout 60;
proxy_intercept_errors off;
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_set_header Host $host:8126;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_pass http://homeassistant.local.hass.io:8123/api
}
```
1. Restart the nginx proxy addon.

##### Port Forwarding

1. Forward port 443 on your router to port 443 on of the ip address of your Home Assistant.

## Setup Fail

It turns out that T-Mobile Home Internet uses CGNAT.  This means that you can't access your router from outside your home network.  This also means that you can't access your Home Assistant from outside your home network.  So, port forwarding and reverse proxy will definitely not be possible with my current configuration.


