# Agent Orchestration Directive

## Roles & Responsabilidades
- **Claude Code (Lead Software Engineer):** Se encarga exclusivamente de escribir scripts en Luau (`src/`), configurar la arquitectura Cliente/Servidor, gestionar la persistencia cuando el GDD la requiera y mantener la integración con Rojo.
- **Codex (Technical 3D Artist):** Se encarga de la creación, edición,de mapa,npc y otros
## Flujo de Trabajo (Hand-off)
1. Claude revisa `game_designs/GDD.md` y define los identificadores de los modelos necesarios en `creation_models.md`.
2. Codex lee las especificaciones de `creation_models.md`, ejecuta el pipeline de Blender y exporta el archivo `.fbx` o `.blend`.
3. Claude programa la lógica en Luau importando los identificadores de la malla (`MeshPart`) en Roblox.
