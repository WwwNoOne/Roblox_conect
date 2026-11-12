# Gigantes abisales

Las dos criaturas se diseñaron como fauna ambiental para el fondo de Abismo. Las escalas de esta primera versión se eligieron para leer sus siluetas desde lejos. El tamaño está expresado en ancho × alto × largo.

| Criatura | Tamaño aproximado | Triángulos | Huesos | Ciclos |
|---|---:|---:|---:|---|
| Manta abisal | 125 × 43 × 131 studs | 2.728 | 17 | Deriva de 6 s y nado de 8 s |
| Nautilo colosal | 66 × 67 × 159 studs | 4.840 | 38 | Deriva de 10 s y nado de 12 s |

## Archivos para Studio

1. Importa el FBX base de la [manta](Manta_Abisal.fbx) o del [nautilo](Nautilo_Colosal.fbx) con **Archivo → Importar 3D**.
2. Abre el rig en el **Editor de animaciones** e importa los FBX de los clips sobre ese mismo rig. Marca la reproducción en bucle. Studio admite una pista por exportación FBX. [Especificaciones de Roblox](https://create.roblox.com/docs/art/modeling/specifications)
3. Las animaciones son en el sitio. `Root` se mantiene fijo y el movimiento de avance queda a cargo de la trayectoria ambiental del proyecto.

| Criatura | Deriva | Nado |
|---|---|---|
| Manta | [Idle](Manta_Abisal_Idle.fbx) | [Swim](Manta_Abisal_Swim.fbx) |
| Nautilo | [Idle](Nautilo_Colosal_Idle.fbx) | [Swim](Nautilo_Colosal_Swim.fbx) |

La [fuente Blender](Gigantes_Abisales.blend) tiene una escena por criatura y las cuatro acciones editables. Los FBX llevan incrustada la [textura de color](Fauna_Abisal_Color.png). La [máscara emisiva](Fauna_Abisal_Emissive.png) se puede asignar al `SurfaceAppearance` para conservar el brillo de ojos, fotóforos y puntas en la oscuridad. [Texturas PBR](https://create.roblox.com/docs/art/modeling/surface-appearance)
