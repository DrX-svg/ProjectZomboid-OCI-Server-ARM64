# System Architecture

## Overview

This project documents the deployment and administration of
a Project Zomboid dedicated multiplayer server on Oracle
Cloud Infrastructure (OCI).

The server runs on Ubuntu ARM64 and uses Docker and FEX-Emu
to support the x86-64 Project Zomboid dedicated server.

## Infrastructure

- Cloud provider: Oracle Cloud Infrastructure
- Operating system: Ubuntu 24.04 ARM64
- Architecture: AArch64
- Container runtime: Docker
- Compatibility layer: FEX-Emu
- Game server: Project Zomboid Build 42
- Service management: systemd
- Remote administration: SSH, Python and RCON

## Runtime Architecture

Oracle Cloud VM (ARM64)
|
+-- Ubuntu Linux
    |
    +-- Docker
    |   |
    |   +-- pz-server-fex
    |       |
    |       +-- FEX-Emu
    |           |
    |           +-- x86-64 Project Zomboid Server
    |
    +-- systemd
    |   |
    |   +-- pz-fex.service
    |   +-- pz-discord-bot.service
    |   +-- pz-softlock-watchdog.service
    |   +-- pz-softlock-watchdog.timer
    |
    +-- Python and shell utilities
        |
        +-- RCON administration
        +-- Player monitoring
        +-- Graceful shutdown
        +-- Discord integration
        +-- Automated recovery

## Server Monitoring

The Lua monitoring bridge tracks player activity,
game time, pause state and weather conditions.

The bridge exports status information to a file
that can be queried by external administration tools.

## Automated Recovery

The softlock watchdog periodically checks process
availability and RCON responsiveness.

Once RCON has successfully responded, three consecutive
RCON failures while the game process remains alive
trigger diagnostic collection and service restart.

Diagnostics include process information, systemd logs
and a JVM thread dump.

RCON failures are used as a softlock heuristic and
do not independently prove that the JVM is deadlocked.

## Data Persistence

The examined Docker container has no configured
Docker bind mounts or volumes.

Game saves and configurations are stored within
the container filesystem.

Container recreation requires special care:
persistent backups or external storage should be
established before replacing the container.

## Third-Party Components

FEX Docker base:
https://github.com/EthanHand/project-zomboid-docker-arm64

ARM64 server tooling:
https://github.com/kaanzapkinus/ZomboidServer-arm

The original source, its modifications and the
project-specific components are documented separately.
