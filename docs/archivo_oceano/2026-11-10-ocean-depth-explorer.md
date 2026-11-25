# Plan histórico de Ocean Depth Explorer

> Este plan describe el prototipo anterior. El trabajo activo se sigue en el [plan de Abismo](2026-11-11-abismo.md).

> Claude Code dirige la implementación. Cuando se apruebe el diseño, asigna un ID por subagente y revisa su entrega antes de integrar tareas dependientes. Si está disponible, usa `superpowers:subagent-driven-development` para la ejecución.

**Objetivo.** Entregar primero una expedición completa y jugable en solitario. El jugador sale del puerto, bucea hasta un punto fijo, recoge botín, regresa, lo vende y compra una mejora que cambia su siguiente inmersión. Después, completar el alcance aprobado del MVP.

**Arquitectura propuesta.** Rojo sincroniza el código desde `src/`. El servidor gobierna supervivencia, economía, criaturas, recuperación y persistencia. El cliente gestiona controles, presentación y HUD. El mapa y los modelos se integran mediante IDs estables que Claude especifica para Codex.

**Tecnología y especificación.** Roblox Studio, Luau y Rojo. Leer el [GDD v1.3](../../../game_designs/archive/ocean-depth-explorer-v1.3.md), [AGENTS.md](../../../AGENTS.md), [guía de Claude](../../../Docs/CLAUDE.md), [guía de Codex](../../../Docs/CODEX.md) y [arranque](../../../arranque.md).

## Estado verificado

- MCP desde esta sesión de Codex detectó `Place1`, devolvió el estado `Edit` y leyó `Workspace`, `ServerScriptService` y `ReplicatedStorage`. El árbol consultado muestra la plantilla base y esos dos servicios sin hijos. La verificación fue de lectura.
- El repositorio todavía carece de `src/` y `default.project.json`. `rojo` no apareció en el `PATH` de esta sesión. El cliente MCP de Claude Code y la sincronización de Rojo se validarán en P01.
- `game_designs/assets/model_design.md` y `game_designs/assets/ui_design.md` están vacíos. `arranque.md` menciona el HUD y un submarino. La primera entrega propuesta es el HUD de buceo a pie con un mapa provisional, para que su validación sea independiente de la malla del submarino.

## Aprobación de diseño

El GDD §18 pide revisión del alcance antes de programar o crear modelos definitivos. Los encargos D01–D03 producen propuestas revisables. D04 reúne las decisiones del creador. Los valores marcados **PROPUESTO** y los asuntos **PENDIENTES** del GDD requieren esa revisión. El tanque básico de 360 s sí está confirmado.

| ID | Depende de | Encargo y criterio de entrega |
| --- | --- | --- |
| D01 | GDD §§3–4, 7–8, 10, 13, 15 | Especificar nivel de mar, conversión studs/m, velocidad, ruta y tiempos de ida/vuelta. Proponer números de oxígeno, presión, daño, incapacitación, batería, consumo y recarga. Anexar controles PC/móvil y reglas de hora/clima por servidor. Entregar una tabla de casos límite y un recorrido calculado contra los 360 s. |
| D02a | GDD §§6, 8, 11–12, 16 | Proponer catálogo, seis peces, tres depredadores y leviatán de borde. Entregar tablas de regiones, apariciones, conductas, recompensas, capacidades, precios, recetas y planos, junto con una decisión sobre `Stage`. |
| D02b | GDD §§9–10, 13–14 | Proponer reglas de grupos, pertenencias y alcance entre servidores. Resolver destino de recuperaciones de terceros, contenedores inaccesibles, registro inactivo y persistencia de vehículos. Entregar una tabla con el resultado esperado para cada desconexión o recuperación. |
| D03a | GDD §§2–4, 13, 16 | Claude prepara `creation_models.md` con IDs, pivotes, escala, colisiones, anclajes y rutas de integración. Usa `game_designs/assets/model_design.md` como referencia visual. Define marcadores de puerto, superficie, arrecife, naufragio, apariciones y borde. Entregar prioridades y distinguir assets provisionales y definitivos. |
| D03b | GDD §§14–16 | Completar el encargo de wireframes en `game_designs/assets/ui_design.md`. Entregar vistas de HUD de buceo y submarino, inventario, mapa, taller e intercambio con estados de advertencia y variantes PC/móvil. |
| D04 | D01–D03 | Claude presenta una propuesta de alcance para aprobación del creador. La aprobación debe distinguir el primer corte jugable del MVP, confirmar los valores y políticas necesarios para cada uno y registrar qué se difiere. Mantener el desarrollo del sistema correspondiente pendiente si su regla de diseño sigue abierta. |

Para preparar D01–D03 en paralelo, cada subagente devuelve su propuesta por separado. Claude reconcilia nombres y decisiones cruzadas en D04, especialmente coordenadas, economía, pertenencias y grupos.

## Contratos para repartir el trabajo

Estos nombres y rutas son propuestas de implementación. Claude los fija en P01 y los incluye en el encargo de cada subagente. Los archivos indicados en las tareas son nuevos.

| Ruta | Destino y responsabilidad |
| --- | --- |
| `default.project.json` | Mapea `src/shared/` a `ReplicatedStorage.OceanDepth`, `src/server/` a `ServerScriptService.OceanDepth` y `src/client/` a `StarterPlayer.StarterPlayerScripts.OceanDepth`. La integración comprueba la conservación de instancias de Studio fuera de esos espacios. |
| `src/shared/Contracts.luau` | Tipos compartidos y nombres de canales. Identificadores de ítem, plano, región, aparición y modelo como cadenas estables. Coordenadas físicas en studs y profundidad derivada en metros. |
| `src/server/Bootstrap.server.luau` | Inicio y orden de dependencias. Claude integra aquí los módulos de los subagentes. |
| `src/client/Bootstrap.client.luau` | Inicio de controles, HUD y menús. Claude integra aquí los módulos de los subagentes. |
| `Workspace.OceanWorld` | Propuesta de raíz artística. Claude acuerda en `creation_models.md` los IDs y atributos de cada marcador; Codex entrega el mapa y las mallas. |

- `DiveSnapshot` lleva `oxygenSeconds`, `oxygenMaxSeconds`, `depthMeters`, `health`, `pressureWarning` y, cuando exista, `batteryPercent`. P05b consume el contrato de P03–P04. P14a extiende la telemetría para el HUD a pie.
- `ActionRequest` lleva acción, objetivo, cantidad cuando aplique e ID de operación. Los manejadores resuelven al jugador a partir de la conexión y verifican tipo, rango, distancia, disponibilidad y propiedad. El servidor calcula precios, daño, botín y elegibilidad. Máximo **20 Hz por cliente**, con límites específicos para acciones costosas. [Seguridad del límite cliente-servidor](https://create.roblox.com/docs/scripting/security/client-server-boundary).
- `InventoryService` concentra cambios de pertenencias y moneda. `ProfileService` expone una mutación serializada por jugador con ID de operación y confirmación durable para operaciones críticas. La captura, venta, muerte y recuperación comparten esa ruta cuando la persistencia esté integrada. `--!strict` en todos los ModuleScripts, PascalCase en servicios y módulos, camelCase en funciones locales.
- El perfil versiona y guarda únicamente datos serializables. Para DataStore, medir los bytes del JSON, aplicar un margen conservador por debajo del límite de **4 194 304 por clave** y respetar los presupuestos de solicitudes y caudal. El límite de datos por clave y el caudal de escritura por minuto son medidas distintas. Las pruebas locales empiezan con almacenamiento en memoria y las de DataStore real usan una experiencia de prueba separada. [Límites de DataStore](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) y [guía de DataStore](https://create.roblox.com/docs/cloud-services/data-stores).

## A. Primer corte jugable

| ID | Depende de | Archivo y encargo | Criterio de aceptación |
| --- | --- | --- | --- |
| P01 | D04 | `default.project.json`, los dos `Bootstrap` y `Contracts.luau`. Fijar versión de Rojo, árbol, contratos compartidos y lugar de pruebas. Verificar la conexión de Claude por separado. | `rojo build -o /tmp/ocean-depth-explorer.rbxlx` termina con código 0. Con `rojo serve` y el plugin conectado al lugar de pruebas, los módulos aparecen en sus servicios y las instancias externas sobreviven a la sincronización. Claude lee ese lugar por MCP. [Flujo de Rojo](https://rojo.space/docs/v7/getting-started/new-game/) y [formato de proyecto](https://rojo.space/docs/v7/project-format/). |
| P02 | P01, D03a | `src/server/WorldRegistry.luau`. Validar el contrato de marcadores del bloque gris de Codex. Resolver puerto, plano de superficie, ruta y punto de botín por ID. | Aparecer en puerto y alcanzar el punto de botín. El arranque identifica marcadores ausentes o IDs duplicados sin registrar una ruta inválida. |
| P03 | P02 | `src/server/DiveService.luau`. Calcular profundidad con el nivel de mar y actualizar oxígeno, inmersión y reposición desde el servidor. | Un tanque básico comienza con 360 s. La inmersión consume, cruzar la superficie recupera según la regla aprobada y el tiempo permanece entre 0 y su capacidad. Probar olas o cruce repetido de la superficie sin regeneración indebida. |
| P04 | P03 | `src/server/SurvivalService.luau`. Aplicar presión y asfixia, clasificar la causa de muerte y controlar una transición única al respawn. Exponer el punto de integración para incapacitación y pertenencias en P11/P13. | Verificar los límites aprobados de presión y oxígeno. Con daños simultáneos, la muerte se resuelve una vez. Reaparecer con kit básico y estado limpio en la isla. |
| P05a | P02, D01 | `src/client/DiveControls.luau`. Exponer ascenso y descenso en teclado y táctil. | El jugador completa la ruta en PC y emulación táctil. Cambiar el tipo de entrada o reaparecer libera las acciones que estaban pulsadas. |
| P05b | P03, P04, D03b | `src/client/DiveHud.luau`. Mostrar oxígeno, profundidad, salud y aviso de presión. Reservar el campo de batería para P14a. | El HUD refleja datos del servidor, se reinicia al respawn y los avisos son distinguibles por texto o icono en ambas plataformas. |
| P06 | P01, D02a | `src/shared/ItemCatalog.luau` y `src/server/InventoryService.luau`. Catálogo del corte, mochila, depósito seguro y movimientos en memoria. Definir capacidad, apilamiento y transacciones con resultado explícito. | Mochila llena y cantidades inválidas se rechazan sin perder ítems. Mover un ítem al depósito solo sucede en el punto válido del puerto. |
| P07 | P02, P06 | `src/server/LootService.luau`. Registrar una aparición fija y conceder botín con una reclamación validada por servidor. | Dos clientes intentan capturar el mismo botín a la vez; uno solo lo obtiene. Mochila llena, distancia inválida y reenvío no conceden ítems adicionales. |
| P08 | P03, P06 | `src/server/PortEconomyService.luau` y `src/client/PortHud.luau`. Implementar venta de un botín y compra/equipamiento de una mejora básica en el puerto. La vista lista botín disponible y saldo del servidor. | La venta modifica botín y Coins juntos. Una compra sin saldo o un reintento no producen saldo negativo ni doble entrega. La mejora equipada se refleja en la siguiente inmersión. |
| V01 | P04–P08 | Claude integra el primer corte en el lugar de pruebas. | Completar puerto → inmersión → botín → regreso → venta → mejora → nueva inmersión en solitario. Repetir con dos clientes para validar el botín y en modo táctil para validar el HUD y controles. El corte conserva el progreso durante la sesión; P09 incorpora el guardado. [Modos de prueba de Studio](https://create.roblox.com/docs/studio/testing-modes). |

## B. Persistencia y riesgo de expedición

| ID | Depende de | Archivo y encargo | Criterio de aceptación |
| --- | --- | --- | --- |
| P09a | P06, P08 | `src/server/ProfileSchema.luau`. Versionar el perfil, definir valores iniciales y migraciones y medir su tamaño serializado. | Una versión previa válida migra sin perder campos compatibles. Un perfil inválido o demasiado grande produce un error explícito antes de intentar escribir. |
| P09 | P09a | `src/server/ProfileService.luau`. Conectar inventario y Coins al almacenamiento. Gestionar reintentos acotados, sesiones concurrentes y cierres. | Un perfil vuelve al reconectar. Un error de carga nunca inicia una escritura con valores por defecto. Guardado ambiguo o sesión duplicada conservan los datos y producen un estado comprobable. |
| P10 | P09, D02b | `src/server/ExpeditionService.luau`. Mantener miembros y permisos en servidor y exponer la lista válida al morir. | Expedición de un jugador funciona. Un tercero no puede incorporarse mediante un ID falsificado. Los cambios posteriores de grupo no alteran los permisos ya registrados en un contenedor. |
| P11 | P04, P09, P10 | `src/server/DeathCacheService.luau`. Mover mochila a un registro persistente de muerte, con dueño, IDs autorizados y posición exacta, incluida profundidad. Implementar materialización y política de archivo aprobada. | Muerte y reconexión conservan una sola copia recuperable. El contenedor existe únicamente tras confirmar el movimiento durable. Un fallo de escritura conserva la mochila y mantiene pendiente la transición. Las pertenencias aseguradas, el mapa, el nivel y los planos se conservan. |
| P12 | P11 | `src/server/RecoveryService.luau`. Validar distancia, autorización y destino. Aplicar la política de recuperación inaccesible y destino de bienes de terceros de D04. | Dueño y aliado autorizado pueden recuperar. Extraño, doble reclamación, desconexión y fallo tras confirmar la operación no duplican ni pierden bienes. Si el destino no puede recibirlos, el registro sigue recuperable. |
| P13 | P06, P11 | `src/server/RescueService.luau`. Añadir incapacitación, estabilización y exclusiones según el diseño aprobado. | Probar rescate válido, interrupción, vencimiento y causas terminales. Expirar o morir deriva al flujo de muerte una sola vez. |

## C. Sistemas del MVP sujetos al alcance aprobado

| ID | Depende de | Archivo y encargo | Criterio de aceptación |
| --- | --- | --- | --- |
| P14a | P05b, D01 | `src/server/EquipmentService.luau` y `src/client/ToolControls.luau`. Agregar linterna, consumo, recarga y batería en el HUD. | Batería agotada apaga la linterna. El HUD muestra batería y los controles funcionan en PC y táctil. |
| P14b | P05a, P14a | `src/server/PropulsionService.luau` y `src/client/PropulsionControls.luau`. Integrar propulsor con movimiento, batería y señal de ruido. | El propulsor se desactiva al agotar batería y no aporta aire ni protección de presión. La señal de ruido se expone a la fauna cuando esté habilitada. |
| P15 | P02, P07, P05a | `src/server/FaunaSpawns.luau`, `src/server/FishingService.luau` y `src/client/FishingControls.luau`. Integrar peces por región, reaparición fija y captura con arpón. | Las especies aprobadas aparecen en sus zonas. Un arpón fuera de rango no captura y cada ejemplar se reclama una vez, incluida la ventana de reaparición. |
| P16 | P02, P04, P14a | `src/server/PredatorService.luau`. Añadir detección, búsqueda, persecución y retirada para depredadores menores y de emboscada. Enlazar daño y señales de alerta. | Perder contacto activa búsqueda local sin rastreo omnisciente. Una criatura distante deja de simularse con el costo de una activa. Probar señales visuales y sonoras. |
| P17 | P02, P16 | `src/server/VoidBoundaryService.luau`. Integrar patrulla y advertencias del leviatán en el borde del mapa. | El jugador puede entrar bajo riesgo, recibe señales previas y el leviatán permanece ligado al territorio. El progreso del corte no exige entrar al Vacío. |
| P18 | P02, P04, P08, P09 | `src/server/CraftingService.luau` y `src/client/WorkshopHud.luau`. Hallar planos, conservar su descubrimiento y fabricar trajes o mejoras con Coins y recursos regionales. | El plano se obtiene explorando. La receta consume insumos y concede el equipo una sola vez. El traje cambia la tolerancia a presión y la entrada a zonas carece de barrera por `Stage`. |
| P19 | P09, P14a, P18, D03a | `src/server/VehicleService.luau` y `src/client/VehicleHud.luau`. Integrar el minisubmarino operativo, control, ocupación, profundidad, casco, aire de cabina y carga. | La cabina y el tanque personal tienen valores independientes. Una profundidad que excede el límite afecta al casco según el diseño aprobado. Dos clientes no toman el mismo asiento. |
| P20 | P09, P19 | `src/server/VehicleRecoveryService.luau`. Persistir estado averiado, ubicación y carga. Gestionar recuperación y reparación con costo según D04. | La carga sigue asociada al vehículo al averiarse y reconectar. Recuperación, reparación y cargos se aplican una sola vez aunque haya reintentos. |
| P21 | P09, P10, P11 | `src/server/NavigationService.luau` y `src/client/MapHud.luau`. Revelar mapa personal, manejar balizas manuales y compartidas y mostrar marcador exacto de recuperación. | Compartir una baliza no revela geografía ni planos. Visitar la región sí actualiza el mapa personal. Los marcadores de muerte usan la ubicación persistida. |
| P22 | P02, D01 | `src/server/EnvironmentService.luau` y `src/client/DepthLighting.luau`. Integrar reloj, lluvia ocasional y atenuación visual y sonora por profundidad. | Dos clientes del mismo servidor ven la fase acordada. El ciclo es visible en la superficie y las profundidades permanecen oscuras. La coordinación entre servidores sigue la regla aprobada. |
| P23 | P06, P08, P09 | `src/server/TradeService.luau` y `src/client/TradeHud.luau`. Limitar el comercio a los bienes elegibles en colonia. Diseñar y probar una operación recuperable entre dos perfiles antes de habilitarla. | Una oferta editada exige reconfirmar. La desconexión entre escrituras y el reintento dejan a ambas partes con el resultado acordado o revierten la reserva sin duplicación. |
| P24 | P02, P09, P21 | `src/server/DiscoveryService.luau` y `src/client/JournalHud.luau`. Registrar el misterio opcional aprobado con marcadores físicos acordados con Codex. | Se puede completar el bucle principal sin consultar el misterio. Las pistas descubiertas quedan registradas y se conservan tras reconectar. |
| P25 | P06, P09, D03b | `src/client/InventoryHud.luau`. Mostrar mochila y almacén del puerto, con cantidades, capacidad y confirmación de movimientos. | El cliente refleja el estado tras una respuesta del servidor. Con destino lleno, el ítem permanece en origen y la interfaz explica el rechazo. |
| V02 | V01, P09–P25 según D04 | Claude integra el alcance firmado y registra evidencia por ID. | Probar solitario, dos clientes y el tamaño de grupo aprobado. Cubrir regreso con botín, muerte/recuperación, reconexión, transacciones, fauna, luz, límite del mapa y rendimiento táctil. Registrar lugar de pruebas, versión, resultados, errores y decisiones diferidas. |

## Asignación, revisión e integración

1. Con D04 aprobado, asignar P01 a un solo responsable. Después, P02 y P06 pueden avanzar en paralelo. Con P02 y P06 integrados, P03 y P07 también pueden avanzar en paralelo. P08 usa el contrato de P03 y P05b usa el de P04.
2. Tras V01, los módulos sin dependencias mutuas pueden repartirse por archivos. P09a puede avanzar junto a P14a y P22 si sus dependencias están listas. Mantener en secuencia P09a → P09 → P10 → P11 → P12 y P19 → P20. Claude integra los dos `Bootstrap`, `Contracts` y el esquema de perfil en una sola cola.
3. Un subagente recibe su ID, requisitos del GDD, contratos, archivos que puede tocar y prueba de aceptación. Primero reproduce el caso de aceptación o prepara el fixture. Luego implementa, ejecuta `rojo build -o "$ocean_build_dir/ocean-depth-explorer.rbxlx"` con un directorio temporal propio creado con `mktemp -d`, valida el caso en Studio y devuelve archivos, evidencia y bloqueos. Una instancia de Studio compartida se reserva para una prueba a la vez.
4. Claude revisa e integra cada entrega. Verificar especialmente `NaN` o cantidades inválidas en remotos (P06–P08), muertes dobles (P04/P11), guardados fallidos sin sobrescribir un perfil (P09), reclamaciones simultáneas (P07/P12), reintentos tras escrituras parciales (P20/P23) y retorno desde el modo táctil o el respawn (P05a/P05b). Las pruebas con DataStore real requieren la experiencia separada indicada arriba.
5. Tras D03a y D04, Codex prepara el bloque gris del primer corte, luego los modelos y el mapa aprobados. Entrega los IDs del manifiesto, archivos `.fbx` o `.blend`, escala, pivote y colisiones. La ruta `assets_build/exports/submarine.fbx` de `arranque.md` corresponde a P19. Claude enlaza las MeshParts en el lugar de pruebas y verifica el contrato antes de habilitar su uso.

## Mensaje inicial para Claude Code

> Lee `AGENTS.md`, `Docs/CLAUDE.md`, `game_designs/GDD.md` y `docs/superpowers/plans/2026-11-10-ocean-depth-explorer.md`. Empieza con D01–D03 y reúne las decisiones en D04 para revisión del creador. Conserva los valores confirmados del GDD y etiqueta tus propuestas. Tras la aprobación, valida tu conexión MCP y Rojo en P01. Luego asigna un ID por subagente y prioriza V01. Para Codex, prepara `creation_models.md` con los IDs y requisitos del bloque gris y de cada malla aprobada.
