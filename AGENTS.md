# Agent Orchestration Directive

## Roles & Responsabilidades
- **Claude Code (Lead Software Engineer):** Se encarga exclusivamente de escribir scripts en Luau (`src/`), configurar la arquitectura Cliente/Servidor, gestionar la persistencia cuando el GDD la requiera y mantener la integración con Rojo.
- **Codex (Technical 3D Artist):** Se encarga de la creación, edición,de mapa,npc y otros
## Flujo de Trabajo (Hand-off)
1. Claude revisa `game_designs/GDD.md` y define los identificadores de los modelos necesarios en `creation_models.md`.
2. Codex lee las especificaciones de `creation_models.md` y entrega el modelo o mapa como `.rbxmx` en `assets_build/exports/`. Usa estilo low poly, texturas planas y ambientación de espacios liminales tipo Backrooms (sin motivos oceánicos). Incluye rig y clips editables cuando el modelo deba animarse.
3. Claude integra el modelo en Roblox y programa la lógica en Luau usando los nombres y marcadores definidos en `creation_models.md`.

## Subida de assets (Open Cloud)

El repo incluye el MCP `roblox-opencloud` (ver `tools/roblox-opencloud-mcp/README.md`): sube `.glb/.gltf/.fbx`, `.png/.jpg`, audio y devuelve el `assetId` para usarlo en Studio, sin pasar por el Creator Hub. Requiere la API key en `~/.config/opencode/roblox-opencloud.env`.

- Solo sube archivos dentro del repo; el resto se rechaza.
- Modelos como `Model`, texturas como `Image` (nunca `Decal`: el id no texturiza y no da error).
- `.rbxmx` no se sube por Open Cloud: se importa en Studio desde `assets_build/exports/`.

