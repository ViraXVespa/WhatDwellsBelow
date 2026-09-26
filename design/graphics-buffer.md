# Graphics buffer

Status: binding design + live snapshot
Read when: 256-512 xz radiance buffer, disc blobs, tile occupancy

One low-res light texture in xz, 256-512, following the camera or the live stream ring.

Stamp light discs for data sources (xz, range, color). Crystals and campfires become sources; they are tint-only today. Stamp tile occupancy so a disc does not flood through walls.

Ground shader samples this RT. Engine DirectionalLight3D and OmniLight3D shadows stay off. Compatibility and web export stay the leash.

Actor sprite masks may stay separate floor quads in v1. Do not use Decal3D. Invented range and energy values go in tunables and debug.
