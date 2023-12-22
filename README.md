# Home Assistant and Zoneminder

## Introduction

I bought a property that had a security system with it that was managed by Alarm.com.  The purpose of this project is to integrate with an existing Qolsys IQPanel 2 and ADC-VC826 streaming cameras from Alarm.com and get remote monitoring without paying a subscription fee.

After looking at several options for this, I selected a combination of Home Assistant and ZoneMinder.  Home Assistant is a home automation platform that can integrate with many different devices, and I found an addon to integrate with the Qolsys panel.  ZoneMinder is a video surveillance platform that can integrate with many different cameras.

I had a variety of devices available to me to run this on, including an [Nvidia Jetson Xavier AGX](https://www.amazon.com/NVIDIA-Jetson-Xavier-Developer-32GB/dp/B083ZL3X5B), a [Raspberry Pi 4](https://www.amazon.com/Raspberry-Pi-Computer-Suitable-Workstation/dp/B0899VXM8F), and an [UP Squared AI Vision X Developer Kit](https://up-board.org/upkits/up-squared-ai-vision-kit/).

I made several attempts to get this working, and they are outlined below for reference.  The final solution ended up being Home Assistant running on a Raspberry Pi and Zoneminder running on a Jetson Xavier AGX.  I already had both devices, so my cost was $0.

## Attempt 1

This first attempt was to run everything on the Jetson Xavier AGX.  Getting Zoneminder running on the Xavier was fairly straight forward, but I was disappointed that there is no up to date Docker container for running it.  I also learned that the easiest way to run Home Assistant is with Home Assistant OS, which gives you full access to the Home Assistant Addon store.  I ultimately abandoned the Xavier for running Home Assistant.

##  Attempt 2

Knowing the Zoneminder was working on the Xavier, I decided to try running Home Assistant on a Raspberry Pi 4.  This was much easier to setup and maintain.  There are several ways to enable remote access to Home Assistant, and the most basic way is to use Port Forwarding on your router.  I learned that T-Mobile Home Internet does not support Port Forwarding, so I had to find a different solution.

##  Attempt 3

Home Assistant supports two other ways to enable remote access.  First is to use Nabu Casa, which is a paid service.  They provide a lot of very cool capabilities with this, but my goal was to keep my cost at $0.  The second way is to use a VPN.  Home Assistant has great integration with TailScale, which is a VPN service.  I was able to get this working fairly quickly.
