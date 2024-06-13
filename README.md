# PoSh-Control

### Description

A Powershell script to monitor all PS processes, setup transcripting, view history, change settings, and defend against badUSB devices.

This script runs in the background and creates a system-tray tool to control it.

### Features

**Enable / Disable Powershell Transcripting**

Creates neccecary registry keys and values to enable transcripting. Then creates a new folder and powershell script to enable transcription for all powershell processes. Log files are created in the 'Documents/WindowsPowershell/Transcripts' directory.
