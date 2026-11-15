# Martillo Abisal

Criatura de cabeza en martillo con cuatro pares de apéndices frontales y dos pares de aletas caudales. La malla tiene 4.772 triángulos y mide 6,86 × 2,48 × 21,08 studs en la pose de reposo. La cadena axial tiene 21 huesos desde `Head` hasta `Tail_Tip`. La cabeza está ligada al 100 % a `Head`.

## Importación en Roblox Studio

1. En **Archivo → Importar**, selecciona [Martillo_Abisal.fbx](Martillo_Abisal.fbx). Usa **Rig personalizado**, **Unidad de escala → Stud** y **Factor de escala → 1**. Activa **Mantener huesos de influencia cero** para conservar `Root` y deja **Combinar mallas** y **Usa jaulas** desactivados. La cabeza apunta hacia `-Z` al importar. [Importador de Roblox](https://create.roblox.com/docs/studio/importer)
2. El FBX usa el PNG de color de la misma carpeta para la vista previa. Importa los cuatro PNG y asigna sus IDs a una instancia `SurfaceAppearance` hija de `Piel_Martillo`. Los cuatro mapas comparten un único atlas UV de 1024 × 1024. [SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance)

| Propiedad | PNG |
|---|---|
| `ColorMap` | [Martillo_ColorMap.png](Martillo_ColorMap.png) |
| `NormalMap` | [Martillo_NormalMap.png](Martillo_NormalMap.png) |
| `RoughnessMap` | [Martillo_RoughnessMap.png](Martillo_RoughnessMap.png) |
| `EmissiveMaskContent` | [Martillo_EmissiveMask.png](Martillo_EmissiveMask.png) |

## Animaciones

Selecciona el modelo importado en **Avatar → Editor de clips**. En el menú de tres puntos, elige **Importar → Desde archivo**, selecciona el FBX del clip y confirma **Personalizado**. Activa el bucle para `Idle` y `Swim`. Los clips se animan en el sitio. Publica cada clip bajo el propietario de la experiencia para reproducirlo por ID en el juego. [Documentación de Roblox](https://create.roblox.com/docs/resources/beyond-the-dark/custom-characters)

| Clip | Duración | FBX |
|---|---:|---|
| Reposo | 6 s | [Idle](Martillo_Abisal_Idle.fbx) |
| Nado | 3 s | [Swim](Martillo_Abisal_Swim.fbx) |
| Sobresalto | 1,6 s | [Startle](Martillo_Abisal_Startle.fbx) |

La [fuente de Blender](Martillo_Abisal.blend) conserva las acciones editables, los PNG empaquetados y el modificador `Armature` activo.
