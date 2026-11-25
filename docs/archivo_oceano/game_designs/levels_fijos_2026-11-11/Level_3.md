# Nivel 3 — Cueva profunda y baliza

**Función:** nivel final. Se activa la baliza y termina la partida. Es el más grande y oscuro.

| Dato | Valor |
| :-- | :-- |
| Tamaño propuesto (X × Y × Z) | **700 × 700 × 700 studs** (cubo) |
| Profundidad (HUD) | ~220 m |
| Presión | 1,2 daño/s al casco |
| Cuota | Ninguna (la baliza termina la partida) |
| Enemigos | Cangrejo guardián (1) |
| Tiempo de exploración objetivo | 4–6 minutos por equipo de 2 |

## Disposición
> Con el cubo de 700 las distancias de abajo son relativas: el nivel es mucho más grande que lo que se llena. Llenar solo las zonas de juego (ruta, naufragios/cuevas, `DeepZone`) y dejar el resto como agua abierta, roca o niebla; el cubo es el límite (`Bounds`), no un área que haya que decorar entera. Criaturas grandes: espacios de al menos 3× su tamaño.
- `SubDock` en el extremo −Z, con su nicho. El nivel es una **cueva grande** (`Cave`) con cámaras unidas por túneles.
- `BeaconSite` en el extremo +Z, dentro de `DeepZone`: una cámara amplia donde se mantiene `E` ~5 s para activar la baliza. El cangrejo puede aparecer mientras se activa; dejar cobertura alrededor.
- `GuardZone` cubre la mitad profunda de la cueva; `CrabLair` cerca de la entrada de esa mitad. `CrabDrop` en una cámara lateral lejana, no junto a la baliza (el cangrejo te saca del objetivo, no te acerca).
- Al menos dos rutas hacia la baliza, una más corta y vigilada y otra larga y más segura.

## Tesoros (bonus; sin cuota)
| Cantidad | Tamaño |
| :-- | :-- |
| 2 | Medium |
| 3 | Large |

Los Large lejos de la ruta directa a la baliza, para que sean una decisión.

## Marcadores
`Platform`, `SubDock`, `Bounds`, `Cave`, `BeaconSite` (Part de ~9 × 2 × 9, donde Claude coloca la baliza o usa `Props/Beacon`), `TreasureSpawn` ×5 (con `Size`), `DepthMarker` (`Depth = 220`), `CrabLair`, `GuardZone`, `DeepZone`, `CrabDrop1…2`, `CrabPatrol1…4` (opcional).

## Notas de ambiente
Lo más oscuro del juego. Poca luz ambiente; algunas fuentes (hongos, corales) que marquen puntos de referencia y la cámara de la baliza.
