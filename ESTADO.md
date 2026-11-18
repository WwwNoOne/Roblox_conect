# Estado de Abismo y dónde nos quedamos

Actualizado el **2026-11-18** (secciones 0.1 y 0.2; el resto sigue siendo del 15-nov). Es la página de entrada para retomar el trabajo y repartir tareas entre subagentes. Detalle del diseño: [`game_designs/Generacion_Cuevas.md`](game_designs/Generacion_Cuevas.md) · criaturas: [`game_designs/Criaturas.md`](game_designs/Criaturas.md) · histórico: [`docs/historial_implementacion.md`](docs/historial_implementacion.md).

## 0. Giro de diseño (2026-11-15) — leer primero
El mapa pasa de **masivo a laberinto estrecho**, con **enemigo agresivo** y gameplay **más frenético**: salas medianas de 90-120, pasillos más estrechos con formas (**lineal, codo, T, cuádruple**), **zonas para esconderse** y **movimiento más rápido**. El usuario modela pasillos, el enemigo y una sala; después se prueba el gameplay. Detalle y consecuencias para el generador/IA: [`game_designs/Generacion_Cuevas.md`](game_designs/Generacion_Cuevas.md) §0. Tareas nuevas en §5 (**C7-C9**).

## 0.1 Arte con ForgeGUI (2026-11-17)
Registro completo (jobs, ids de Roblox, estado) en [`forgegui-project.json`](forgegui-project.json).
- **Kit de la instalación abandonada** (9 props, tuberías/algas): `ServerStorage.AbismoAssets.Kit_Instalacion`. Las 10 salas de `Workspace.Kit_10_Salas_Vacias_16` tienen un modelo `Decoracion` (356 piezas) generado con [`assets_build/forgegui/decorar_salas.luau`](assets_build/forgegui/decorar_salas.luau) (se puede volver a ejecutar; deja libres los huecos de 16 × 16). Lámparas con etiqueta `LamparaInstalacion` (parpadeo en `FacilityAmbience.client`). **Hecho 2026-11-18:** las 10 salas están en `Workspace.Salas` (con `Conexiones/Cara_*`, marcas a 0,13 de la cara exterior; huecos comprobados con raycast) y en `Config.Maze.Pieces` (`MaxRooms = 3`). Kit v2 de decoración (litera, mesa de laboratorio, generador, armario eléctrico, escotilla, huevos orgánicos) añadido al kit y a `decorar_salas.luau` (ahora apunta a `Workspace.Salas`); las 10 salas ya están re-decoradas con los 15 props. Las provisionales (`Estacion_De_Filtrado_180`, `Estructura_1`) están en `ServerStorage.Respaldo_Salas_Provisionales`. El `Lobby.Model` se movió +6000 en X para que no se solape con la zona generada.
- **5 criaturas nuevas** (`ServerStorage.AbismoAssets.Creatures`: `Anguila_Abisal`, `Rape_Abisal`, `Medusa_Abisal`, `Isopodo_Gigante`, `Tiburon_Duende`), con rugido al detectarte (`Workspace.sonidos.Criaturas_ForgeGUI`). `MonsterService` ahora saca `Config.Monster.PerLevel` especies por nivel de `Config.Monster.Species`. **Animación procedural en el cliente** (ForgeGUI no sube animaciones a Roblox): `CreatureAnimator.client` + `CreatureSegments` cortan la malla en trozos con EditableMesh y la mueven como cadena (perfiles en `Config.CreatureAnim`); si no hay memoria, la mueve en bloque. Las mallas ya son de 5000 triángulos (cambiadas en las 5 plantillas el 2026-11-18; atributo `MallaLigera`) porque el presupuesto de EditableMesh del cliente solo cabía una criatura de 15 000.
- **Panel del submarino** con arte generado (placa, botones, iconos): `Shared/UiArt.luau` + `SubPanelClient`.
- **Pendiente de audio**: ambiente de la instalación, gemidos de tubería y clic del panel quedaron en `outcome_unknown` en ForgeGUI; el código ya los busca por nombre (`Config.Sfx.FacilityAmbience`, `PipeGroan`, `PanelClick`) y no suena nada mientras falten.

## 0.2 Próxima tarea: pase visual (2026-11-18)
Siguiente bloque, **todo visual**: niebla/ambiente por sala (ver C6), más decoración de salas, interfaces (HUD, menús, lobby). Ya hecho: 10 salas en `Workspace.Salas` (tamaño completo en modo maze), 18 props de decoración + 3 estructuras, lobby movido +6000 en X.
- **Pendiente de verificar en Play (con linterna):** que las texturas de los props nuevos carguen (la mesa de laboratorio se vio gris en Edit); salas 09, 06 y 10 son las más cargadas.
- **ForgeGUI:** quedan ~6.700 créditos (un modelo `standard` cuesta ~4.700). Los 3 sonidos fallidos no se reintentan sin decisión del usuario. Registro en `forgegui-project.json`.
- **No verificado:** partida completa con los monstruos y las salas nuevas; `Lobby.Part` en (-648, 145, -331) sin identificar; place sin guardar en Studio; código con diseño viejo (C1, C2, C4 de abajo).

## 0.3 Decoración de salas: pasa a Codex (2026-11-18)
Los modelos de ForgeGUI no encajan con el estilo visual del juego, así que **se retiró la `Decoracion` de las 10 salas** de `Workspace.Salas` (quedan solo las cáscaras, con sus huecos de 16 × 16). Respaldos en `ServerStorage`: `Respaldo_Decoracion_v1` (primera versión aleatoria) y `Respaldo_Decoracion_v2_ForgeGUI` (temas y grupos). **Codex decora las salas**; no volver a ejecutar `assets_build/forgegui/decorar_salas.luau` salvo que se vuelva a usar el kit (`Kit_Instalacion`). Sin la decoración desaparecen también las lámparas `LamparaInstalacion` (la luz de las salas es la del jugador y la niebla). **Codex terminó (2026-11-18):** las 10 salas tienen `Decoracion_Industrial` (la 01 una `Planta_De_Filtrado_01`; 05, 06, 08, 09 y 10 también `Divisiones_Interiores`) y una carpeta `Orientacion` con una guía por cara (`EjeLocal`/`NormalLocal`). Las salas definitivas del bioma inicial viven agrupadas en `Workspace.Salas["Bioma(frabrica)"]` (para añadir más biomas como carpetas hermanas; el generador las busca de forma recursiva por nombre). `MazeGenerator.ReadPiece` lee `Orientacion`: la sala solo gira sobre el eje vertical (nunca de cabeza) y falla con un mensaje claro si Techo no está en +Y y Piso en -Y. Revisado en Studio: guías coherentes con `Conexiones` en las 10, puertas libres (solo un montante fino de 0,28 a 16 studs de la puerta Sur de la sala 04).
- **Sala_0 con agujero de 16 × 16** (medido con rayos): centro (563,6, 14, 36,9) = `SubDock` + (2,6, −8, 72,9); `Config.Level.Sala0Port` ya lo usa, sin marco de pozo. La sala_0 conecta siempre primero con un tramo vertical de pasillo (`Pozo_*`), nunca con una sala.

## 1. Dónde estamos (resumen)
El juego pasó de **3 niveles fijos + paradas** a un **modo infinito de cuevas generadas con salas modulares** (11 salas + sala_0 con el submarino, unidas por pasillos de 140 × 60 × 60, con semilla). Los niveles viejos y el agua de Terrain se **eliminaron** de Studio; se conservaron los assets de decoración, la fauna (peces) y el lobby.

**Hecho y probado en Studio**
- Código de juego base (salas, partidas, economía, tesoros, oxígeno, compuerta, baliza/espectador, natación, lámpara, sonido): ver el historial.
- Enemigos: **cangrejos** en plataformas (3 por partida), **3 mandíbulas radiales** que rondan el mapa, **kraken abisal** (70 studs) con agarre mortal y postura erguida (`KrakenService`/`KrakenClient`). Probados solo en parte; **nada probado con jugadores reales en partida con las salas nuevas**.
- Piezas de mapa modeladas por el usuario (en Studio, **no versionadas**): `Sala_0`, `Pasillo`, sala grande `Salas_grandes.Kraken_map` (con las 6 puertas de 60 × 60 cortadas y verificadas, `Conexiones` añadidas y pivote en el centro) y la primera sala pequeña `Salas_normales.Sala_De_Bombeo_160`.
- **Laberinto:** ahora con **pozos verticales** (`Pasillos_V`) y la sala `Salas.Estructura_1`; enemigo `MonsterService` (Pez Pelícano) que patrulla y corre al detectarte. `MazeGenerator.luau` y `Config.Maze` generan el nivel con las 4 piezas de pasillo modeladas (28 piezas, escondites en cada una); `Config.Level.Mode = "maze"`.
- **`LevelService.server.luau`** (nuevo; aparta `Workspace.Assets`/`Zona_Prueba`/`LeadPipes` a `ServerStorage.Plantillas` al arrancar): genera el nivel al arrancar el servidor y avisa a la pantalla de carga; **el kraken ya ronda solo en su sala grande** (`KrakenService`). Cangrejos y mandíbulas siguen **desactivados** (apuntan a mapas viejos; tarea C4).
- **`RoomGenerator.luau`** (nuevo, versionado): primera versión probada en Studio: nivel de ejemplo con 1 grande + 10 pequeñas + 11 pasillos, sin solapes y con agua (`Workspace.NivelGenerado`).

**Código que apunta aún al diseño viejo** (hay que reemplazarlo): `Config.Run.Stages` (Level_1…Level_3 y Parada), `Runs.luau` (`showOnlyMap`, `moveSubTo`, `carveCabin`, `restoreWater`; `dockOf` ya cae a `Workspace.Sala_0.SubDock`), `OxygenService` (consumo según `InteriorZone`), y los servicios de criaturas (buscan `Workspace.Maps.<Nivel>` y su `Bounds`). Hoy una partida **no puede arrancar** con normalidad.

## 2. Estado de Studio (no versionado: guardar el lugar)
- `Workspace`: `Sala_0` (Folder; incluye `SubDock` en `(561, 22, −36)`), `Pasillo` (Folder → Model con `Port_A`/`Port_B`), `Salas_grandes` (`Kraken_map` y `Plantilla_Sala_grande`), `Zona_Prueba` (suelo de pruebas, 850 × 837), `Kit_Rocas_De_Pared_Con_Algas` (1510 partes), `asset_decorations` (72 elementos), `Lobby` (con el submarino original `Lobby.Model.Submarine`), `Maps.Parada` (vacío), modelos sueltos `Larva_Abisal`, `Hunter`, `Holue(fossil)` y un `Player` de referencia.
- `ServerStorage`: `AbismoAssets` (`Creatures`: Cangrejo, Peces, `Kraken_Abisal`, `Mandibula_Radial`; `Treasures`; `Props`; `_Duplicados`), **`Krakem_tuberias_optimizado`** (tuberías en 378 partes, listas para sustituir a las originales) y **`Sala_kraken_original_respaldo`** (losas originales sin agujeros). `ReplicatedStorage.AmbientFauna`: 6 plantillas de peces.
- El submarino **duplicado** de pruebas (`Workspace.Submarine`) ya fue borrado.

## 3. Operativa
- **Rojo:** `rojo serve default.project.json` en segundo plano; se corta a las 2 h (límite) y hay que **reconectar el plugin** (puerto 34872). Lo reinicia quien lo pida.
- **MCP de Studio:** a veces falla con *"Server's protocol version is not supported"*; se arregla reiniciando la sesión/cliente y volviendo a conectar. `studio_id` cambia al reiniciar Studio (`list_roblox_studios`).
- **Un solo escritor en Studio a la vez.** Varios subagentes pueden editar `src/` en paralelo si tocan archivos distintos.
- Texto de proyecto en **español**; estilo `--!strict` en Luau (ver `Docs/CLAUDE.md`).

## 4. Decisiones abiertas
| Tema | Opciones | Recomendación actual |
| :-- | :-- | :-- |
| Escala del nivel | modelado a escala 1 · `Config.Level.Scale` | **0,6** (2026-11-15: la sala pequeña de 174 se sentía como la grande). Salas definitivas: pequeña ≈ 100³, grande ≈ 170, puertas/pasillo 36 × 36, pasillo 84 |
| Puertas y grosor | 60 × 60, pared de 8 | decidido |
| Kraken | 70 de alto, solo en su sala | decidido |
| Tuberías de la sala grande | original (24 864 partes) · optimizada (378) | usar la optimizada tras comparar |
| Isla del naufragio sobre la puerta de suelo | subirla/bajarla o desplazar la puerta | revisar al modelar |
| Jefes 2-4 | por diseñar | empezar solo con el kraken |

## 5. Tareas para subagentes
Cada tarea es independiente salvo donde se indica. **E1** y **E2** escriben en Studio: no lanzarlas a la vez.

### Código (Luau, en `src/`, versionado)
- **C1 · Runs sin etapas fijas.** Quitar `showOnlyMap`, `moveSubTo`, `carveCabin`, `restoreWater` y las `Config.Run.Stages` de niveles/paradas; colocar el submarino una vez en `Workspace.Sala_0.SubDock` al iniciar; la partida pasa a ser una sucesión de niveles generados (`Descending` ya no mueve el submarino). Mantener `Rooms`/`RunHandlers`/economía funcionando. *Hecho cuando:* una partida arranca, el submarino aparece en el `SubDock`, la economía y la cuota siguen operativas. *Depende de:* nada.
- **C2 · Oxígeno y zonas seguras.** `OxygenService`: gastar aire estando en agua (terreno `Water` o estado de nado) y recargar en seco o en `DryZone`/`InteriorZone`. Un helper común `IsSafe(player)` (submarino o `DryZone`) que usen cangrejo, mandíbula y kraken en vez de `IsUserInside`. *Depende de:* nada.
- **C3 · Generador de salas (`RoomGenerator`) — primera versión hecha y probada en Studio** (ver `Generacion_Cuevas.md` §5.5; faltan bucles extra, biomas, semilla del servidor, ejecución en partida real y un `Tapon` definitivo). Módulo puro y testeable: dada una **semilla** y un catálogo de salas, devuelve el grafo en rejilla (sala_0 arriba, grande a continuación, 10 pequeñas, bucles, ≥ 3 puertas a la grande, ≥ 3 biomas, rotaciones 0/90/180/270), y un instanciador que clona salas y pasillos, los alinea por `Port_*`, pone tapones y rellena agua (`Terrain:FillBlock`). Tests de determinismo por semilla y de las reglas. Estándar de sala: `Generacion_Cuevas.md` §4. *Depende de:* el estándar (ya fijado); para probarlo con arte, de E1.
- **C4 · Criaturas por sala.** Adaptar `CrabService`, `MandibulaService` y `KrakenService` para usar el `Bounds` y los marcadores (`CrabPlatform`, `CreatureSpawn`, `BossSpawn`) de las salas activas; el kraken solo en la sala grande; ninguna criatura entra en la sala_0. *Depende de:* C2 y, para pruebas reales, de C3/E1.
- **C5 · Profundidad, dificultad y ranking.** Contador de profundidad por nivel generado, escalado de dificultad (cuota, número de criaturas) y ranking (`OrderedDataStore`) opcional. *Depende de:* C1.
- **C6 · Clima/Niebla por bioma.** `BiomeZone` (atributos) → el cliente ajusta niebla/color/luz al entrar a cada sala. `UnderwaterFog.client` ya lee el agua del Terrain. *Depende de:* el estándar de sala.

- **C7 · Generador con piezas de pasillo — primera versión hecha y probada** (`MazeGenerator.luau` + modo `maze` de `LevelService`, ver `Generacion_Cuevas.md` §0; faltan: integrar salas con puertas de 20 × 20, piezas verticales, rotación de piezas en 3D más allá del primer tramo). Evolucionar `RoomGenerator` para que salas **y** tramos (lineal, codo, T, cruce) sean piezas con 2-4 puertos unidas puerto con puerto sobre una rejilla modular; cerrar bucles cuando los puertos alinean; tapar puertos sin usar; devolver el grafo de piezas (lo usa la IA). Mantener `Plan`/`Validate`/`Build` y las pruebas de semilla. *Depende de:* medidas de las piezas que modele el usuario.
- **C8 · Enemigo agresivo con navegación por grafo — primera versión hecha** (`MonsterService`, Pez Pelícano Abisal; ver `Generacion_Cuevas.md` §0). Pendiente: colisión/esquinas, publicar animaciones, más de un enemigo, ajustar velocidades y daño tras jugar.
- *(texto original de C8)* Servicio nuevo para el modelo del usuario: persigue por el laberinto con BFS entre piezas + waypoints en los puertos, detección por vista/luz/ruido, ignora a quien está en un `Escondite` salvo muy cerca, agarre/muerte a definir. Reutiliza `Config.Kraken` como plantilla de parámetros y `KrakenService` como referencia. *Depende de:* el modelo y animaciones del enemigo; C7 para el grafo.
- **C9 · Escondites y ritmo — escondites hechos** (E en la caja industrial, `Hiding.luau`; ver `Generacion_Cuevas.md` §0). Falta: velocidad de nado/dash y ritmo, y ajustar la detección del enemigo nuevo (muy cerca / lámpara).
- *(texto original de C9)* Marcador `Escondite` (volumen) y estado "oculto" del jugador; subir la velocidad de nado/dash (`Config.Swim`, `Config.Dash`) y calibrar con el enemigo; ritmo más frenético (el enemigo aparece pronto, menos tiempo muerto). *Depende de:* C8 para probar.

### Studio (un agente a la vez; guardar el lugar al terminar)
- **E1 · Terminar la sala grande del kraken.** Sustituir `Krakem tuberias` por `Krakem_tuberias_optimizado`; mover fuera el kit de tuberías suelto; crear `Port_X±/Y±/Z±` (60 × 60 × 8, hacia fuera), `Bounds`, `BossSpawn`, marcadores y `BiomeZone`; poner el pivote en el centro de la caja; resolver la isla sobre la puerta de suelo; modelar el prefab `Tapon`; comprobar presupuesto (< 2500 partes). Replicar los agujeros en `Plantilla_Sala_grande` con la técnica de 4 bloques.
- **E2 · Terminar sala_0 y pasillo.** Sala_0: `DryZone`, `Bounds`, `Pool`/puerta del pozo, ajustar hueco del muro (23,2 → ≥ 28), suelo bajo el pasillo de 60 × 60, escalón desde el submarino. Pasillo: `Bounds` 60 × 60 × 140 y variante sin decoración de suelo para el uso vertical.

### Arte (usuario / Codex)
- **A0 · (usuario) Pasillos modulares** lineal, codo, T y cruce con `Conexiones` (estándar `Cara_*`), un **enemigo agresivo** (modelo + animaciones) y **una sala mediana (90-120)**; con eso se prueba el gameplay nuevo.
- **A1 · Kit de roca** reutilizable (pared, cuña de esquina, estalactitas, marco de puerta).
- **A2 · Salas pequeñas:** 12 = 4 biomas × 3 variantes (empezar con 1 bioma × 2 variantes).
- **A3 · Jefes 2-4 y sus salas grandes.**

### Documentación y calidad
- **D1 · Pruebas con 2 y 4 clientes** (Server & Clients) y registro en `docs/historial_implementacion.md`. Pendiente desde T01–T07.
- **D2 · Revisión de presupuesto** (partes/luces por sala) y de rendimiento con el nivel completo generado.

## 6. Orden sugerido
1. En paralelo: **C1**, **C2**, **C3** (módulo puro) y **E1** (Studio).
2. Luego: **C4** y **C6** con la sala grande real; **E2**.
3. Probar el nivel mínimo (sala_0 + pasillo + grande + 1-2 pequeñas) con un cliente; después con 2 y 4.
4. Después: **A1**/**A2** (arte), **C5** y los jefes.
