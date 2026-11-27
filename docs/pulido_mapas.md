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
| Escuela | 1347 | 0 | 4 |
| Mansión | 1045 | 4 | 4 |
| Centro comercial | 3696 | 14 | 4 |

Los conteos antiguos de duplicados basados solo en posición y tamaño incluían siluetas con rotaciones diferentes. No deben usarse para borrar piezas automáticamente.

## Contención exterior

Cada mapa incluye `ContencionExterior`, con piezas invisibles ancladas, con colisión y consultas activas. Sigue el exterior de la unión de las huellas de **todas** las plantas; no corta escaleras ni puentes internos. Los segmentos se solapan 0,6 studs en las juntas.

La altura supera la pieza sólida más alta del mapa en 15,2 studs: salto de 7,2 medido en `StarterPlayer` más margen de 8. El borde inferior queda 16 studs bajo la geometría sólida más baja. No es una protección contra exploits, vuelo o teletransportes. Si se cambian el salto o los modelos, regenerar y repetir las pruebas.

## Verificaciones y reproducción

- Seis pruebas de regresión: solapes parciales, conservación de siluetas y marcadores, plataforma y colisión, líneas de grosor mínimo puente superior sin barrera interior y casi coincidencias por redondeo de 0,001 studs.
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

## Resultado en Studio

Aplicado en el place `137133016631933`, guardado en Roblox como versión **481** (sin publicar). Se conservaron los seis respaldos en `ServerStorage.MapsBackup.BeforePolish_20261126`. El MCP necesitó reconexión para reconocer el dominio autorizado.

- Cero caras coplanares residuales en los bloques alineados de los seis mapas del place. Se corrigió una casi coincidencia adicional en un librero de la Escuela; ahora el generador contempla 0,001 studs de tolerancia.
- **43.590 Blockcasts**, repartidos por todos los segmentos, en ambos sentidos y tres alturas: cero pasos a través de las barreras.
- **Play, un cliente:** intentos de caminar/saltar hacia fuera en un borde de cada mapa (incluida la azotea del Hospital): ninguno cruzó. Es una prueba puntual por mapa, complementada por el muestreo geométrico del perímetro; no equivale a recorrer todas las rutas posibles.
- Revisión visual de la Fábrica y del área del librero de la Escuela. Las colisiones nuevas son invisibles.
- `Workspace.zona` ya no existe en este lugar; no fue necesario moverla.
- Scripts de prueba reproducibles fuera de `src/`: `studio_faces.luau`, `studio_verify.luau`, `play_check.luau` y `nav_check.luau`. Anteponer `local mapName = "Level_N"`; los dos últimos se ejecutan en servidor durante Play. Solo alteran temporalmente el estado de la prueba.

### Navegación de criaturas, antes/después en la misma sesión

| Nivel | Nodos antes → después | Mayor componente antes → después | Componentes antes/después |
| --- | --- | --- | --- |
| 1 | 2663 → 2663 | 2663 → 2663 | 1 / 1 |
| 2 | 2150 → 2150 | 1810 → 1810 | 35 / 35 |
| 3 | 7950 → 7954 | 7945 → 7949 | 6 / 6 |
| 4 | 4374 → 4376 | 4374 → 4376 | 1 / 1 |
| 5 | 7134 → 7134 | 7134 → 7134 | 1 / 1 |
| 6 | 9004 → 9006 | 8972 → 8974 | 20 / 20 |

No se perdió conectividad. Los 340 nodos fuera del componente principal del Pantano siguen siendo un pendiente anterior, independiente de este trabajo.
