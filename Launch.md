# Roblox Studio y lugares de prueba

## Lugar actual

**Conservar el lugar actual como banco de pruebas.** En Studio, el lugar `137133016631933` contiene el puerto, agua de Terrain, 11 marcadores, `Workspace.OceanWorld.LightTest` y `Workspace.hoja_coral`. Sirve para comprobar importaciones, rig, agua, controles, lámpara y niebla en aislamiento.

- Usar las estaciones de 8, 28 y 62 m para comparar luz. Verificar la visibilidad con lámpara encendida y apagada.
- Usar Hoja Coral para validar escala, textura y animación. El clip está en `ServerStorage.RBX_ANIMSAVES`. Su reproducción publicada depende de un ID de animación que pueda usar el propietario de la experiencia.
- El lugar aún contiene scripts del prototipo anterior. Claude prepara una configuración de prueba sin escrituras persistentes para los nuevos ensayos.

## Lugar de integración de Abismo

Trabajar sobre **una copia de pruebas separada** cuando estén listos el interior del submarino y el inicio de partida. Llevar a esa copia el agua, la iluminación y los marcadores que se necesiten. Añadir el lobby provisional, el submarino, las zonas por paradas y el fondo de la baliza según el [plan vigente](docs/superpowers/plans/2026-11-11-abismo.md).

1. Desde el worktree de Claude, ejecutar `rojo build` y `rojo serve`. Conectar el plugin de Rojo a la copia de pruebas y verificar el lugar seleccionado antes de sincronizar.
2. Mantener el escenario creado en Studio fuera de los contenedores que Rojo controla. Comprobar que los objetos del mapa siguen presentes después de la sincronización.
3. Probar con **Server & Clients** y dos clientes como mínimo. Usar cuatro para validar espacio interior, compuerta y concurrencia.
4. Registrar el lugar, commit, cantidad de clientes, resultado y pasos para reproducir fallos en [arranque.md](arranque.md).

En Linux, el selector de archivos de Studio bajo Wine mostró los archivos del sistema con la ruta `Z:/home/…`. El archivo en el repositorio conserva su ruta de Linux.
