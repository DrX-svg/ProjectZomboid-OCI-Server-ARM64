# Third-Party Software and Attribution

## ZomboidServer-arm

- **Original repository:** https://github.com/kaanzapkinus/ZomboidServer-arm
- **Imported version:** v2.2.0
- **Upstream commit:** `4c78f0dfbf9c529f78f8fc7064dfb7127c410c02`
- **License:** MIT
- **Local location:** `third_party/ZomboidServer-arm/`

The upstream source is included with its original `LICENSE` and attribution. The upstream import is distinct from project-specific OCI scripts, configurations, and experiments. See `third_party/ZomboidServer-arm/UPSTREAM.md`.

## Project Zomboid Docker ARM64

- **Original repository:** https://github.com/EthanHand/project-zomboid-docker-arm64
- **Local changes:** `docker/docker-fex-oci.patch`

The Dockerfile was used as a starting point, and project-specific changes included:

- Pinning FEX-Emu to revision `a08a6ce`
- Initializing Git submodules explicitly
- Preparing Steam, Zomboid, and FEX RootFS directories
- Setting appropriate filesystem ownership

No explicit license was identified in the examined upstream checkout. The Dockerfile is therefore **not** redistributed in full here; the repository contains a patch and a link to the upstream source. The patch does not grant additional rights over the upstream code.

## Custom Components

Project-specific Python, Lua, Bash, and systemd additions are maintained outside `third_party/`. Their licensing has not yet been designated. **The MIT license in `third_party/ZomboidServer-arm/` applies to that upstream project, not automatically to every file in this repository.**

## Attribution and Development History

Third-party work is attributed to its original authors and is not represented as original work. Custom changes, integrations, operational configuration, and experiments are documented separately in [Engineering Contributions](contributions.md).

Historical development commit timestamps were reconstructed in October 2026 from available files and records.
