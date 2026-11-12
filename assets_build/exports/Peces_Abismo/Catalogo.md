# Peces de Abismo

Seis peces ambientales independientes, con esqueleto y textura de color incrustada. Las medidas de la tabla indican el largo de cada pez.

| Pez | Largo | Triángulos | Modelo | Nado en bucle | Arranque |
|---|---:|---:|---|---|---|
| Farol rojo | 2,9 studs | 1112 | [FBX](Pez_Farol_Rojo.fbx) | [Swim · 2,4 s](Pez_Farol_Rojo_Swim.fbx) | [Dart · 1,1 s](Pez_Farol_Rojo_Dart.fbx) |
| Ojo dorado | 2,5 studs | 848 | [FBX](Pez_Ojo_Dorado.fbx) | [Swim · 1,8 s](Pez_Ojo_Dorado_Swim.fbx) | [Dart · 1,1 s](Pez_Ojo_Dorado_Dart.fbx) |
| Aro lunar | 2,6 studs | 1092 | [FBX](Pez_Aro_Lunar.fbx) | [Swim · 2,6 s](Pez_Aro_Lunar_Swim.fbx) | [Dart · 1,1 s](Pez_Aro_Lunar_Dart.fbx) |
| Mariposa | 2,4 studs | 900 | [FBX](Pez_Mariposa.fbx) | [Swim · 2,8 s](Pez_Mariposa_Swim.fbx) | [Dart · 1,1 s](Pez_Mariposa_Dart.fbx) |
| Cuchilla | 1,8 studs | 728 | [FBX](Pez_Cuchilla.fbx) | [Swim · 2,2 s](Pez_Cuchilla_Swim.fbx) | [Dart · 1,1 s](Pez_Cuchilla_Dart.fbx) |
| Aguja espectral | 2,7 studs | 668 | [FBX](Pez_Aguja_Espectral.fbx) | [Swim · 1,4 s](Pez_Aguja_Espectral_Swim.fbx) | [Dart · 1,1 s](Pez_Aguja_Espectral_Dart.fbx) |

## Roblox Studio

Importa el FBX base de cada pez desde **Archivo → Importar 3D**. En el Editor de animaciones, carga los dos FBX de clips sobre su rig correspondiente. Activa el bucle para **Swim** y usa **Dart** como un gesto de una sola reproducción. Cada archivo de clip contiene una pista. [Especificaciones de Roblox](https://create.roblox.com/docs/art/modeling/specifications)

Los clips se reproducen en el sitio y mantienen fijo el hueso Root. Las trayectorias del cardumen quedan a cargo de la lógica del proyecto. Al duplicar una especie puedes iniciar su ciclo en puntos distintos para que las colas no se muevan al unísono.

La [fuente Blender](Peces_Abismo.blend) incluye las doce acciones en seis escenas. El [atlas de color](Peces_Abismo_Color.png) está incrustado en los FBX. La [máscara emisiva](Peces_Abismo_Emissive.png) se entrega aparte para SurfaceAppearance. [Texturas PBR](https://create.roblox.com/docs/art/modeling/surface-appearance)
