# Pulido de mapas · 26/11/2026

Alcance: parpadeo por superficies superpuestas y contención del jugador en los seis mapas actuales. No se modifica `src/`, la distribución, los marcadores, las cuotas ni la duración de las etapas.

## Geometría

`tools/levelgen/polish.py` separa caras exteriores coincidentes de bloques alineados con los ejes, incluidos los girados 90°. No elimina intersecciones válidas de paredes ni las siluetas cruzadas del bosque. La separación por conflicto es de 0,02 studs, con un máximo de 0,12 por cara. Los planos delgados de pintura se desplazan en vez de reducirse por debajo del mínimo de Roblox. Las colisiones se mantienen; no cambia la altura de `Platform`. Solo se eliminan duplicados con geometría, orientación equivalente y propiedades visuales/físicas iguales, sin marcadores ni luces.

El escritor XML conserva nueve cifras significativas: con las cinco anteriores se perdían separaciones pequeñas en coordenadas grandes.

| Mapa | Piezas ajustadas | Duplicados reales retirados | Segmentos de contención |
| --- | ---: | ---: | ---: |
| Fábrica | 2873 | 0 | 244 |
| Pantano | 2114 | 0 | 170 |
| Hospital | 4811 | 0 | 20 |
| Escuela | 1345 | 0 | 4 |
| Mansión | 1045 | 4 | 4 |
| Centro comercial | 3696 | 14 | 4 |

Los conteos antiguos de duplicados basados solo en posición y tamaño incluían siluetas con rotaciones diferentes. No deben usarse para borrar piezas automáticamente.

## Contención exterior

Cada mapa incluye `ContencionExterior`, con piezas invisibles ancladas, con colisión y consultas activas. Sigue el exterior de la unión de las huellas de **todas** las plantas; no corta escaleras ni puentes internos. Los segmentos se solapan 0,6 studs en las juntas.

La altura supera la pieza sólida más alta del mapa en 15,2 studs: salto de 7,2 medido en `StarterPlayer` más margen de 8. El borde inferior queda 16 studs bajo la geometría sólida más baja. No es una protección contra exploits, vuelo o teletransportes. Si se cambian el salto o los modelos, regenerar y repetir las pruebas.

## Verificaciones y reproducción

- Cinco pruebas de regresión: solapes parciales, conservación de siluetas y marcadores, plataforma y colisión, líneas de grosor mínimo y puente superior sin barrera interior.
- Cero caras coincidentes en los bloques alineados de los seis archivos XML exportados. La revisión no evalúa superficies curvas ni bloques de rotación arbitraria.
- Marcadores y atributos protegidos comparados antes/después de generar.

```sh
python3 tools/levelgen/test_polish.py
python3 tools/levelgen/gen.py all
python3 tools/levelgen/verify_polished_exports.py assets_build/exports/Level_?.rbxmx
```

Para generar los parches de Studio junto con los exports y el informe:

```sh
python3 tools/levelgen/export_polish.py --patch-dir /tmp/backrooms-polish
python3 -m http.server 8791 --bind 127.0.0.1 --directory /tmp/backrooms-polish
```

`studio_patch.luau` se ejecuta como herramienta de edición, nunca como script de juego. Requiere el dominio local autorizado en MCP. Anteponer `local mapName = "Level_1"; local apply = false` para verificar la coincidencia de cada pieza, después `apply = true` para aplicar. Conserva un respaldo en `ServerStorage.MapsBackup.BeforePolish_20261126`. `studio_verify.luau` comprueba los segmentos con Blockcast en ambos sentidos y varias alturas.

**Estado de Studio:** aplicación y pruebas en el lugar pendientes de restablecer la conexión/permisos MCP. Los exports sí están corregidos y verificados localmente.
