# Guías de niveles de Abismo

Guías para modelar el mapa final de cada nivel. Una por mapa: [Nivel 1](Level_1.md), [Nivel 2](Level_2.md), [Nivel 3](Level_3.md) y [Parada](Parada.md). Recorrido: **Nivel 1 → Parada → Nivel 2 → Parada → Nivel 3**.

Las medidas son propuestas de partida. Para comprobarlas hay una caja por nivel en Studio (`Workspace.LevelSizeGuides`): ajustar su tamaño si no sirve y avisar para actualizar estas guías y los valores de `Config`.

## Cajas de tamaño en Studio

`Workspace.LevelSizeGuides` tiene una caja por mapa (`Level_1_Guide`, `Level_2_Guide`, `Level_3_Guide`, `Parada_Guide`), en una fila aparte (z de −900 en adelante) para no solaparse con los mapas actuales:

| Mapa | Tamaño (X × Y × Z) | Centro (X, Y, Z) |
| :-- | :-- | :-- |
| Nivel 1 | 200 × 60 × 260 | (0, −22, −770) |
| Nivel 2 | 280 × 80 × 380 | (340, −92, −710) |
| Nivel 3 | 360 × 110 × 520 | (760, −177, −640) |
| Parada | 80 × 40 × 80 | (1080, −32, −860) |

Cada caja incluye: `SizeBox` (el volumen, con su tamaño en el atributo `SizeXYZ`), `SubScaleRef` (un bloque gris del tamaño del submarino acoplado), `DockRef` (bola verde: dónde va `SubDock`, extremo −Z) y `DeepRef` (bola roja: zona profunda sugerida, extremo +Z). Para ajustar: cambiar el `Size` de `SizeBox` y avisar el valor definitivo.

## Reglas comunes

- **Estructura** en `Workspace.Maps.<Mapa>` (Folder). Los scripts buscan por **nombre exacto**. Los objetos de control son transparentes, `CanCollide = false`, `Anchored = true`.
- **Mínimo obligatorio de cada mapa:** `Platform` (base), `SubDock` (donde se acopla el submarino) y `Bounds` (volumen del nivel).
- **Submarino:** mide ~26,6 × 15,4 × 36,9 studs (con escala 1,5). `SubDock` es el centro del interior (`Hull`); el eje Z mira hacia donde sale la compuerta (`Hatch.ExitPoint`, +Z local del submarino) hacia el área explorable. Reservar un **nicho/bahía de acoplamiento** de al menos 40 × 24 × 50 studs sin obstáculos alrededor del `SubDock`, para esconder la forma de caja (ver `creation_models.md`).
- **Jugador:** avatar de 4 × 5 studs. Nada a 16 studs/s con flotabilidad neutra (se queda quieto al soltar los controles; Espacio sube, Ctrl/C baja). Pasillos y cuevas de al menos 10 studs de ancho y 8 de alto para que quepan 4 jugadores y el cangrejo.
- **Agua:** todo el nivel está bajo agua (Terrain). La niebla/color por profundidad los controla `Config.Water`; el mapa no debe depender de luz solar. Dejar zonas oscuras donde la linterna importe.
- **Tesoros:** Attachments `TreasureSpawn` con atributo `Size` (`Small` 25 $, `Medium` 75 $, `Large` 200 $). Cada jugador lleva 4 objetos. El valor total debe superar la cuota con margen, pero no sobrar demasiado.
- **Cangrejo (Niveles 2 y 3):** `CrabLair`, `GuardZone`, `DeepZone`, `CrabDrop1…N` y opcionalmente `CrabPatrol1…N` (ver `creation_models.md`). El cangrejo es más lento que el jugador (10 vs 16 studs/s) y detecta a 45 studs (67 con la lámpara).
- **Orientación del nivel:** `SubDock` en el extremo −Z; la zona profunda (`DeepZone`) en el extremo +Z. La ruta de regreso desde `DeepZone` al `SubDock` debe tardar varios segundos de nado.
- **Rendimiento:** mantener el conteo de partes razonable (mallas simples, pocas luces). Objetivo: < 3000 partes visibles por nivel.

## Lista de entrega por nivel

- [ ] `Platform`, `SubDock`, `Bounds` con las medidas de la guía.
- [ ] Nicho/bahía de acoplamiento alrededor de `SubDock`; la compuerta da al área explorable.
- [ ] `TreasureSpawn` con `Size` según la tabla del nivel.
- [ ] Marcadores del cangrejo (Niveles 2 y 3).
- [ ] `BeaconSite` en el Nivel 3.
- [ ] Probar con el submarino acoplado: el jugador sale, recoge, vuelve, y el cangrejo no entra en la zona del `SubDock`.
