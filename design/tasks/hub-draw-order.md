# Hub draw-order / sorting sweep

id: hub-draw-order
owner: web
status: open
done-when: Player never sorts in front of awnings, roofs, or stall ceiling; receptionist sorts correctly; player shadows do not clip through buildings.
resume: python tools/open_slice.py hub --task hub-draw-order

## Intent
Cross-cutting 2.5D draw-order fixes after geometry is stable.

## Refs
Drop examples in design/refs/hub-draw-order/.
