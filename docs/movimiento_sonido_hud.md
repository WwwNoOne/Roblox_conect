# Movimiento, sonido e interfaz en primera persona

Estado: **funcionando y verificado en Play** (2026-11-25). Commits `8317260`, `f0e022f`, `5c8af9b` en `backrooms-cleanup` y `main`.

## Resumen

| Sistema | Script | Parámetros |
| --- | --- | --- |
| Velocidad, sprint, agacharse, aterrizajes | `StarterPlayerScripts/MovementController.client.luau` | `Config.Movement`, `Config.Sprint` |
| Cámara (ojos, balanceo, FOV) | `StarterPlayerScripts/CameraMotion.client.luau` | `Config.FirstPerson`, `Config.Movement` |
| Pasos, respiración, latido, reverberación | `StarterPlayerScripts/FootstepAudio.client.luau` | `Config.Footsteps` |
| Interfaz: vida, estamina, cuota, ranuras | `StarterPlayerScripts/SurvivalHud.client.luau` | `Config.Hud` |
| Estado compartido entre los anteriores | `StarterPlayerScripts/MotionState.luau` | — |
| Escala única de avatar | `ServerScriptService/Services/AvatarService.server.luau` | `Config.Avatar` |
| Estamina y agachado (servidor) | `ServerScriptService/Services/StaminaService.server.luau` | `Config.Sprint` |
| Sonidos por defecto de Roblox anulados | `StarterPlayerScripts/RbxCharacterSounds.client.luau` (vacío) | — |
| Animaciones | `StarterCharacterScripts/Animate2`, `Turning.client.luau` | — |

Retirados: `MovementClient`, `SprintClient` y el panel de datos de `GameHud` (queda solo el reloj y los avisos). Los scripts del pack importado que se sustituyeron (Bobbing Camera, Lean, LandAnim, Crouching) están fuera del proyecto, en `legacy/movement_pack/` del worktree de `main` (sin seguimiento).

## Dueños únicos (no escribir desde otros scripts)

- `Humanoid.WalkSpeed` → `MovementController`.
- `Camera.FieldOfView` y `Humanoid.CameraOffset` → `CameraMotion`.
- Estamina (`Stamina`, `StaminaMax`, `Sprinting`, `Exhausted`) y `Crouching` → `StaminaService` (atributos de jugador).

## Controles

- `Shift` (L3 en mando, botón táctil "Correr"): correr. Solo hacia delante, gasta estamina.
- `C` (B en mando, botón táctil "Agachar"): agacharse, alterna. `Espacio` o correr te levanta.

## Movimiento

- Andar 16, correr 34 (`Config.Sprint.WalkSpeed` / `Speed`), agachado 8. Equilibrio con `Monster.ChaseSpeed` 26: te alcanzan andando, no corriendo.
- Inercia: al arrancar se parte del 45 % y se acelera a 45 studs/s².
- Hacia atrás 75 %, de lado 90 %. Delante/detrás se mide con la **mirada de la cámara** (el cuerpo va por detrás al girar).
- Peso: −4 % por objeto cargado. Agotado: 85 %. Vida < 25 %: 88 %. Caída fuerte (≥ 55 studs/s): frena 0,7 s.
- Sprint predicho en el cliente durante 0,4 s y luego manda el atributo `Sprinting` del servidor.
- La estamina se gasta **en cualquier sitio** (también en el lobby), salvo dentro del Ascensor en partida, escondido o agachado.
- Agachado: no corre, no salta, no se levanta con techo encima, y los enemigos lo oyen a la mitad de distancia (`CrouchHearFactor`, en `MonsterService`). Remoto `SetStance`.

## Cámara

- Ojos 0,18 por encima y 0,32 por delante del centro de la cabeza (`Config.FirstPerson.EyeUp` / `EyeForward`), con la altura de la cabeza en la **pose de reposo** del esqueleto (acepta `Motor6D` y `AnimationConstraint`). Se adelanta hasta 0,6 más con la velocidad para compensar la inclinación de la cabeza al correr.
- **Lección:** no mover `camera.CFrame` de posición a mano. El script de cámara de Roblox recalcula la mirada desde la cámara del cuadro anterior y da saltos de hasta 60°. La posición va por `Humanoid.CameraOffset`, compensando los 0,5 studs que Roblox retrocede la cámara en primera persona.
- Sobre la cámara solo hay giros pequeños (balanceo, inclinación lateral y al girar, aterrizaje, respiración), que se deshacen al empezar cada cuadro (`RenderPriority.First`) para que no se acumulen.
- Orden por cuadro: Roblox (`Camera`) → captura (`+1`) → `CameraMotion` (`+2`) → `CameraFx` / `DescentFx` (`+3`).
- Verificado: en reposo la cámara no se mueve; al correr la inclinación oscila ±0,8° y vuelve.

## Sonido

- Un paso por zancada real (andar 7,5 studs, correr 11, agachado 4); ritmo compartido con el balanceo de la cámara.
- Superficie por rayo bajo los pies: material del Terrain o de la pieza, o el atributo `Superficie` (`Concrete`, `Carpet`, `Metal`, `Wood`, `Water`, `Grass`) en la pieza o su modelo.
- Variantes sin repetir, tono y volumen aleatorios; agachado flojo (alcance 22), corriendo fuerte (alcance 110).
- Pasos de otros jugadores en 3D, apagados si hay pared entre la cámara y ellos.
- Reverberación por tamaño de espacio (solo el grupo `Movimiento`, no la música); la moqueta absorbe.
- Respiración con el esfuerzo y latido con vida < 35 %.
- Los sonidos de Roblox (`rbxasset://sounds/...` en la raíz del personaje) se silencian aunque `RbxCharacterSounds` esté anulado, porque igualmente aparecían.
- IDs verificados en Studio. **Créditos:** pasos de metal de SCP:CB, licencia CC BY-SA 3.0.

## Interfaz

- Vida (abajo izquierda): barra segmentada, rastro blanco del daño, temblor al recibir daño, roja < 30 % con viñeta roja y desaturación. Indicador de linterna.
- Estamina: tira sobre la vida; aparece al gastarla y se oculta llena. Agotado: parpadea en rojo.
- Ranuras (abajo centro, solo en partida): tecla, icono de la hoja de Codex si existe (si no, código de texto), ocupación y penalización de peso.
- Cuota (arriba derecha, solo en partida): nivel, depositado / cuota, fondo, fallos. Verde al cumplir.
- En táctil, vida y estamina suben arriba a la izquierda.

## Avatar

`AvatarService` normaliza todas las escalas R15 al aparecer (altura, anchura, profundidad, cabeza = 1; tipo de cuerpo y proporción = 0) con `ApplyDescription`. Conserva ropa, colores y accesorios.

## Pendiente

- Animaciones propias de agachado y aterrizaje: las del pack (`118794928043357`, `98772997953918`) son de otro creador y Roblox las bloquea. Subir las propias y poner los IDs en `Config.Movement.CrouchIdleAnim`, `CrouchWalkAnim` y `LandAnim`. Sin ellas, al agacharse baja la cámara pero el cuerpo sigue de pie.
- No probado aún: aterrizajes fuertes, pasos de otros jugadores con 2+ clientes, reverberación en mapas reales, diseño táctil.
