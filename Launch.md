# Roblox Studio y lugares de prueba

> El banco de pruebas oceánico (puerto, agua de Terrain, marcadores `Marker_*`, `LightTest`, `hoja_coral`, `Workspace.Maps` con niveles submarinos) **quedó obsoleto el 2026-11-25**. Antes de integrar, limpiar el lugar `137133016631933` en Studio: eliminar agua de Terrain, `Workspace.OceanWorld`, `Workspace.Markers`, `Workspace.hoja_coral` y los mapas submarinos de `Workspace.Maps`.

## Lugar de integración

1. Desde el worktree de Claude, ejecutar `rojo build` y `rojo serve`. Conectar el plugin de Rojo y verificar el lugar seleccionado antes de sincronizar.
2. Mantener el escenario creado en Studio fuera de los contenedores que Rojo controla.
3. Los mapas viven bajo `Workspace.Maps` (`Level_N`, `Parada`) con los nombres de [creation_models.md](creation_models.md). **[POR DEFINIR]** cuando existan los nuevos niveles.
4. Probar con **Server & Clients** y dos clientes como mínimo; cuatro para validar espacio interior, puerta y concurrencia.
5. Registrar lugar, commit, cantidad de clientes, resultado y pasos para reproducir fallos en [arranque.md](arranque.md).

En Linux, el selector de archivos de Studio bajo Wine muestra rutas `Z:/home/…`.

## Plugin de Rojo en Linux (instalado 2026-11-25)

`rojo plugin install` **no funciona en Linux** (`Your platform is not currently supported`): solo conoce las rutas de Windows y macOS. El plugin se copia a mano en la carpeta de plugins de Studio, que bajo Vinegar es `%LOCALAPPDATA%\Roblox\Plugins`:

```
~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/Plugins/Rojo.rbxm
```

Instalado **Rojo 7.7.1**, la misma versión que el CLI de `/home/miranda/.rokit/bin/rojo`. La versión del plugin y la del CLI deben coincidir; para actualizar:

```sh
curl -sSL -o /tmp/Rojo.rbxm https://github.com/rojo-rbx/rojo/releases/download/v<X.Y.Z>/Rojo.rbxm
cp /tmp/Rojo.rbxm ~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/Plugins/Rojo.rbxm
```

Studio carga los plugins **solo al arrancar**: hay que reiniciarlo para que aparezca la pestaña *Rojo* en la toolbar. Si tras reiniciar no aparece, revisar el log más reciente en `…/appdata/Roblox/logs/` buscando `Roblox\Plugins`.

### Servir el proyecto

```sh
cd /home/miranda/.claudette/workspaces/Roblox_conect/burnished-lilac   # worktree con default.project.json
rojo serve            # escucha en localhost:34872
```

En Studio: pestaña **Rojo** → *Connect*. Sin `rojo serve` corriendo el botón falla con un error de conexión, no de plugin.
