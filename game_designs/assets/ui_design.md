# UI Design — HUD de buceo
- Panel inferior izquierdo (240x70): profundidad en metros (studs) + barra de oxígeno con tiempo restante m:ss.
- Barra azul; pasa a rojo por debajo del 20 %.
- Datos: `UpdateHUD(current, max)` desde OxygenService (4 Hz). Profundidad calculada en cliente.
