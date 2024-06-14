# PoSh-Control

### Description

A Powershell script to monitor all PS processes, setup transcripting, view history, change settings, and defend against badUSB devices.

This script runs in the background and creates a system-tray tool to control it.

![Screenshot_1](https://github.com/beigeworm/PoSh-Control/assets/93350544/4045f95e-ed8e-44fa-bbdf-5bb0f0183e12)

### Features

**Enable / Disable Powershell Transcripting**

Creates neccecary registry keys and values to enable transcripting. Then creates a new folder and powershell script to enable transcription for all powershell processes. Log files are created in the 'Documents/WindowsPowershell/Transcripts' directory (off by default)


**Execution Policy Control**

Change Powershell execution policy on the fly with a simple button (this will affect the script itself on next run if enabled)


**View Logs and History**

Open Powershell command history, Transcript Files and BadUSB detection logs with a click.


**BadUSB Detection and Protection**

Monitor Windows for new usb devices and track keystrokes for 60 seconds when a device is detected, if keystrokes are entered above 60 keys per second all inputs are disable for 20 seconds (on by default)
