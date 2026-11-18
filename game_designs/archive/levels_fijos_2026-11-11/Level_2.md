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

## Estado de implementación (2026-11-13)
- Modelado terminado en Studio (fosa vertical). `Bounds` creado (481 × 659 × 481 en el volumen de la fosa).
- **Fauna ambiental:** solo peces (los 4 cardúmenes de `Config.Ambient.Fish`); sin manta ni nautilo (`Giants.Level_2 = {}`). Requiere `Bounds`.
- **Pendiente en Studio:** un único `SubDock` real (hay dos sueltos fuera del mapa), `TreasureSpawn` ×7 con `Size`, `CrabLair`, `GuardZone`, `DeepZone`, `CrabDrop1…2`, `DepthMarker`.

## Plataformas H-2 y zona J-2 (2026-11-14)
- **H-2** (×21, plataformas de ~19×20, hijas directas de `Maps.Level_2`): todas son huecos de tesoro (como `TreasureZone`). En cada partida se sortean 3 (`Config.Crab.PlatformCount`) y en cada una aparece un cangrejo que patrulla su plataforma. Si el mapa no tiene H-n se usa el `CrabLair` clásico.
- **J-2** (×1): sin uso por ahora. 

## Kraken abisal (2026-11-14)
Sustituye al leviatán (eliminado). Enemigo que ronda libre por `Bounds`: aparece en `Spawn_leviatan` a los 40 s, persigue a quien vea fuera del submarino (160 studs; más con la lámpara encendida) y golpea al tocarlo (30 de daño, empujón, 3 s de enfriamiento por jugador); tras golpear se aleja 5 s. Más lento que el nado (16 vs 20) para poder esquivarlo. Plantilla `ServerStorage.AbismoAssets.Creatures.Kraken_Abisal`; parámetros en `Config.Kraken`; lógica en `KrakenService`, animación de huesos en `KrakenClient`.

## Mandíbulas radiales (2026-11-14)
3 (`Config.Mandibula.Count`) rondan todo el mapa (puntos al azar en `Bounds`, a ≥250 studs del `SubDock` al aparecer). Persiguen a quien vean fuera del submarino (90 studs; más con la lámpara), muerden (20 de daño, empujón, 2 s de enfriamiento) y se alejan 2,5 s. Más lentas que el nado (18 vs 20). Plantilla `AbismoAssets.Creatures.Mandibula_Radial`; lógica en `MandibulaService`.

**Nivel 2 completo:** 3 cangrejos en plataformas H-2, 3 mandíbulas por todo el mapa y el kraken.
