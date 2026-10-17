# World Pre-generation Research

## Problem

During high-speed vehicle travel, Project Zomboid could temporarily halt vehicle movement while world areas were being generated or loaded. This was most noticeable when driving quickly on roads, compared with slower off-road travel.

## Objective

Explore whether map areas could be loaded or generated in advance to reduce interruptions during vehicle travel.

## Prototype Evolution

### Version 1 — Sequential Teleportation

The first server-side Lua controller attempted to:

- Read target coordinates from a queue file
- Locate a dedicated `PregenBOT` player
- Teleport the player through queued coordinates
- Save progress and checkpoints
- Support `pause`, `run`, `run1`, and `run20` controls

### Version 2 — Client Acknowledgment

The next iteration replaced direct server-side teleport attempts with a client-server command/acknowledgment design:

- Send teleport requests to the client
- Process ACK and failure notifications
- Validate reported player position on the server
- Handle request timeouts
- Persist progress via checkpoint files

### Version 3 — Broadcast Experiment

The final variant changed `sendServerCommand(player, ...)` to `sendServerCommand(...)`, exploring broadcast delivery rather than a command addressed to a specific player.

## Results and Limitations

The queue, checkpoint, status tracking, and ACK-handling logic were implemented as experiments. However, a complete and reliable world pre-generation workflow **was not demonstrated**.

The ACK-based versions require complementary client-side code to execute teleport requests and send acknowledgments; that code is not included here. The final broadcast variant is **not production-ready**.

## Version History

Earlier iterations are preserved in the Git history for `RBXPregenQueue.lua`:

- `3918785` — initial sequential queue
- `347d0ff` — client ACK and position validation
- `73acc09` — broadcast command experiment

The dates for these historical commits were reconstructed from available development records and file timestamps.
