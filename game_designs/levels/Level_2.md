# Nivel 2 — Naufragios y cuevas

**Función:** subir la tensión. Aparece el **Cangrejo guardián**. Hay que decidir si arriesgarse a entrar en su territorio por los tesoros mejores.

| Dato | Valor |
| :-- | :-- |
| Tamaño propuesto (X × Y × Z) | **700 × 700 × 700 studs** (cubo) |
| Profundidad (HUD) | ~120 m |
| Presión | 0,5 daño/s al casco |
| Cuota | **200 $** |
| Enemigos | Cangrejo guardián (1) |
| Tiempo de exploración objetivo | 3–4 minutos por equipo de 2 |

## Disposición
> Con el cubo de 700 las distancias de abajo son relativas: el nivel es mucho más grande que lo que se llena. Llenar solo las zonas de juego (ruta, naufragios/cuevas, `DeepZone`) y dejar el resto como agua abierta, roca o niebla; el cubo es el límite (`Bounds`), no un área que haya que decorar entera. Criaturas grandes: espacios de al menos 3× su tamaño.
- `SubDock` en el extremo −Z. Dos zonas:
  - **Zona segura** (primeros ~120 studs): fondo abierto con un naufragio pequeño y tesoros fáciles.
  - **Territorio del cangrejo** (resto, hacia +Z): cuevas y un naufragio más grande y oscuro.
- `GuardZone` cubre el territorio del cangrejo y **no** incluye el `SubDock` ni su nicho.
- `DeepZone` = el extremo +Z (cuevas más profundas). `CrabDrop` dentro de `DeepZone`, lo más lejos posible del `SubDock`, para que el regreso lleve varios segundos.
- `CrabLair` en el borde de `GuardZone`, visible desde lejos (hueso, rocas, silueta).
- Cuevas con al menos dos rutas para poder rodear al cangrejo; pasillos de ≥ 10 studs.

## Tesoros (valor total ≈ 500 $; cuota 200 $)
| Cantidad | Tamaño | Dónde |
| :-- | :-- | :-- |
| 3 | Small | Zona segura |
| 3 | Medium | Mitad del nivel, cerca de `GuardZone` |
| 1 | Large | Dentro de `DeepZone` (motivo para arriesgarse) |

## Marcadores
`Platform`, `SubDock`, `Bounds`, `Wreck`, `TreasureSpawn` ×7 (con `Size`), `DepthMarker` (`Depth = 120`), `CrabLair`, `GuardZone`, `DeepZone`, `CrabDrop1…2`, `CrabPatrol1…4` (opcional).

## Notas de ambiente
Más oscuro que el Nivel 1. La linterna debe ser útil dentro de las cuevas; zonas con casi nada de luz en `DeepZone`.
