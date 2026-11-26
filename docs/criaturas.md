# Criaturas y guía de creación (Backrooms Coop)

> **Estado:** Aprobado para prototipo y pruebas en `Level_1` (2026-11-26).
> **Referencias:** [GDD](../game_designs/GDD.md) · [Manifiesto de modelos](../creation_models.md) · [Plan (T05)](plan.md) · [Directivas de Codex](../Docs/CODEX.md)

Este documento define las **3 categorías de criaturas** iniciales, las variantes **SujetoFeliz** y **Acosador del Tramo Final**, el enfoque visual **2.5D**, la animación de screamer y el contrato de entrega en `assets_build/exports/`.

---

## 1. Enfoque visual y de animación

### 1.1 Criaturas en el mundo: Plano 2.5D animado (sin rig 3D)
En lugar de modelos 3D con rig (que requieren modelado, pesado y clips en Blender y pueden perder fuerza visual en pasillos oscuros), las criaturas de prueba y primera línea usan **planos 2.5D orientados a la cámara** (`BillboardGui` sobre un `Part` raíz):

1. **Animación por Sprite Sheet (cliente):** un PNG en grilla (ej. `4×4`) reproducido cambiando `ImageRectOffset` y `ImageRectSize` en el cliente según el atributo `Estado` publicado por el servidor (`Idle`, `Patrol`, `Chase`, `Windup`, `Lunge`, `Stalk`, `Ambush`, `Flee`).
2. **Doble capa de iluminación (profundidad en penumbra):**
   * **Cuerpo (`LightInfluence = 1`):** queda oscuro en los pasillos sin luz y **se revela al alumbrarlo con la linterna**.
   * **Ojos / detalles emisivos (`LightInfluence = 0`):** capa independiente encima del cuerpo que **brilla en la oscuridad** aunque la linterna esté apagada.
3. **Oclusión real:** `AlwaysOnTop = false` en todos los `BillboardGui`, para que paredes, pilares y puertas cerradas oculten a la criatura.
4. **Trucos de volumen y movimiento procedural (cliente):**
   * Oscilación vertical y balanceo lateral proporcional a la velocidad (cabalgata de persecución).
   * Espasmos cortos de escala/rotación en `Windup` o al detectar a un jugador.
   * Sombra suave en el suelo, `ParticleEmitter` oscuro sutil en `Root` y `PointLight` tenue de corto alcance para teñir paredes cercanas.

### 1.2 Screamer: animación 2D multicapa (no un PNG estático)
Cuando el **Acechador** embosca a un jugador, el cliente dispara una secuencia de ~0.9 s combinando:
1. **Sprite Sheet del screamer (`ScreamerImage`):** 8–16 cuadros rápidos (`16–24` FPS) donde la silueta/boca se abre y abalanza hacia la pantalla.
2. **Golpe de entrada y vibración:** escala rápida (`0.35 → 1.35` en `~0.08 s`), flash blanco/rojo de 2 cuadros y sacudida coordinada con `CameraFxClient` (sin interferir con `CameraMotion`).
3. **Glitch / aberración cromática 2D:** dos copias extra del sprite teñidas de rojo y cian con desplazamiento aleatorio de píxeles + franjas horizontales de estática + viñeta oscura/roja en bordes.
4. **Audio en capas:** impacto grave (*sub-bass*) + grito distorsionado + estática de salida.

---

## 2. Categorías de criaturas

### 2.1 Categoría 1 — Agresivo (`creature_agresivo_01`)
* **Inspiración de diseño (prototipo):** *Cave Dweller*, *The Knocker* o *Nextbot* humanoide alto y delgado. *(Para pruebas puede basarse en estilo Minecraft terrorífico; antes de publicación comercial, reemplazar por diseño propio estilo Backrooms).*
* **Rol:** Amenaza principal constante que obliga a huir, apagar la linterna o esconderse.
* **Comportamiento:**
  * Patrulla la red de pasillos y escucha ruidos (`Sprint`, fallos de generadores, cortocircuitos de puertas vía `Noise.Emitted`).
  * Detecta por línea de visión (amplificada por la linterna encendida del jugador) y por oído cercano.
  * Al detectar: ruge, alerta a enemigos cercanos y persigue con aceleración progresiva (frenesí).
  * **Ataque:** preparación breve (`Windup`, aviso visual/sonoro para esquivar) → embestida (`Lunge`). **Si atrapa al jugador, lo mata** (daño letal `100`, configurable por especie).
  * Si el jugador se esconde en una caja `Escondite` sin ser visto, pierde el rastro; si el Agresivo se queda pegado a la caja olisqueando (`DiscoverSeconds`), lo saca de ella.
  * **Límites:** nunca entra en la zona segura del Ascensor (`SafeZone`).

### 2.2 Categoría 2 — Acosador (`creature_acosador_01`)
* **Inspiración de diseño (prototipo):** *Herobrine*, *The Watcher* o *Man From The Fog* (silueta quieta al fondo del pasillo con ojos blancos/rojos brillantes).
* **Rol:** Terror psicológico, vigilancia y presión sobre jugadores separados del grupo.
* **Comportamiento:**
  * Busca líneas de visión largas a distancia media-larga (observando desde pasillos oscuros o intersecciones sin cargar de inmediato).
  * Mantiene `EyesBillboard` encendido (`LightInfluence = 0`) para que sus ojos destaquen en la oscuridad.
  * **Al ser descubierto (mirado de frente o alumbrado fijo ~1.5–2.5 s):** emite un sonido inquietante y se retira/desaparece hacia otro nodo lejano del mapa (o hace una finta corta).
  * **Si es ignorado mientras observa mucho tiempo (~5–7 s):** delata la posición del jugador alertando al **Agresivo** más cercano y eleva el temblor de tensión.

### 2.3 Categoría 3 — Acechador (`creature_acechador_01`)
* **Inspiración de diseño (prototipo):** *The Mimicer* / *Dwellers* de esquina / entidad pegada en zonas de paso y escondites.
* **Rol:** Castigar el descuido al girar esquinas sin mirar o al entrar a escondites sin prestar atención.
* **Comportamiento:**
  * En lugar de patrullar continuamente, elige un punto de emboscada en **esquinas/cruces** o junto a una caja **`Escondite`** (máximo una caja ocupada a la vez para no inutilizar el sigilo).
  * Emite una **pista sutil de proximidad** (respiración leve / estática suave a muy corta distancia) para que un jugador atento pueda detectarlo antes de caer.
  * **Al acercarse un jugador al umbral (o intentar usar la caja ocupada):**
    1. Lanza el **screamer 2D** al jugador sorprendido.
    2. **Baja vida** (`25–35` HP, daño no letal salvo vida crítica).
    3. Entra en estado `Flee` / `Cooldown` y se reubica en otro punto lejano para no campear la misma esquina.

### 2.4 Variante agresiva — SujetoFeliz (`sujetoFeliz`)

Máscara flotante de yeso resquebrajado, cuencas oscuras y sonrisa abierta. Combina la aparición silenciosa del Acosador con una embestida más rápida que el sprint del jugador.

* **Aparición.** Elige un jugador objetivo fuera de la zona segura y aparece a distancia en un punto navegable con línea de visión. Se queda quieto, orientado hacia ese jugador, durante `Stalk`.
* **Mirada sostenida.** Si el objetivo lo mira directamente y sin interrupciones durante el umbral, SujetoFeliz pasa a `Lunge` y se abalanza a gran velocidad. Una vez iniciada la embestida, apartar la mirada deja de cancelarla. La ruta respeta paredes, puertas cerradas y el Ascensor.
* **Mirada apartada.** Si el objetivo aparta la mirada antes de activar la embestida, el contador se reinicia. Si la aparta de forma sostenida, o nunca lo mira durante la ventana inicial, la criatura desaparece sin atacar. Una pared interpuesta cuenta como pérdida de visión. En cooperativo, solo la mirada del jugador objetivo cuenta.
* **Valores de prototipo ajustables.** Distancia de aparición de 50 a 90 studs, observación inicial de hasta 5 s si el jugador objetivo aún no lo ha mirado, 3 s de mirada continua para activar el ataque, 0.6 s mirando hacia otro lado para desaparecer y velocidad de embestida de 44 studs/s.
* **Contrato visual.** `sujetoFeliz` usa `Category = "Aggressive"` y `Behavior = "SujetoFeliz"`. La grilla 4 × 4 aporta poses de reposo, observación, avance y ataque. La muestra de `Workspace.sujetoFeliz` sirve para revisar el arte. La integración debe registrar el comportamiento en `MonsterService` antes de incluir el asset en el grupo de criaturas que aparecen durante la partida.

### 2.5 Variante — Acosador del Tramo Final (`creature_acosador_final_01`)

Conserva la silueta de la referencia adjunta: rostro negro con ojos blancos, torso pálido y brazos largos. El sprite mantiene el encuadre de la ilustración. La capa de ojos sigue visible en penumbra.

* **Antes del tramo final.** Conserva el acecho del Acosador base. Observa desde lejos, se retira ante una mirada sostenida y puede delatar al jugador si lo ignoran.
* **Al quedar poco tiempo.** A **30 s** del final, valor ajustable para el prototipo, aparece en un punto navegable fuera del Ascensor si estaba oculto. Pasa de `Stalk` a `Chase` y avanza a **6 studs/s**, también ajustables. La mirada y la linterna dejan de hacerlo retroceder durante esta fase.
* **Persecución persistente.** Mantiene la persecución hasta que termina el nivel. Si pierde de vista a su objetivo, busca una ruta hacia su última posición conocida y reanuda la persecución al recuperarlo. Si ese jugador muere o entra al Ascensor, cambia a otro jugador válido. Respeta puertas cerradas, paredes y la zona segura.
* **Contrato visual.** `Category = "Stalker"`, `Behavior = "FinalPursuit"`. Dos PNG 4 × 4 alineados, para cuerpo y ojos. La muestra en `Workspace.creature_acosador_final_01` permite comprobar el arte. La transición de fase depende del temporizador del servidor y queda en la integración de `MonsterService`.

### 2.6 Categorías futuras (en estudio, no implementar aún)
* **Ciego / Sensible al ruido** (*The Warden*): sin visión (ignora linterna), pero reacciona a larga distancia ante cualquier ruido (`Sprint`, generador, puerta); refuerza el uso de agacharse (`C`).
* **Estatua / Reverso de mirada** (*The Creaking* / *SCP-173*): avanza rápido solo cuando ningún jugador la mira o alumbra; se congela bajo contacto visual.

---

## 3. Guía de creación para Codex (Sprites + `.rbxmx`)

### 3.1 Presupuesto y formato de imágenes (Sprite Sheets)
* **Formato:** PNG con canal alfa limpio (fondo `100%` transparente, sin bordes blancos).
* **Resolución máxima por archivo:** **`1024 × 1024` px** (límite de subida de Roblox).
* **Grilla recomendada para mundo:** **`4 × 4`** (16 cuadros iguales de `256 × 256` px; o `4 × 2` de `256 × 512` px para criaturas muy altas y estrechas, indicando `SpriteCols` / `SpriteRows`).
  * **Distribución de filas en `4 × 4`:**
    * Fila 1 (cuadros `1..4`): `Idle` (respiración, parpadeo, temblor).
    * Fila 2 (cuadros `5..8`): `Patrol` / `Stalk` (paso lento o postura de acecho).
    * Fila 3 (cuadros `9..12`): `Chase` / `Flee` (carrera frenética, brazos extendidos).
    * Fila 4 (cuadros `13..16`): `Windup` / `Attack` / `Ambush` (pose de ataque o salto).
* **Capa de ojos (`EyesImage`):** segundo PNG con **exactamente la misma grilla y alineación**, pero dibujando únicamente los ojos/boca brillante sobre fondo transparente. Si no tiene ojos brillantes (ej. opcional en Acechador), puede omitirse.
* **Sprite Sheet del Screamer (`ScreamerImage`, obligatorio en `creature_acechador_01`):**
  * Grilla `4 × 4` o `4 × 3` en `1024 × 1024` px (cuadros de `256 × 256` px o `256 × 341` px), secuencia continua desde el cuadro 1 al último (cara/garras acercándose y abriendo la boca).
* **Regla de subida Open Cloud:** usar el MCP `roblox-opencloud` subiendo cada PNG como tipo **`Image`** (nunca `Decal`, ver [AGENTS.md](../AGENTS.md)). Si una criatura se prueba antes de subir texturas, puede entregarse el `.rbxmx` con placeholders temporales y los PNG en `assets_build/exports/creatures/`.

### 3.2 Contrato exacto del `.rbxmx` (`assets_build/exports/`)
Entregar un archivo `.rbxmx` por criatura en `assets_build/exports/` (o dentro de `assets_build/exports/creatures/` y replicado en `ServerStorage.GameAssets.Creatures` en Studio). Los scripts buscan por **nombre exacto**:

* **Nombre del `Model` raíz:**
  * `creature_agresivo_01`
  * `creature_acosador_01`
  * `creature_acechador_01`
  * `sujetoFeliz` (variante agresiva)
  * `creature_acosador_final_01` (variante del Acosador)
* **Jerarquía obligatoria dentro del `Model`:**
  * `Root` (`Part`, `PrimaryPart` del `Model`):
    * `Size`: aprox. `Vector3.new(2, 8, 2)` (se ajusta al escalado de pasillos de 16 studs).
    * `Transparency = 1`, `Anchored = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `Massless = true`.
    * Frente lógico: **`-Z`**.
  * `BodyBillboard` (`BillboardGui`, hijo de `Root`):
    * `Adornee = Root` (o nil al ser hijo directo de `Root`).
    * `AlwaysOnTop = false` *(obligatorio para que las paredes lo tapen)*.
    * `LightInfluence = 1` *(obligatorio para que reaccione a oscuridad y linterna)*.
    * `Size`: en escala de studs (`UDim2.fromScale(W, H)`), recomendado:
      * Agresivo: `UDim2.fromScale(5.5, 9.5)`
      * Acosador: `UDim2.fromScale(4.5, 8.5)`
      * Acechador: `UDim2.fromScale(5.0, 7.5)`
    * `StudsOffset = Vector3.new(0, 0.5, 0)` (centrado sobre el piso cuando `Root` está a mitad de altura).
    * `MaxDistance = 240`.
    * Hijo `Sprite` (`ImageLabel`): `Size = UDim2.fromScale(1, 1)`, `BackgroundTransparency = 1`, `ScaleType = Enum.ScaleType.Fit`, `Image = rbxassetid://...`.
  * `EyesBillboard` (`BillboardGui`, hijo de `Root`, recomendado en Agresivo y Acosador):
    * Mismos `Size`, `StudsOffset`, `MaxDistance` y `AlwaysOnTop = false`.
    * `LightInfluence = 0` *(brilla siempre en lo oscuro)*.
    * Hijo `Eyes` (`ImageLabel`): `Size = UDim2.fromScale(1, 1)`, `BackgroundTransparency = 1`, `ScaleType = Enum.ScaleType.Fit`, `ZIndex = 2`, `Image = rbxassetid://...`.
* **Elementos opcionales recomendados en `Root`:**
  * `FloorShadow` (`Part` plano fino abajo de `Root` con `Decal` de círculo difuminado oscuro, `CanCollide = false`).
  * `AuraParticles` (`ParticleEmitter` oscuro sutil, `Rate = 6–12`).
  * `EyeLight` (`PointLight` tenue, `Range = 8–12`, `Brightness = 0.6–1.2`, color rojo/blanco según especie).
  * `Grab` (`Attachment` en `Root`, para referencia de ataque/posición).

### 3.3 Atributos obligatorios en el `Model` raíz
El animador 2.5D y el sistema de screamer leen estos atributos directamente del `Model`:

| Atributo | Tipo | Ejemplo | Uso |
| :--- | :--- | :--- | :--- |
| `Category` | `string` | `"Aggressive"` / `"Stalker"` / `"Ambusher"` | Categoría de IA |
| `BodyImage` | `string` | `"rbxassetid://123..."` | Sprite sheet del cuerpo (respaldo si no viene en `Sprite.Image`) |
| `EyesImage` | `string` | `"rbxassetid://456..."` | Sprite sheet de ojos (opcional) |
| `SpriteCols` | `number` | `4` | Columnas de la grilla |
| `SpriteRows` | `number` | `4` | Filas de la grilla |
| `AnimFps` | `number` | `12` | Velocidad base de cuadros por segundo |
| `ScreamerImage` | `string` | `"rbxassetid://789..."` | Sprite sheet 2D del screamer (solo `Ambusher`) |
| `ScreamerCols` | `number` | `4` | Columnas del screamer |
| `ScreamerRows` | `number` | `4` | Filas del screamer |
| `ScreamerFrames` | `number` | `12` | Total de cuadros útiles del screamer |

### 3.4 Checklist de verificación en Roblox Studio (Codex)
1. Colocar el modelo en un pasillo oscuro de `Level_1` (`Lighting` con poca luz).
2. Confirmar que con la linterna apagada **no se ve el cuerpo**, solo los **ojos** (`EyesBillboard` con `LightInfluence = 0`), y al apuntar la linterna **aparece el cuerpo** (`BodyBillboard` con `LightInfluence = 1`).
3. Confirmar que al caminar detrás de una pared de `Level_1`, el modelo **desaparece detrás del muro** (`AlwaysOnTop = false`).
4. Confirmar que el cuadro `(0, 0)` de la grilla está alineado y no recorta brazos/cabeza ni muestra bordes del cuadro vecino (dejar ~4 px de margen interior en cada celda).
5. Comprobar que el suelo no corta los pies de la criatura (`StudsOffset` y altura de `Root` acordes a `Level_1`).

---

## 4. Transición futura a 3D (opcional)
Si tras validar la jugabilidad se decide modelar alguna criatura en 3D en Blender:
* Se conserva exactamente el mismo `Model` raíz, `Root` (`-Z` al frente) y `Grab`, sustituyendo `BodyBillboard`/`EyesBillboard` por la malla riggeada con `AnimationController` + `Animator` y clips `Idle`, `Walk`/`Run`, `Attack`.
* La lógica del servidor (`MonsterService`) no requiere cambios.
