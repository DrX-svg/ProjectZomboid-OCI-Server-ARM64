# Project Zomboid — Oracle Cloud ARM64 Server

Dedicated multiplayer server infrastructure built on Oracle Cloud Infrastructure (OCI), Ubuntu ARM64, Docker and FEX-Emu.

## Docker / FEX-Emu

Based on:
https://github.com/EthanHand/project-zomboid-docker-arm64

Custom modifications are documented in `docker/docker-fex-oci.patch`:

- Pin FEX-Emu to a specific Git revision.
- Initialize Git submodules explicitly.
- Prepare Steam, Zomboid and FEX RootFS directories with appropriate ownership.

## Development history

The Git history was reconstructed retrospectively in October 2026.
Historical timestamps are based on available filesystem metadata and development records, not original Git commits.
