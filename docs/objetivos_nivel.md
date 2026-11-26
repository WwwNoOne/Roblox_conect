# Objetivos del nivel: generadores, cajas fuertes y tesoros

Implementado el 25/11/2026. Parámetros en `Config.Objectives` (valores de prueba, a calibrar en T08).

## Flujo
1. Al llegar a un nivel (`Runs` estado `Level`), `ObjectiveService` coloca en el mapa cargado (`Workspace.Maps.<Nivel>`):
   * un **generador** en cada `MachineSpawn` elegido. Aparecen `Base + floor((jugadores-1)/PerExtraPlayers) + Spare` (máx. los que haya); hay que reparar `Needed` (sin el `Spare`).
   * una **caja fuerte** en cada `PuzzleSpawn` cuyo Part padre empieza por `Cofre`. Los `PuzzleSpawn` de `Puerta…` siguen libres (puertas con puzzle, pendiente).
2. `EconomyHandlers` reparte los tesoros 0,3 s después y **descarta los `TreasureSpawn` que caen dentro de un generador o caja**.
3. Mientras `run.powerDone < run.powerNeeded`, `RequestDescend` devuelve `POWER_OFF` («Sin energía: reparen los generadores primero»). El temporizador del nivel sigue partiendo solo.
4. HUD: panel **ENERGÍA** bajo la cuota (`SurvivalHud`), alimentado por `powerDone`/`powerNeeded` de `UpdateHUD`.

## Minijuegos (`PuzzleClient`, validados en servidor)
* **Generador · calibración de fase:** una aguja va y vuelve por el medidor. `Espacio`/`E`/clic la fija. Dentro de la franja = fase estable; fuera = chispazo, ruido y se pierde una fase. 3 fases, cada una más rápida y estrecha. El servidor recalcula la aguja con la hora de servidor que envía el cliente (con margen `MaxClockSkew`).
* **Caja fuerte · dial:** `A`/`D`, flechas, rueda o botones giran el dial 0-39. Al pasar por el número correcto suena un clic y se enciende el piloto (consulta `Probe`, máx. 14/s). `Espacio` fija el número. Un número incorrecto reinicia la combinación y bloquea el dial 2,5 s. Al abrirse, la puerta gira sobre la bisagra y dentro aparecen un tesoro Grande y uno Mediano.
* `Q`/`Retroceso` salen. Con el minijuego abierto el ratón queda libre y el personaje no se mueve. Alejarse, morir o el fin del nivel lo cierran. Un objetivo lo usa un jugador a la vez.

## Animaciones (`ObjectiveFx`, cliente)
* Generador averiado: chispazos sueltos, humo y piloto rojo que parpadea. Al fallar: lluvia de chispas con destello. Reparado: el ventilador arranca, la palanca baja, humo por el escape, luz cálida, zumbido 3D y pantalla «EN LÍNEA».
* Caja fuerte: el dial gira mientras alguien la manipula; piloto rojo → ámbar → verde; luz interior al abrirse.
* Tesoros: la luz late y, al recogerlos, vuelan hacia quien los recoge encogiéndose, con sonido.

## Modelos
`Props` construye el generador y la caja fuerte con piezas (low poly, colores planos, como `Level_1`) y los apoya contra la pared más cercana, deslizándolos si chocan con muebles. Si Codex entrega `GameAssets/Generator` o `GameAssets/Safe` con el contrato de nombres de `creation_models.md`, se usan esos.

## Sonidos (Creator Store, en `Config.Objectives.Sounds`)
Generador (Alpha_Corvi), chispa y apertura (ProSoundEffects), clic de cerradura, bloqueo, zumbador y recogida (SCP:CB, CC BY-SA 3.0: requiere crédito, como los pasos metálicos).

## Pendiente
* `Noise.Emitted` (ruido de reparaciones y fallos) aún no lo escucha nadie: conectarlo en T05 cuando las criaturas se muevan.
* Puertas con puzzle (`PuzzleSpawn` en `Puerta01/02`).
* Probar con 2-4 clientes (Studio → Test → Clients).
