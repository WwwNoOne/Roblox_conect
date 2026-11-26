# Reglas para Codex: código y construcción de mapas

Contrato entre el trabajo de mapas, ambientación y sonido (Codex) y el código Luau (Claude). Romper un nombre, un marcador o una medida de esta lista no da error al importar: la partida simplemente deja de funcionar (ascensor que no atraca, criaturas quietas, escondites sin aviso). Ante la duda, anotarlo en `arranque.md` y dejar el código a Claude.

## 1. Repositorio y Rojo

- Trabajar en el worktree `Roblox_conect-backrooms`, rama `backrooms-cleanup`. El worktree `Roblox_conect` (`main`) es solo un espejo.
- `rojo serve` vigila `src/`. **Nunca `rm -r` ni archivos temporales dentro de `src/`**: Rojo 7.7.1 se cae (`change_processor.rs` línea 179) y Studio deja de sincronizar sin avisar. Generar los temporales fuera de `src/` (p. ej. en `assets_build/` o `/tmp`).
- Commits con `git -c user.name="Trabajo" -c user.email="wwwnoone@outlook.com"`. Al terminar: `git merge --ff-only backrooms-cleanup` en `main` y push de las dos.
- Los mapas y todo lo que hay en `Workspace` y `ServerStorage` **no pasan por Rojo**. Tras importar o mover algo en Studio, **guardar el place**.

## 2. Código (`src/`)

- **El Luau lo escribe Claude.** Codex no edita scripts de `src/`. Si un mapa necesita lógica nueva (un objeto interactivo, un tipo de escondite, un evento), se describe en `arranque.md` o en el doc del nivel y Claude lo integra.
- Excepción: Codex puede ajustar **valores** (no estructura) en `src/ReplicatedStorage/Shared/Config.luau`:
  - `LevelAtmosphere.Profiles.Level_N` (ambiente de cada nivel);
  - `Audio.Music.Levels` y volúmenes de `Audio`;
  - textos de `Hiding` (`PromptText`, `ObjectText`).
  
  Sin añadir ni quitar claves, sin cambiar `Run.Stages` (orden, nombres de mapa, cuotas) ni `LevelSeconds`.
- Hoy quedan valores de prueba que **no** se tocan: `Monster.PerLevel = 5` y `Monster.Debug`. Se ajustan antes de publicar.

## 3. Construcción de mapas

### Nombres y lugar

- Cada nivel es un `Model` llamado exactamente `Level_1` … `Level_6`, dentro de `Workspace.Maps`. Al jugar, `Runs` los aparta a `ServerStorage.MapStorage` y solo carga el de la etapa actual.
- **Nada suelto en la raíz del `Workspace`.** Ejemplo real: `Workspace.zona` (700×1×700, visible y con colisión, a altura 49,5) atravesaba el Nivel 1 a la altura de la cabeza y bloqueaba a los jugadores. Todo lo del nivel va dentro de su modelo; las pruebas, en `ServerStorage`.
- Que las cajas de los mapas se solapen entre sí no importa en partida, pero cada mapa debe ser autosuficiente (su suelo, sus límites, sus luces).

### Marcadores (no renombrar ni quitar)

| Marcador | Tipo | Regla |
|---|---|---|
| `ElevatorDock` | BasePart, PrimaryPart del mapa | Uno por mapa. El ascensor atraca ahí. Su altura menos 6 es la planta 0 de `NavFloors`. |
| `Platform` | BasePart | Andén delante del ascensor. |
| `Bounds` | BasePart | Caja del nivel. Lleva los atributos `NavFloors` ("0,14,…") y `NavSpacing` (la celda). Rojo descarta los atributos del modelo raíz: ponerlos siempre también en `Bounds`. |
| `Patrol#`, `CreatureSpawn` | Attachment | Rutas y apariciones de criaturas. En cruces de pasillos y en cada escalera. |
| `MachineSpawn` | Attachment | Generadores (12 contra muros, repartidos). |
| `PuzzleSpawn` | Attachment | En `Cofre##` y en `Puerta##`. Las puertas llevan `Width` y `Height`; el vano mide 10 × 9 con pared de 1. |
| `TreasureSpawn` | Attachment | Tesoros. |
| `Escondite` | BasePart | Ver «Escondites». |
| `Beacon` | Model | Solo en el nivel final (`Level_6`). Si falta, el código pone una baliza provisional. |

### Suelo y red de las criaturas

`MapNav` lanza rayos hacia abajo en cada planta de `NavFloors` y une los puntos vecinos. Para que la red no quede en islas:
- Suelos transitables con `CanCollide = true` y casi planos (normal Y > 0,7). Las rampas y escaleras deben poder recorrerse a pie: entre puntos vecinos no puede haber más de 10 studs de desnivel.
- Toda zona elevada (casas del árbol, puentes, pasarelas, azoteas) debe enlazar con el suelo por una escalera o rampa continua, y su altura debe estar en `NavFloors`. Si no, queda aislada: hoy el Pantano tiene 340 de 2150 puntos sueltos.
- Pasillos de al menos una celda (`NavSpacing`) de ancho libre. Un mueble que tapa medio pasillo puede cortarlo para las criaturas.
- La decoración puede ir con `CanQuery = false`. Suelos, muros y escaleras, no.
- No dejar obstáculos a menos de 6 studs de la salida del ascensor (`SafeZone`): es la zona segura y tiene que ser transitable.

### Escondites

- Un `BasePart` llamado `Escondite` dentro del mueble (taquilla, armario, arbusto): invisible (`Transparency = 1`), sin colisión ni `CanQuery`, del tamaño de un jugador (la taquilla usa 2,6 × 6 × 2). El jugador queda anclado en su centro. En el generador, `common.hide_volume`.
- Atributos: `Kind` = `Locker` o `Bush` (elige la vista desde dentro), `Label` = texto del aviso («Taquilla», «Armario», «Arbusto»).
- **La cara −Z del volumen (`LookVector`) mira hacia fuera** (la puerta de la taquilla, el claro del arbusto): el jugador mira en esa dirección.
- Delante de cada escondite, a menos de 14 studs, debe haber suelo transitable (ahí espera el Acechador).

### Piezas, luces y rendimiento

- **Sin piezas duplicadas** (misma posición y tamaño): hoy hay 764 en el Pantano, 430 en la Mansión (postes de barandilla donde se unen dos tramos), 151 en la Escuela y 14 en el Centro comercial. Deduplicar al generar.
- Evitar solapes parciales visibles entre suelos y muros (parpadeo).
- Presupuesto orientativo por mapa (lo medido hoy y que carga bien): hasta unas 18.000 piezas y unas 460 luces, con sombras solo en las luces que lo necesiten.

## 4. Ambientación

- **No meter `Atmosphere`, `Sky`, `ColorCorrection`, `Bloom` ni cambios de `Lighting` dentro de los mapas.** El ambiente de cada nivel lo aplica `LevelAtmosphere` (cliente) desde `Config.LevelAtmosphere.Profiles.Level_N`, con transición, y lo devuelve al del lobby al salir.
- Las luces (`PointLight`, `SpotLight`, `SurfaceLight`) sí van dentro del mapa.

## 5. Sonido

- Los efectos se buscan por **prefijo de nombre** en `Workspace.sonidos` (lista en `Config.Sfx`, p. ej. `Impacto`). La música, en `Workspace.sonidos.Musica_background`, con los nombres de `Config.Audio.Music.Levels`. No renombrar los existentes.
- Sonidos ambientales de un nivel (goteo, viento, zumbidos): `Sound` dentro de una pieza del propio mapa. Así se cargan y descargan con él.
- Subir audio por Open Cloud (MCP `roblox-opencloud`) y comprobar que el id carga en Studio. Hoy fallan dos ids archivados: `rbxassetid://481217914` y `rbxassetid://481218268`.
- Pendiente: los sonidos `Criatura_*` (hoy suenan sustitutos).

## 6. Ascensor, lobby y criaturas

- Ascensor (`Workspace.Inicial.Elevator`): no renombrar `Gate`, `Door`, `DoorOpen`, `DoorClosed`, `EntryPoint`, `ExitPoint`, `InteriorZone`, `InsidePrompt`, `OutsidePrompt`, `Frame`, `Equipment` (`SellStation`, `ShopStation`), `StatusGauge`, `StatusLight`.
- Lobby: la puerta del ascensor está en la pared norte (`NorthWall_West` + `NorthWall_Lintel`). No tapar el paso del spawn a la puerta.
- Criaturas: plantillas en `ServerStorage.GameAssets.Creatures` con el nombre de `TemplateName` de `Config.Monster.Species`. Imágenes de sprites como `Image`, nunca `Decal`.

## 7. Comprobar un mapa antes de darlo por bueno

1. Importarlo en `Workspace.Maps` (sustituyendo el anterior) y guardar el place.
2. Pedir a Claude la medición, o hacerla en Play (servidor): sacar el mapa de `ServerStorage.MapStorage` a `Workspace.Maps`, `MapNav.Build(map)`, contar el componente conexo mayor de `nav.adj` y las piezas duplicadas. Valores de hoy en [niveles_generados.md](niveles_generados.md), «Pendiente de retocar».
3. Recorrerlo en Play: salir del ascensor andando, subir a cada planta y entrar en un escondite.
