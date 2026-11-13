# Gigantes abisales

Las dos criaturas se diseñaron como fauna ambiental para el fondo de Abismo. Las escalas de esta primera versión se eligieron para leer sus siluetas desde lejos. El tamaño está expresado en ancho × alto × largo.

| Criatura | Tamaño aproximado | Triángulos | Huesos | Ciclos |
|---|---:|---:|---:|---|
| Manta abisal | 125 × 43 × 131 studs | 2.728 | 17 | Deriva de 6 s y nado de 8 s |
| Nautilo colosal | 66 × 67 × 159 studs | 4.840 | 38 | Deriva de 10 s y nado de 12 s |

## Archivos para Studio

Inserta [Manta_Abisal.rbxmx](Manta_Abisal.rbxmx) o [Nautilo_Colosal.rbxmx](Nautilo_Colosal.rbxmx) con **Insertar desde archivo** en el Explorador de Studio. Cada modelo incluye un `AnimationController`, un `Animator` y los ciclos `Idle` y `Swim` en la carpeta `Animaciones`. Estas versiones usan las mallas de Roblox con color por vértice, por lo que se pueden insertar sin cargar el PNG. Los ciclos son `KeyframeSequence` editables en el archivo.

### Importación desde FBX

1. Importa el FBX base de la [manta](Manta_Abisal.fbx) o del [nautilo](Nautilo_Colosal.fbx) con **Archivo → Importar 3D**. Desactiva **Merge Meshes** y **Uses Cage**, selecciona **Rig Type → Custom** y activa **Keep Zero Influence Bones** para conservar `Root`. [Opciones de importación de Roblox](https://create.roblox.com/docs/studio/importer)
2. Abre el rig en el **Editor de animaciones** e importa los FBX `Idle` y `Swim` como clips sobre ese mismo rig. Marca la reproducción en bucle. Studio admite una pista por exportación FBX. [Especificaciones de Roblox](https://create.roblox.com/docs/art/modeling/specifications)
3. Las animaciones son en el sitio. `Root` se mantiene fijo y el movimiento de avance queda a cargo de la trayectoria ambiental del proyecto.

| Criatura | Deriva | Nado |
|---|---|---|
| Manta | [Idle](Manta_Abisal_Idle.fbx) | [Swim](Manta_Abisal_Swim.fbx) |
| Nautilo | [Idle](Nautilo_Colosal_Idle.fbx) | [Swim](Nautilo_Colosal_Swim.fbx) |

Si Studio falla al subir la imagen, importa la [manta con color integrado](Manta_Abisal_ColorIntegrado.fbx) o el [nautilo con color integrado](Nautilo_Colosal_ColorIntegrado.fbx) con los mismos ajustes. Deja **Ignore Vertex Colors** desactivado. Estas variantes llevan el color en la geometría y conservan los huesos para los mismos clips. El color por vértice reproduce la paleta general con menos detalle superficial que el mapa PNG. [Colores por vértice en el importador](https://create.roblox.com/docs/studio/importer)

Los FBX usan un material con un único mapa de color incrustado. Si una malla aparece gris en Studio, importa [Fauna_Abisal_Color.png](Fauna_Abisal_Color.png) y asígnala al `ColorMap` de su `SurfaceAppearance`. Para recuperar la bioluminiscencia de ojos, fotóforos y puntas, asigna la [máscara emisiva](Fauna_Abisal_Emissive.png) a `EmissiveMaskContent` en ese mismo `SurfaceAppearance`. [Texturas PBR](https://create.roblox.com/docs/art/modeling/surface-appearance)

La [fuente Blender](Gigantes_Abisales.blend) incluye el material de vista previa con emisión, una escena por criatura y las cuatro acciones editables.
