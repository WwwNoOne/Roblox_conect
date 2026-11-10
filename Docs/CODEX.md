# Codex Guidelines (Blender 3D Modeling)

- Entorno de trabajo: Ejecutar Blender en modo headless o vía bridge local en Python (`blender --background`).
- Estilo Visual: Low-Poly / Anime Stylized (definido en `creation_models.md`).
- Presupuesto de geometría: Máximo 2,500 triángulos por asset estático; máximo 5,000 para modelos complejos.
- Exportación: Siempre aplicar transformaciones (Location, Rotation, Scale = 1.0) antes de exportar a `.fbx` con ejes Y-Forward, Z-Up (estándar de Roblox).