# Roblox Studio y lugares de prueba

> El banco de pruebas oceánico (puerto, agua de Terrain, marcadores `Marker_*`, `LightTest`, `hoja_coral`, `Workspace.Maps` con niveles submarinos) **quedó obsoleto el 2026-11-25**. Antes de integrar, limpiar el lugar `137133016631933` en Studio: eliminar agua de Terrain, `Workspace.OceanWorld`, `Workspace.Markers`, `Workspace.hoja_coral` y los mapas submarinos de `Workspace.Maps`.

## Lugar de integración

1. Desde el worktree `Roblox_conect-backrooms` (rama `backrooms-cleanup`), ejecutar `rojo build` y `rojo serve`. Conectar el plugin de Rojo y verificar el lugar seleccionado antes de sincronizar.
2. Mantener el escenario creado en Studio fuera de los contenedores que Rojo controla.
3. En el lugar hay que renombrar: modelo `Submarine`→`Elevator` (`Hull`→`Body`, `Hatch`→`Gate`, `HullGauge`→`StatusGauge`, quitar `RepairStation`), `SubDock`→`ElevatorDock`, `ServerStorage.AbismoAssets`→`GameAssets`. Eliminar `Workspace.sonidos` oceánicos que ya no se usen.
3. Los mapas viven bajo `Workspace.Maps` (`Level_N`, `Parada`) con los nombres de [creation_models.md](creation_models.md). **[POR DEFINIR]** cuando existan los nuevos niveles.
4. Probar con **Server & Clients** y dos clientes como mínimo; cuatro para validar espacio interior, puerta y concurrencia.
5. Registrar lugar, commit, cantidad de clientes, resultado y pasos para reproducir fallos en [arranque.md](arranque.md).

En Linux, el selector de archivos de Studio bajo Wine muestra rutas `Z:/home/…`.

## Plugin de Rojo en Linux (instalado y verificado 2026-11-25)

`rojo plugin install` **no funciona en Linux** (`Your platform is not currently supported`): solo conoce las rutas de Windows y macOS. El plugin se copia a mano en:

```
~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/miranda/AppData/Local/Roblox/Plugins/Rojo.rbxm
```

Instalado **Rojo 7.7.1**, la misma versión que el CLI de `/home/miranda/.rokit/bin/rojo`. Plugin y CLI deben coincidir; para actualizar:

```sh
curl -sSL -o /tmp/Rojo.rbxm https://github.com/rojo-rbx/rojo/releases/download/v<X.Y.Z>/Rojo.rbxm
cp /tmp/Rojo.rbxm ~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/miranda/AppData/Local/Roblox/Plugins/Rojo.rbxm
```

### Trampa: Wine tiene dos `%LOCALAPPDATA%`

En este equipo `Local AppData` está redirigido en el registro a `…/data/vinegar/appdata`, y ahí van los logs, `OTAPlugins`, `mcp.bat` y `LocalStorage`. Pero los datos de plugins por usuario (`Roblox/<userId>/InstalledPlugins`, `CustomRibbonTabs`) viven en el prefijo. **La carpeta de plugins que Studio escanea es la del prefijo**, no `…/appdata/Roblox/Plugins`: una copia en `appdata` se ignora en silencio (el log muestra `Loading Plugins in 0 total`).

### Los plugins locales cargan al abrir un lugar

No al arrancar Studio. Con la pantalla de inicio abierta y sin lugar, la lista está vacía y parece que no se instaló nada.

Para comprobarlo sin mirar la interfaz:

```sh
grep -i "user_Rojo" ~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/logs/*_last.log | tail -3
```

Debe aparecer `loadPlugin user_Rojo.rbxm` y `Running plugin user_Rojo.rbxm`. El botón está en la pestaña **Plugins** de la cinta (barra propia "Rojo"), no crea una pestaña nueva. Ojo: `list_plugin_actions` del MCP no sirve para esto, solo lista toggles de ventanas, no botones de toolbar.

### Servir el proyecto

```sh
cd /home/miranda/Documentos/Proyectospersonales/RobloxGames/Roblox_conect-backrooms   # worktree de la rama backrooms-cleanup (código vivo)
rojo serve            # escucha en localhost:34872
```

En Studio: pestaña **Plugins** → botón **Rojo** → *Connect*. Sin `rojo serve` corriendo, el botón falla con un error de conexión, no de plugin.
