# Nivel 1 — Naufragio poco profundo

**Función:** introducir el juego. Aquí se aprende a salir, recoger, depositar y volver. Sin cangrejo; el único peligro es el oxígeno y la oscuridad.

| Dato | Valor |
| :-- | :-- |
| Tamaño propuesto (X × Y × Z) | **200 × 60 × 260 studs** |
| Profundidad (HUD) | ~40 m |
| Presión | 0,1 daño/s al casco (muy baja) |
| Cuota | **100 $** |
| Enemigos | Ninguno (fauna ambiental opcional, sin daño) |
| Tiempo de exploración objetivo | 2–3 minutos por equipo de 2 |

## Disposición
- `SubDock` en el centro del extremo −Z. El nivel crece hacia +Z.
- Un **naufragio** (`Wreck`) grande y fácil de recorrer a ~100–140 studs del `SubDock`, con 2–3 compartimentos; luz natural tenue en la zona del submarino y más oscuro dentro del casco hundido.
- Suelo marino con algo de relieve y rocas para orientarse; sin cuevas largas.
- `Bounds` = la caja entera. Pared de roca en los bordes para que no se vea el vacío.

## Tesoros (valor total ≈ 250 $; cuota 100 $)
| Cantidad | Tamaño |
| :-- | :-- |
| 4 | Small |
| 2 | Medium |

Colocar los Small cerca (a ~40–80 studs del `SubDock`) para que el primer viaje cumpla casi la cuota; los Medium dentro del naufragio.

## Marcadores
`Platform`, `SubDock`, `Bounds`, `Wreck`, `TreasureSpawn` ×6 (con `Size`), `DepthMarker` (atributo `Depth = 40`). Sin marcadores de cangrejo.

## Notas de ambiente
Color de agua más claro (ver `Config.Water.SurfaceColor`). Algún elemento llamativo (boya, ancla) que oriente hacia el naufragio.
