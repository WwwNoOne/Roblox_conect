# Agent Orchestration Directive

## Roles y responsabilidades
- **Claude Code (Lead Software Engineer):** escribe los scripts en Luau (`src/`), la arquitectura Cliente/Servidor, la persistencia cuando el GDD la requiera y la integración con Rojo. Revisa y verifica en Studio (MCP) el trabajo de modelado.
- **Codex (Technical 3D Artist):** crea y edita mapas, salas, NPC y otros modelos (Blender → `.fbx`/`.blend`).
- **Usuario:** modela en Studio las salas, el pasillo y la decoración, y decide el diseño.

## Flujo de trabajo (hand-off)
1. Claude revisa `game_designs/GDD.md` y `game_designs/Generacion_Cuevas.md` y define los modelos necesarios en `creation_models.md`.
2. Codex (o el usuario) lee `creation_models.md`, produce el modelo y lo deja en Studio o en `assets_build/exports`.
3. Claude programa la lógica en Luau importando los identificadores de las mallas (`MeshPart`) en Roblox.

## Por dónde empezar
- **Estado actual y tareas pendientes (para repartir entre subagentes):** [`ESTADO.md`](ESTADO.md).
- Diseño del sistema de cuevas: [`game_designs/Generacion_Cuevas.md`](game_designs/Generacion_Cuevas.md). Criaturas: [`game_designs/Criaturas.md`](game_designs/Criaturas.md).
- Convenciones de código: [`Docs/CLAUDE.md`](Docs/CLAUDE.md). Convenciones de arte: [`Docs/CODEX.md`](Docs/CODEX.md).

## Reglas de coordinación
- **Un solo agente escribe en Studio a la vez** (Studio es un único documento compartido; los cambios no se versionan). El código sí se versiona (Rojo): varios agentes pueden editar archivos distintos de `src/` en paralelo.
- Rojo se lanza con `rojo serve default.project.json` (en segundo plano, con 2 h de límite) y el plugin debe reconectarse.
