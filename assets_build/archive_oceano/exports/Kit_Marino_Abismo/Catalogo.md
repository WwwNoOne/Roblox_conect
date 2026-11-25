# Kit marino de Abismo

Doce mallas independientes con pivote en la base. Las alturas del catálogo se muestran a la escala original de cada pieza. Cada FBX incluye la textura de color.

## Piezas

| Pieza | Ancho × fondo × alto (studs) | Triángulos | Uso |
|---|---:|---:|---|
| [Alga de bosque](Alga_Bosque.fbx) | 7,9 × 6,7 × 19,2 | 2948 | Alga alta de dos tallos, con láminas verdes y vesículas doradas. |
| [Cinta roja](Alga_Cinta_Roja.fbx) | 8,2 × 8,4 × 9,6 | 2372 | Roseta de cintas carmesí arqueadas, con lóbulos y venas. |
| [Pasto marino](Pasto_Marino.fbx) | 4,6 × 3,8 × 4,1 | 1020 | Macolla baja y extendida, pensada para repetirse sobre el lecho. |
| [Faroles abisales](Flora_Farol_Abisal.fbx) | 5,0 × 3,4 × 7,8 | 2244 | Faroles alienígenas en tallos curvos, con piel azul y núcleos cian. |
| [Coral ramificado](Coral_Ramificado.fbx) | 4,9 × 4,4 × 6,6 | 2148 | Colonia coralina de ramas porosas de color salmón. |
| [Coral abanico](Coral_Abanico.fbx) | 6,5 × 3,3 × 5,2 | 2698 | Gorgonia púrpura con huecos entre ramas y puntas rosadas. |
| [Esponja tubular](Esponja_Tubular.fbx) | 4,9 × 4,1 × 5,6 | 1948 | Grupo de ocho tubos abiertos con bocas verdes bioluminiscentes. |
| [Coral de repisa](Coral_Repisa.fbx) | 8,2 × 6,0 × 5,7 | 1640 | Lajas coralinas lavanda con bordes luminosos sobre una chimenea. |
| [Columna de basalto](Roca_Columna_Basalto.fbx) | 7,7 × 6,9 × 8,8 | 260 | Columna volcánica alta para siluetas y pasos estrechos. |
| [Laja escalonada](Roca_Laja_Escalonada.fbx) | 10,6 × 6,2 × 4,2 | 300 | Repisa ancha de estratos irregulares para bordes y desniveles. |
| [Arco natural](Roca_Arco_Natural.fbx) | 19,7 × 6,6 × 10,9 | 366 | Arco de basalto con vano abierto para marcar un pasillo. |
| [Grupo de derrumbe](Roca_Grupo_Derrumbe.fbx) | 8,0 × 5,6 × 2,5 | 958 | Conjunto de cascajo, bloques pequeños y colonias de percebes. |

## Roblox Studio

Importa las piezas que quieras con **Archivo → Importar 3D**. Ancla las piezas de escenario con `Anchored = true`. Para flora y corales de decoración, ajusta `CanCollide` a `false`. Si quieres atravesar el arco con colisión de roca, revisa el hueco con `CollisionFidelity = PreciseConvexDecomposition`.

La [máscara emisiva compartida](Kit_Marino_Emissive.png) es opcional. Puedes asignarla como máscara de emisión del `SurfaceAppearance` para resaltar los faroles, las bocas de esponja y los bordes de coral. La [textura de color compartida](Kit_Marino_Color.png) también se entrega aparte. [Importador de Roblox Studio](https://create.roblox.com/docs/studio/importer) · [Texturas PBR](https://create.roblox.com/docs/art/modeling/surface-appearance)

La [fuente Blender](Kit_Marino_Abismo.blend) incluye las 12 mallas agrupadas por familia y ambas texturas empaquetadas. Las vistas de catálogo encuadran cada pieza por separado.
