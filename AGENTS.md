# Agent Orchestration Directive

## Roles & Responsabilidades
- **Claude Code (Lead Software Engineer):** Se encarga exclusivamente de escribir scripts en Luau (`src/`), configurar la arquitectura Cliente/Servidor, gestionar la persistencia cuando el GDD la requiera y mantener la integración con Rojo.
- **Codex (Technical 3D Artist):** Se encarga de la creación, edición,de mapa,npc y otros
## Flujo de Trabajo (Hand-off)
1. Claude revisa `game_designs/GDD.md` y define los identificadores de los modelos necesarios en `creation_models.md`.
2. Codex lee las especificaciones de `creation_models.md` y entrega el modelo o mapa como `.rbxmx` en `assets_build/exports/`. Usa estilo low poly, texturas planas y colores sombríos acordes con el terror submarino. Incluye rig y clips editables cuando el modelo deba animarse.
3. Claude integra el modelo en Roblox y programa la lógica en Luau usando los nombres y marcadores definidos en `creation_models.md`.
