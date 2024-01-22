# Home Automation and Video Surveillance

## Introduction

I bought a property that had a security system with it that was managed by Alarm.com.  The purpose of this project is to integrate with an existing Qolsys IQPanel 2 and ADC-VC826 streaming cameras from Alarm.com and get remote monitoring without paying a subscription fee.

After looking at several options for this, I selected Home Assistant as the primary home automation platform, and experimented with both ZoneMinder and Frigate for video surveillance.  For the final solution, I am running the following:

I had a variety of devices available to me to run this on, including an [Nvidia Jetson Xavier AGX](https://www.amazon.com/NVIDIA-Jetson-Xavier-Developer-32GB/dp/B083ZL3X5B), a [Raspberry Pi 4](https://www.amazon.com/Raspberry-Pi-Computer-Suitable-Workstation/dp/B0899VXM8F), and an [UP Squared AI Vision X Developer Kit](https://up-board.org/upkits/up-squared-ai-vision-kit/).

For my final solution to run everything, I settled on the following:

1. UP Squared AI Vision X Developer Kit for the main hardware.
1. Home Assistant for Home Automation
1. Frigate for Video Surveillance

I had no issues interfacing with the Qolsys IQ Panel 2, however the ADC-VC826 cameras had proprietary firmware, and no way to change it out, so I will replace it.

You can see the final setup instructions for this project [here](/UpSquared%20Vision%20AI/Readme.md)

Other Attempts:

## Nvidia Jetson Xavier AGX with Home Assistant and Zoneminder

This first attempt was to run everything on the Jetson Xavier AGX.  Getting Zoneminder running on the Xavier was fairly straight forward, but I was disappointed that there is no up to date Docker container for running it.  As a first time setup, I also learned that the easiest way to run Home Assistant is with Home Assistant OS, which gives you full access to the Home Assistant Addon store.  This will not run on the Xavier.

##  Raspberry Pi

I was able to run Home Assistant OS on a Raspberry Pi 4 very easily.  This was much easier to setup and maintain.  There are several ways to enable remote access to Home Assistant, and the most basic way is to use Port Forwarding on your router.  I learned that T-Mobile Home Internet does not support Port Forwarding, so I had to find a different solution.  The Pi is not a suitable device for video surveillance, so I would need to use the Xavier or Up Squared for that.
