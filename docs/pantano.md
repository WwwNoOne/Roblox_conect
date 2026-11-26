# Level_2 · Pantano de la Esclusa

Importa [Level_2.rbxmx](../assets_build/exports/Level_2.rbxmx) como `Workspace.Maps.Level_2`. El modelo utiliza `ElevatorDock` como pivote, con `+Z` hacia la salida de la cabina. [Planta del mapa](../assets_build/exports/Level_2_Planta.png).

| Cabaña | Pisos | Habitaciones |
| --- | ---: | ---: |
| Choza del Vigía | 1 | 3 |
| Casa de las Redes | 1 | 4 |
| Casa del Bombeo | 2 | 5 |
| Hospedaje Hundido | 2 | 6 |
| Caseta del Motor | 1 | 5 |
| Casa de la Esclusa | 2 | 7 |
| Pensión de los Sauces | 2 | 8 |
| Bodega de Juncos | 1 | 4 |

El acople tiene tres salidas a una red de pasarelas con circuito y dos atajos. Los dos pisos están a Y = 0 y a Y = 10. Las escaleras exteriores se suben desde el costado de cada cabaña, siguiendo el porche. El lecho está a Y = −3 y tiene gradas para volver a las pasarelas. Los árboles ocultan los cierres físicos del perímetro.

Los faroles y los parches de bruma están activos dentro del modelo. `PerfilPantano` contiene plantillas de `Atmosphere` y `ColorCorrectionEffect`. Para mostrar la niebla de distancia y la corrección de color, clónalas a `Lighting` mientras se juega en `Level_2` y retira esas copias al salir. Para revisar el ambiente en Studio, el perfil se puede probar con una hora nocturna y luz tenue. La superficie es visual y el lecho permite caminar. La penalización de velocidad o ruido y la emboscada exterior corresponden a la lógica de integración. El lecho incluye `PathfindingModifier.Label = "SwampShallows"` como referencia para esa lógica.

El modelo incluye puntos de tesoro con atributo `Size`, cuatro posiciones de máquina, tres de caja fuerte, seis escondites, cuatro posiciones de criatura y ocho nodos numerados de patrulla. La comprobación geométrica fuera de Studio alcanzó las 42 habitaciones desde el acople, validó los cuatro tramos de escalera y comprobó la redundancia de las tres salidas. Falta la prueba con avatares y criaturas en Studio.
