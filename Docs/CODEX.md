# Codex Guidelines (Blender 3D Modeling)

- Entorno de trabajo: Ejecutar Blender en modo headless o vía bridge local en Python (`blender --background`).
- Estilo visual: espacios liminales tipo Backrooms (ver `creation_models.md`). Low poly con texturas planas. La paleta depende de cada nivel; evitar cualquier motivo oceánico.
- Presupuesto de geometría: usar el límite por modelo definido en el [manifiesto](../creation_models.md).
- Exportación: Siempre aplicar transformaciones (Location, Rotation, Scale = 1.0) antes de exportar a `.fbx` con ejes Y-Forward, Z-Up (estándar de Roblox).
- No usar ni referenciar `assets_build/archive_oceano/` salvo para reciclar topología.
