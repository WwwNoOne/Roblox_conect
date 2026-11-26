# Guía de modelos

El [manifiesto](../../creation_models.md) define IDs, nombres, prioridades y presupuesto por modelo. Estilo: low poly estilizado con ambientación liminal tipo Backrooms (sin motivos oceánicos).

- **Ascensor.** Cabina transitable para cuatro avatares, con puerta, estación de venta, tienda e indicador. Piezas separadas para paredes, suelo y techo. Aspecto de ascensor/cabina industrial.
- **Niveles.** Secciones modulares con entradas claras y espacio de maniobra. Ocultar el ascensor en un nicho de acople. Incluir los puntos `TreasureSpawn`, `MachineSpawn`, `PuzzleSpawn`, `CreatureSpawn` y `Patrol`.
- **Máquinas y puzzles.** Siluetas legibles, `StatusLight` para el estado, `PromptAttachment` para interactuar.
- **Criaturas.** Planos 2.5D animados (`BillboardGui` multicapa con sprite sheets de cuerpo + ojos emisivos y screamer 2D) basados en terror estilo Minecraft para prototipo. Ver especificación y guía completa para Codex en [docs/criaturas.md](../../docs/criaturas.md).

Entregar FBX y fuente editable cuando exista, con tamaño, eje frontal, pivote, piezas móviles y colisiones. Verificar en Studio escala, orientación, colisión, nombres y Attachments.
