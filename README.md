# Project Zomboid — Oracle Cloud ARM64 Server

A cloud-hosted **Project Zomboid dedicated server** project built on Oracle Cloud Infrastructure (OCI), combining ARM64/x86-64 compatibility, Docker, Linux automation, remote administration, monitoring, and experimental performance optimization.

## Technology Stack

- **Cloud:** Oracle Cloud Infrastructure (OCI)
- **Operating system:** Ubuntu 24.04 ARM64 (AArch64)
- **Containerization:** Docker
- **Compatibility:** FEX-Emu (x86-64 on ARM64)
- **Languages:** Python, Lua, Bash
- **Administration:** SSH, RCON, systemd
- **Integration:** Discord bot
- **Game server:** Project Zomboid Build 42
- **Version control:** Git

## Architecture

```text
Oracle Cloud Infrastructure — ARM64 VM
|
+-- Ubuntu Linux
    |
    +-- Docker
    |   +-- pz-server-fex
    |       +-- FEX-Emu
    |           +-- Project Zomboid Dedicated Server (x86-64)
    |
    +-- systemd
    |   +-- pz-fex.service
    |   +-- pz-discord-bot.service
    |   +-- pz-softlock-watchdog.timer
    |       +-- pz-softlock-watchdog.service
    |
    +-- Administration
        +-- Python RCON client
        +-- Player session tracking
        +-- Lua monitoring bridge
        +-- Graceful shutdown
        +-- Discord bot
        +-- Automated recovery
```

See [System Architecture](docs/architecture.md).

## Key Engineering Work

### ARM64 / x86-64 Compatibility

Adapted an existing Docker/FEX-Emu environment to run the x86-64 dedicated server on an ARM64 cloud instance. The changes pin the FEX revision, initialize submodules explicitly, and prepare the container filesystem with appropriate directory ownership.

[View Docker modifications](docker/docker-fex-oci.patch)

### Remote Server Administration

Developed and integrated Python and Bash utilities for:

- RCON command execution and response handling
- Player session tracking through connection logs
- Game-world status retrieval
- Controlled save and shutdown procedures

### Automated Server Recovery

Implemented a systemd watchdog that checks process availability and RCON responsiveness. Following a successful initial RCON health check, **three consecutive RCON failures** trigger diagnostic collection, including process state, journal logs, and a JVM thread dump, followed by a service restart.

This is a **heuristic recovery mechanism**, not definitive deadlock detection.

### Discord Integration

Integrated a Python Discord bot with Linux administration tools and systemd service management. The bot runs under a dedicated Linux account and reads its configuration from environment variables. Its full command set is not documented here until separately verified against `bot.py`.

### Lua Server Monitoring

Implemented a Lua bridge that records player activity, world time, pause state, and weather information for use by external monitoring tools.

### World Pre-generation Experiments

Investigated map-loading delays during high-speed vehicle movement. Prototyped a teleport queue, checkpoint persistence, client-server ACK validation, position checks, timeouts, and a broadcast command variant.

**These experiments did not produce a confirmed reliable end-to-end pre-generation solution.**

[Read experiment notes](experiments/world-pregen/README.md)

## Technical Documentation

- [System Architecture](docs/architecture.md)
- [Engineering Contributions](docs/contributions.md)
- [World Pre-generation Experiments](experiments/world-pregen/README.md)
- [Third-Party Attribution](docs/third-party.md)

## Third-Party Projects

This repository references and integrates third-party work with attribution:

- [EthanHand/project-zomboid-docker-arm64](https://github.com/EthanHand/project-zomboid-docker-arm64) — upstream Docker/FEX environment. Project-specific changes are provided as a patch.
- [kaanzapkinus/ZomboidServer-arm](https://github.com/kaanzapkinus/ZomboidServer-arm) — imported v2.2.0 source under its original MIT license in `third_party/ZomboidServer-arm/`.

See [Third-Party Attribution](docs/third-party.md) for licensing details.

## Important Notes

This repository is a technical portfolio and infrastructure reference, **not a turnkey production deployment**. Sensitive credentials, player saves, and runtime logs are excluded.

The examined Docker container had no external volumes or bind mounts. Backups should be secured before replacing or recreating it.

## Development History

The historical Git commits were reconstructed retrospectively in October 2026 using available source files, filesystem timestamps, and development records. They document project evolution but are **not** an original real-time Git commit history.
