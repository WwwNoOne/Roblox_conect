# Roblox Studio y lugares de prueba

## Lugar actual

**Conservar el lugar actual como banco de pruebas.** En Studio, el lugar `137133016631933` contiene el puerto, agua de Terrain, 11 marcadores, `Workspace.OceanWorld.LightTest` y `Workspace.hoja_coral`. Sirve para comprobar importaciones, rig, agua, controles, lámpara y niebla en aislamiento.

- Usar las estaciones de 8, 28 y 62 m para comparar luz. Verificar la visibilidad con lámpara encendida y apagada.
- Usar Hoja Coral para validar escala, textura y animación. El clip está en `ServerStorage.RBX_ANIMSAVES`. Su reproducción publicada depende de un ID de animación que pueda usar el propietario de la experiencia.
- Claude mantiene la configuración de Rojo y el arranque de partidas en su worktree. El GDD define economía en memoria para Abismo.

## Lugar de integración de Abismo

En el lugar actual, los mapas de integración están bajo `Workspace.Maps`, separados del banco de luz. La secuencia acordada es `Level_1 → Parada → Level_2 → Parada → Level_3`. El [plan vigente](docs/superpowers/plans/2026-11-11-abismo.md) registra cómo conectar la lógica de partida.

1. Desde el worktree de Claude, ejecutar `rojo build` y `rojo serve`. Conectar el plugin de Rojo al lugar de pruebas y verificar el lugar seleccionado antes de sincronizar.
2. Mantener el escenario creado en Studio fuera de los contenedores que Rojo controla. Comprobar que los objetos del mapa siguen presentes después de la sincronización.
3. Probar con **Server & Clients** y dos clientes como mínimo. Usar cuatro para validar espacio interior, compuerta y concurrencia.
4. Registrar el lugar, commit, cantidad de clientes, resultado y pasos para reproducir fallos en [arranque.md](arranque.md).

En Linux, el selector de archivos de Studio bajo Wine mostró los archivos del sistema con la ruta `Z:/home/…`. El archivo en el repositorio conserva su ruta de Linux.
