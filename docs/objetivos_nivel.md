# Objetivos del nivel: generadores, cajas fuertes y tesoros

Implementado el 25/11/2026. Parámetros en `Config.Objectives` (valores de prueba, a calibrar en T08).

## Flujo
1. Al llegar a un nivel (`Runs` estado `Level`), `ObjectiveService` coloca en el mapa cargado (`Workspace.Maps.<Nivel>`):
   * un **generador** en cada `MachineSpawn` elegido. Aparecen `Base + floor((jugadores-1)/PerExtraPlayers) + Spare` (máx. los que haya); hay que reparar `Needed` (sin el `Spare`).
   * una **caja fuerte** en cada `PuzzleSpawn` cuyo Part padre empieza por `Cofre`.
   * una **puerta con puzzle** (persiana) en cada `PuzzleSpawn` cuyo Part padre empieza por `Puerta` (26/11/2026).
2. `EconomyHandlers` reparte los tesoros 0,3 s después y **descarta los `TreasureSpawn` que caen dentro de un generador o caja**.
3. Mientras `run.powerDone < run.powerNeeded`, `RequestDescend` devuelve `POWER_OFF` («Sin energía: reparen los generadores primero»). El temporizador del nivel sigue partiendo solo.
4. HUD: panel **ENERGÍA** bajo la cuota (`SurvivalHud`), alimentado por `powerDone`/`powerNeeded` de `UpdateHUD`.

## Minijuegos (`PuzzleClient`, validados en servidor)
* **Generador · calibración de fase:** una aguja va y vuelve por el medidor. `Espacio`/`E`/clic la fija. Dentro de la franja = fase estable; fuera = chispazo, ruido y se pierde una fase. 3 fases, cada una más rápida y estrecha. El servidor recalcula la aguja con la hora de servidor que envía el cliente (con margen `MaxClockSkew`).
* **Caja fuerte · dial:** `A`/`D`, flechas, rueda o botones giran el dial 0-39. Al pasar por el número correcto suena un clic y se enciende el piloto (consulta `Probe`, máx. 14/s). `Espacio` fija el número. Un número incorrecto reinicia la combinación y bloquea el dial 2,5 s. Al abrirse, la puerta gira sobre la bisagra y dentro aparecen un tesoro Grande y uno Mediano.
* **Puerta · panel de interruptores** (`Config.Objectives.Door`): 5 palancas con su luz. Cada palanca invierte su luz y las dos vecinas; hay que encenderlas todas. El estado sale de aplicar `Scramble` pulsaciones al azar desde la solución (siempre tiene solución) y nunca se resuelve con menos de `MinPresses`. Cada palanca hace ruido (`PressNoiseRadius`). Con `Budget` pulsaciones gastadas sin resolverlo: **cortocircuito** (chispas, ruido grande, se vuelve a mezclar y el panel se bloquea `LockoutSeconds`). `1`-`5` o clic accionan; `A`/`D` eligen y `Espacio` acciona. Hay un panel a cada lado del vano: vale cualquiera.
* `Q`/`Retroceso` salen. Con el minijuego abierto el ratón queda libre y el personaje no se mueve. Alejarse, morir o el fin del nivel lo cierran. Un objetivo lo usa un jugador a la vez.

## Animaciones (`ObjectiveFx`, cliente)
* Generador averiado: chispazos sueltos, humo y piloto rojo que parpadea. Al fallar: lluvia de chispas con destello. Reparado: el ventilador arranca, la palanca baja, humo por el escape, luz cálida, zumbido 3D y pantalla «EN LÍNEA».
* Caja fuerte: el dial gira mientras alguien la manipula; piloto rojo → ámbar → verde; luz interior al abrirse.
* Puerta: las palancas y luces del panel 3D siguen el estado (servidor); cortocircuito con chispas en los dos paneles; al resolverla la luz pasa a verde y la persiana se enrolla hacia arriba (ya no colisiona).
* Tesoros: la luz late y, al recogerlos, vuelan hacia quien los recoge encogiéndose, con sonido.

## Modelos
`Props` construye el generador y la caja fuerte con piezas (low poly, colores planos, como `Level_1`) y los apoya contra la pared más cercana, deslizándolos si chocan con muebles. Si Codex entrega `GameAssets/Generator` o `GameAssets/Safe` con el contrato de nombres de `creation_models.md`, se usan esos.

La puerta (`Props.BuildDoor`) siempre se construye con piezas, a la medida del vano: desde el marcador se lanzan rayos a las jambas (en X o en Z, máx. `MaxJamb`) y al dintel; el grosor sale de la jamba. El Part del marcador puede fijar el vano con los atributos `Width` / `Height`. Contrato: `Door` (`Plate`, `BottomBar`, lamas), `StatusLightA/B`, `PanelA/PanelB` (`Back.PromptAttachment`, `Back.SparkPoint`, `Lever1..N`, `Lamp1..N`). Sonidos `Lever` y `Shutter` provisionales (reutilizan los de cerradura y caja).

## Sonidos (Creator Store, en `Config.Objectives.Sounds`)
Generador (Alpha_Corvi), chispa y apertura (ProSoundEffects), clic de cerradura, bloqueo, zumbador y recogida (SCP:CB, CC BY-SA 3.0: requiere crédito, como los pasos metálicos).

## Pendiente
* `Noise.Emitted` (ruido de reparaciones y fallos) aún no lo escucha nadie: conectarlo en T05 cuando las criaturas se muevan.
* Probar con 4 clientes (2 verificado el 26/11/2026).
* Sonidos propios de palanca y persiana.
* T05: las persianas cerradas son obstáculo para la navegación de las criaturas.
