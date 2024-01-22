# Qolsys IQ Panel 2 Integration with Home Assistant

In order to integrate the Qolsys Panel with Home Assistant, we will use the [AppDaemon](https://appdaemon.readthedocs.io/) addon.  AppDaemon allows you to run custom python scripts that can interact with Home Assistant and there is a [Qolsys Gateway](https://github.com/XaF/qolsysgw) script that we will run.  These instructions are based on the instructions found in the git repo.


## MQTT Broker Addon

AppDaemon and Home Assistant communicate using MQTT.  This is a lightweight messaging protocol that is easy to setup and use.

1. From Settings -> Addons, install the Mosquitto Broker Addon.
1. Under configuration, set the Options yaml to be:
```yaml
logins:
  - username: appdaemon
    password: appdaemon
require_certificate: false
certfile: fullchain.pem
keyfile: privkey.pem
customize:
  active: false
  folder: mosquitto
```
1. Add an appdaemon user/pwd in the configuration and customize as needed.
1. Under Info, select to 'Start on boot', 'Watchdog', and 'Auto update'.
1. Start the addon and check the logs to verify it's running.

## Connect Home Assistant to the MQTT Broker

1. Under settings -> Devices and Services, click on MQTT
1. Select to configure Home Assistant for the MQTT Broker.

## AppDaemon

1. From Settings -> Addons, install the AppDaemon Addon.
1. Under Info, select to 'Start on boot', 'Watchdog', and 'Auto update'.
1. Start the addon and check the logs to verify it's running.

## Home Assistant Community Store - HACS

We will use the [Home Assistant Community Store](https://hacs.xyz/) to install the Qolsys Gateway script.

1. Open an SSH session.
1. Run the following command to install HACS:
```bash
wget -O - https://get.hacs.xyz | bash -
```
1. Under Settings -> Three Dots - > Restart Home Assistant
1. From Settings -> Devices and Services -> Integrations.
1. Click on the + button to add an integration.
1. Find HACS and click on Configure,
  1. Check 'I know how to access Home Assistant Logs'
  1. Check ' I know there are no add-ons in HACS'
  1. Check 'I know that everything inside HACS including HACS itself is custom and untested by Home Assistant'
  1. Check 'I know that if I get issues with Home Assistant I should disable all my custom_components'
  1. Click Submit
1. Authorize GitHub with the access key.
1. From Settings -> Devices and Services -> HACS -> Integration entries -> Configure
1. In the window that opens, make sure that Enable AppDaemon apps discovery & tracking is checked and click Submit

## Qolsys Gateway

The Qolsys Gateway script will connect to the Qolsys Panel and publish the sensors to MQTT.  Home Assistant will then subscribe to the MQTT topics and create the sensors.

### Access token from Qolysis Panel
1. Swipe down from the top menu bar and select Settings.
1. Touch Advanced Settings and use the dealer code (you might have access with the installer code, too).
1. Touch Installation.
1. Touch Devices.
1. Touch Wi-Fi Devices.
1. Touch 3rd Party Connections.
1. Check the Control4 box to enable 3rd Party Connections.
1. The panel will reboot in order to apply the change.
1. Come back to the same menu once the reboot is done.
1. Touch Reveal secure token and note the token.

### Install Qolsys Gateway

1. Click on your User profile in the bottom left corner.
1. Generate a Long Lived Access Token and note it down.
1. From HACS -> Integrations, click on Explore & Add Repositories.
1. Click on Automations in the right panel.
1. Click on Explore & download repositories in the bottom right corner.
1. Search for qolsysgw, and click on Qolsys Gateway in the list that appears.
1. In the bottom right corner of the panel that appears, click on Download this repository with HACS
1. A confirmation panel will appear, click on Download, and wait for HACS to proceed with the download
1. Open the Studio Code Server from the left sidebar.
1. IMPORTANT: Make sure that the python code was installed under /addon_configs/apps/<random>_appdaemon/apps/qolsysgw.  At the time of this writing, it installed under /config/appdaemon.  If it did, move the qolsysgw folder to /addon_configs/apps/<random>_appdaemon/apps/qolsysgw.
1. Edit AppDaemon.yaml and add the following:
```yaml
appdaemon:
  time_zone: "America/New_York" # Adapt this to your actual timezone

  # All three of those might be already filled for you, or you set the
  # values here, or use the secrets.yaml file to setup the values
  latitude: <yourlatitude>
  longitude: <yourlongitude>
  elevation: <yourelevation>

  plugins:
    # If using the add-on in Home Assistant, that plugin will already be
    # enabled; when using the docker container, you will have to add it here
    HASS:
      type: hass
      ha_url: "http://homeassistant:8123"
      token: <yourtoken> # The token you get from home assistant

    # And we need to add the MQTT plugin
    MQTT:
      type: mqtt
      namespace: mqtt # We will need that same value in the apps.yaml configuration
      client_host: core-mosquitto # The IP address or hostname of the MQTT broker
      client_port: 1883 # The port of the MQTT broker, generally 1883

      # Only if you have setup an authenticated connection, otherwise skip those:
      client_user: appdaemon # The username
      client_password: appdaemon # The password
```
1. Relace the client_user and client_password with the user/pwd you setup in the MQTT Broker.
1. Edit Apps.yaml and add the following:
```yaml
qolsys_panel:
  module: gateway
  class: QolsysGateway
  panel_host: <Panel IP Address>
  panel_token: <Panel Token>
  log_level: DEBUG
```
1. Under Settings -> Addons -> AppDaemon, click on Restart.
1. Check the logs to verify that AppDaemon is running.  You should now see it connect to the Qolsys Panel and start pulling data.
1. Click on Overview in the top left and you should see the sensors from the Qolsys Panel.
