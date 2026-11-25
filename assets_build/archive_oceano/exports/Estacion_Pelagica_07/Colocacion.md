# Estación pelágica 07

Inserta `Estacion_Pelagica_07.rbxmx` desde el menú contextual de **Workspace → Insert from File**. El conjunto contiene dos modelos anclados, con sus colisiones de piso y pared y luces de emergencia. La entrada y la estación ya están alineadas con las cajas blancas de referencia. Retira las cajas de referencia o desactiva su colisión para liberar el paso.

| Pieza | Tamaño exterior en Studio (X × Y × Z) | Centro en Studio (X, Y, Z) |
|---|---|---|
| Entrada abandonada | 28 × 23 × 67 studs | (−306, 61.305, 319.5) |
| Estación abandonada | 120 × 153 × 97 studs | (−281, −17.114, 366.5) |

La entrada se recorre hacia **+Z**. Una rampa atraviesa el hueco del techo y desemboca en observación. La ruta bordea el atrio por el fondo y llega a las rampas del costado este, que conectan observación, laboratorio, comunicaciones, almacén y máquinas.

Para recolocar las dos piezas juntas, mueve el modelo padre. Para montarlas por separado, alinea los Attachments `Conexion` con la misma orientación. Usa el RBXMX para conservar luces, transparencia y colisiones. Los FBX de la [entrada](Entrada_Abandonada.fbx) y la [estación](Estacion_Abandonada.fbx) contienen la geometría con textura de color. La [fuente Blender](Estacion_Pelagica_07.blend) conserva los grupos editables.

Las dos piezas y su unión se comprobaron en Studio. Las pruebas geométricas de recorrido se hicieron sobre el modelo. La prueba de partida queda pendiente.
