# Engineering Contributions

## 1. Docker and FEX-Emu Adaptation

Adapted an existing Docker-based FEX environment
for the Oracle Cloud ARM64 server deployment.

Changes include:

- Pinning FEX-Emu to revision a08a6ce
- Explicit Git submodule initialization
- Preparing Steam, RootFS and Zomboid directories
- Configuring ownership for the steam user

See: docker/docker-fex-oci.patch

Original project:
https://github.com/EthanHand/project-zomboid-docker-arm64

## 2. Python RCON Administration

Implemented a lightweight Python RCON client using
TCP sockets and binary packet serialization.

Features include:
- RCON authentication
- Command transmission
- Response parsing
- Error handling
- Password retrieval from environment variables

See: scripts/pzrcon.py

## 3. Lua Server Monitoring

Developed a server-side Lua bridge to monitor:

- Online player activity
- Game pause state
- Temperature and precipitation
- Thunderstorm conditions
- World time

Supports event-based status updates and periodic snapshots.

See: scripts/monitoring/RBXBridge.lua

## 4. Softlock Detection and Recovery

Integrated a systemd watchdog that monitors
RCON responsiveness while the game process is running.

After three consecutive failures following an
initial successful RCON check, the watchdog collects:

- Process state information
- systemd journal logs
- JVM thread dump

It then restarts the game service.

See: scripts/monitoring/pz-softlock-watchdog

## 5. Remote Administration

Integrated Python and shell utilities for:

- Player session tracking
- RCON queries
- Controlled server shutdown
- Game-world status retrieval
- Discord bot integration

The utilities are managed alongside the server
through systemd services.

## 6. World Pre-generation Research

Prototyped experimental pre-generation workflows
to investigate map-loading delays during high-speed
vehicle movement.

Iterations included:

1. Sequential teleportation with checkpoints
2. Client-server ACK and position validation
3. Broadcast command experiments

The prototype did not reach a confirmed reliable
end-to-end pre-generation solution.

See: experiments/world-pregen/RBXPregenQueue.lua

Earlier iterations are preserved in Git history.

## 7. Troubleshooting and Investigation

Investigated:

- ARM64 and x86-64 compatibility constraints
- Server startup and runtime failures
- Mod conflicts and compatibility problems
- Server responsiveness and RCON failures
- World-generation delays during vehicle movement

Solutions, experimental attempts and unresolved
limitations are distinguished in the repository.

## Historical Notes

The Git history was reconstructed retrospectively
from source files, filesystem timestamps and
available development records.

Commits with historical timestamps do not represent
an original real-time development commit history.
