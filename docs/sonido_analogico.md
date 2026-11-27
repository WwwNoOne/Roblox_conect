# Audio analógico y pistas de generadores — 26/11/2026

Implementado por Codex con excepción expresa del usuario para los scripts cliente de audio e indicador. No se alteran servidor, economía, cuotas, tiempos ni estados autoritativos.

## Mezcla

- Se preservan los 24 sonidos originales del usuario. Se añaden 15 aliases compatibles con `Config.Sfx`, cuatro camas musicales y una capa de persecución.
- Exploración: música base del usuario a volumen 0,22 × MixGain 0,7 × grupo 0,8; lobby aún más suave. Persecución: `musica_accion_frenetica`, ataque de 0,35 s, cama reducida al 18 %. Una sola instancia de persecución; salida suavizada y margen de 2,5 s al perder amenaza.
- La música considera estado y objetivo de criaturas. Las criaturas sin objetivo replicado requieren visibilidad y distancia ≤55 studs; las que tienen objetivo deben apuntar al jugador local y estar a ≤95. Ascensor, escondite, muerte y salida de partida suprimen persecución.
- Generadores averiados: indicador ámbar a ≤42 studs, sin atravesar paredes, atenuación al alejarse. Chispas espaciales a ≤55 studs sincronizadas con las ráfagas existentes (3–9 s). Reparado: sin indicador ni chispas de guía. Se conserva el sonido autoritativo de fallo y motor.
- Cuatro emisores ambientales discretos por mapa, dentro de `Level_N.AnalogAmbience`: industria, insectos, ventilación y estática. Sin colisión ni consultas físicas.

## Reproducir la entrega

Ejecutar `tools/audio/install.luau` en modo Edit después de importar los seis mapas. Es idempotente para los elementos propios de esta entrega; no renombra ni elimina los originales. Importar/regenerar mapas borra sus emisores: volver a ejecutar el instalador.

`assets_build/exports/Audio_Analogico.rbxmx` contiene el banco y sus grupos como respaldo; no sustituir toda la carpeta `sonidos` con él. Para instalación completa preferir el instalador, que conserva originales, coloca grupos en SoundService y añade ambientes a los mapas. Los scripts cliente se sirven con Rojo. En esta sesión Rojo no reflejó los cambios: se sincronizaron explícitamente por MCP/HTTP local y se verificaron en Play.

## Fuentes y mediciones

Los sonidos de criaturas, ascensor y música reutilizan el material aportado por el usuario. Fuentes nuevas de Creator Store:

| Asset | Uso | Duración medida |
|---|---|---:|
| [9116279339](https://create.roblox.com/store/asset/9116279339) | Descarga eléctrica, Pro Sound Effects; también usado por el generador existente | 0,718 s |
| [9112796599](https://create.roblox.com/store/asset/9112796599) | Ambiente industrial, Pro Sound Effects | 36,010 s |
| [9112810051](https://create.roblox.com/store/asset/9112810051) | Insectos, Pro Sound Effects | 56,010 s |
| [9125446564](https://create.roblox.com/store/asset/9125446564) | Ventilación, Pro Sound Effects | 34,624 s |
| [4860560167](https://create.roblox.com/store/asset/4860560167) | Estática de radio, Im_ISTP | 36,519 s |

Selección por descripción y comprobación técnica; no hubo escucha humana ni medición de sonoridad. La mezcla es una primera pasada ajustable.

## Verificación

- Lune: 15 aserciones de política (seguridad, distancia, visibilidad, objetivo, reparación).
- Sintaxis de los tres scripts cliente correcta; `rojo build` correcto.
- Studio: 44 sonidos del banco total cargados, duración positiva; 24 emisores ambientales cargados.
- Play: marcador cercano visible, lejano oculto, oculto tras reparación; se registró una reproducción de chispa y su parada al reparar. Amenaza dirigida activa música (volumen observado 0,229 durante ataque), esconderse la detiene; una única instancia de persecución.
- Avisos ajenos: sonidos archivados 481217914/481218268 en `ServerStorage._Compras_Revisar.Realistic Walk Sounds`, sin tocar. También aviso antiguo de asset 203785492 de tipo incompatible, sin instancia Sound persistente localizada. No se atribuyen a este banco.
