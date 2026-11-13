# Plan — Linterna de círculo perfecto y ambiente submarino

> **Estado del documento:** propuesta para revisión. Lo aprobado se implementa; lo pendiente queda marcado como `D1`–`D5` y bloquea sus tareas hasta que se decida. Claude deja sus observaciones y conflictos al final, en [Observaciones de Claude](#observaciones-de-claude).
>
> Claude implementa Luau y Rojo. Codex construye mapa, modelos y marcadores. Anotar el resultado de cada prueba en [arranque.md](../../../arranque.md).

**Objetivo.** Que la linterna produzca un círculo de luz limpio y estable en cualquier nivel gráfico, y que el agua tenga un aspecto tipo Subnautica (niebla, color, partículas, audio y transición) sin sacrificar rendimiento en móvil.

**Alcance aprobado (2026-11-13).**

- `LightingStyle = Realistic` con `PrioritizeLightingQuality = true` en el place. Ajuste manual de Studio, no scriptable.
- Círculo perfecto **texturizado** con un PNG de gradiente radial generado por Claude (con respaldo `Neon` si el asset no está disponible).
- El resto del efecto de agua (alcance, nivel del agua, linterna de otros jugadores y audio) queda pendiente de las decisiones `D1`–`D5`.

**Arquitectura.** Todo el efecto es de cliente: se dibuja localmente y no se replica. El servidor solo aporta estado (`LampOn`, `LampDir`, profundidad de partida) y no cambia. Rojo sincroniza desde el worktree de Claude (`src/`).

**Referencias.** [GDD](../../../game_designs/GDD.md), [manifiesto de modelos](../../../creation_models.md), [lugar de pruebas](../../../Launch.md), [plan vigente](2026-11-11-abismo.md).

---

## 1. Hallazgos verificados en el place

Comprobados en Studio el 2026-11-13 (solo lectura, sin modificar el lugar). Sirven para que Claude revise conflictos antes de implementar.

| # | Hallazgo | Efecto |
| --- | --- | --- |
| H01 | `LightingStyle = Soft`, `PrioritizeLightingQuality = true` (equivalente a ShadowMap) | Luces locales planas y sin sombras; el motor degrada detalle de luz al bajar calidad. Causa principal del borde "cortado". |
| H02 | `SpotLight` no expone `Texture` en este build | No se puede hacer un gobo circular con la luz del motor. El círculo debe dibujarse aparte. |
| H03 | `Range` máximo real = 120 (probado: 130→120, 500→120) | `Config.LampRange = 130` y `Upgrades.Lamp.RangeBonus = 30` se recortan: la mejora "Luz potente" no tiene efecto. |
| H04 | `LampAngle = 60` más relleno `LampFillAngle = 120` / `LampFillRange = 14` | Dos conos con borde duro superpuestos. |
| H05 | `LampClient` captura `workspace.CurrentCamera` una sola vez y cuelga el `Part` de `camera`; `beams` no se invalida | Al recrearse la cámara o reaparecer, el `Part` queda destruido y la tabla conserva la referencia: la luz se queda pegada o deja de iluminar. |
| H06 | `Workspace.Maps.Level_1.Pared_1..4` tienen `Transparency = 1` y `CanQuery = true` | Un raycast de luz se pega a paredes invisibles. |
| H07 | Agua de Terrain desde Y≈128 hacia abajo; `Config.SeaLevelY = 0`; el muelle de `Level_1` está en Y=-70 | La profundidad visual no coincide con la geometría (≈200 studs reales frente a 70 de diseño). |
| H08 | `Workspace.Maps.Level_2` y `Level_3` no tienen agua (solo plataforma seca) | El efecto submarino nunca se activa en esos niveles. |
| H09 | `UnderwaterFog` escribe `Lighting.Ambient/OutdoorAmbient` cada frame; `DayNightService` los escribe cada segundo | Se anulan mutuamente; el ciclo día/noche no se aprecia bajo el agua. |
| H10 | 73 luces, 29 emisores, ~2.600 partículas vivas (12 emisores de nieve marina), 12 beams, 4.805 partes | Carga fija alta incluso en calidad baja. |
| H11 | `Lighting.DepthOfField` global con `FocusDistance = 0.05`; `Bloom.Threshold = 2`; `SunRays.Intensity = 0.01` | Valores heredados que conviene auditar. |
| H12 | `PlayerGlow` añade un `PointLight` permanente al jugador | Luz dinámica extra que se mueve con el personaje; contribuye al retraso de luz en calidad baja. |
| H13 | `Workspace.StreamingEnabled = true`, radio 1024; los niveles están a ~160 studs | Todos los niveles permanecen cargados; el streaming no alivia la escena. |

**Diagnóstico de los síntomas**

| Síntoma | Causa |
| --- | --- |
| La luz se queda pegada | Rig bajo `Camera` con referencia vieja (H05) + retraso de actualización de luces del motor + 73 luces compitiendo (H10). |
| No ilumina | `Part` destruido tras recrear cámara o reaparecer (H05), u origen dentro de geometría. |
| Se ve cortada | Cono de 60° con borde duro (H04) + tope de `Range` 120 (H03) + malla de vóxeles de `Soft` (H01). |

---

## 2. Decisiones

### Cerradas

| ID | Decisión | Valor |
| --- | --- | --- |
| D0a | Estilo de iluminación del place | `Realistic` + `PrioritizeLightingQuality = true` |
| D0b | Círculo de luz | Texturizado con un PNG de gradiente radial; respaldo `Neon` |

### Pendientes de revisión con Claude

| ID | Decisión | Opciones | Recomendación | Bloquea |
| --- | --- | --- | --- | --- |
| D1 | Alcance del efecto de agua | Esencial / **Completo** / Máximo | Completo: niebla, tinte, audio, transición, partículas, caústicas y haz de linterna. Máximo añade DOF/Bloom/rayos/oleaje. | W05, W06 |
| D2 | Nivel del agua | (a) bajar el agua de `Level_1` a Y=0 · (b) usar la superficie real Y≈128 · (c) dejar `SeaLevelY = 0` | (a) si se quiere poder alcanzar la superficie y lucir caústicas, rayos y transición. (b) convierte el Nivel 1 en una fosa de ~200 m. | W01, A07 |
| D3 | Linterna de otros jugadores | Completa / **Simplificada** | Simplificada: solo `SpotLight` propio y ajeno; el círculo proyectado solo para el jugador local. | L02, L07 |
| D4 | Audio | Existente / Nuevos loops | Reutilizar burbujas, glugs y `Movimiento`; subir loops solo si falta ambiente. | W03 |
| D5 | Zona somera de prueba | Sí / No | Sí: arrecife de prueba a 0–30 m para validar caústicas, rayos y transición. Sin ella no se puede probar esa parte. | W05, A07 |

> Respuesta rápida esperada: `D1 completo, D2a, D3 simplificada, D4 existente, D5 sí`.

---

## 3. Orden de desarrollo

### A. Linterna (aprobada)

| Estado | ID | Depende de | Entrega | Prueba de aceptación |
| --- | --- | --- | --- | --- |
| [ ] | L01 | — | **Claude.** Módulo `QualityTier` (nivel por `SavedQualityLevel`, FPS y táctil, con histéresis) y banco de linterna en Studio: pared curva, esquina, metal, niebla y atributo `LampQualityOverride` (1/5/10) en `workspace`. | Forzando 1, 5 y 10 se ve el mismo círculo con distinta calidad de derrame. El módulo expone `Tier`, `IsLow`, `Changed`. |
| [ ] | L02 | L01 | **Claude.** Reescribir `LampClient` sobre un rig persistente: carpeta local en `Workspace`, `Camera` resuelta cada frame, limpieza en `CharacterAdded`, origen en `LampOrigin` (respaldo `Head`), `Enabled` en vez de crear/destruir, sin escribir propiedades cada frame. | Encender/apagar 100 veces, morir, reaparecer y cambiar de cámara: la luz nunca se queda pegada ni desaparece. |
| [ ] | L03 | L02 | **Claude.** Raycast y círculo proyectado: `IgnoreWater = true`, exclusión de personaje y FX, reintento si el hit tiene `Transparency ≥ 0.99`, `Part` fino orientado a la normal con `SurfaceGui` + `ImageLabel` (gradiente radial, `LightInfluence = 0`). Respaldo de 3 discos `Cylinder` + `Neon`. | Círculo limpio en pared, suelo y esquina; no se pega a `Pared_*` ni al agua; sigue con suavizado y hace *snap* en teletransportes. |
| [ ] | L04 | L03 | **Claude.** Rebote (`PointLight` corto en el impacto) y haz volumétrico (`Beam` + motas) solo en calidad media/alta. | En calidad 1 no existe coste extra; en 5/10 se aprecia el haz sin bajar FPS. |
| [ ] | L05 | L02 | **Claude.** Reequilibrar `Config` y mejoras: `Range` ≤ 120; "Luz potente" sube brillo, ángulo y radio del círculo, no `Range`. `PlayerGlow` y luces lejanas apagadas por distancia en calidad baja. | La mejora cambia visiblemente la linterna; en calidad 1 se apagan las luces a más de 100 studs sin saltos visibles. |
| [ ] | L06 | — | **Claude.** Auditoría de iluminación: `Realistic` + prioridad, `ShadowSoftness`, revisar `DepthOfField` global (0.05), `Bloom` y `SunRays`; dejar valores de partida documentados. | En calidad 1, 5 y 10 la escena no tiene halos ni desenfoques heredados. Se registra el antes/después en la bitácora. |
| [ ] | L07 | L04, L05, L06 | **Claude.** Pruebas con 2 clientes: linterna propia y ajena, móvil en calidad 1, FPS y capturas. | Dos clientes ven la linterna del otro sin errores; FPS estable en calidad 1 en el banco. |

### B. Agua (bloqueada por D1–D5)

| Estado | ID | Depende de | Entrega | Prueba de aceptación |
| --- | --- | --- | --- | --- |
| [ ] | W01 | D2 | **Claude.** Módulo de profundidad: `WaterSurfaceY` por mapa (atributo) con respaldo en `Config.SeaLevelY`, detección de agua con histéresis y zonas `Surface`/`Reef`/`Twilight`/`Abyssal` con lerp exponencial. | La profundidad del HUD y la del efecto coinciden; al cruzar la superficie no hay parpadeo. |
| [ ] | W02 | W01 | **Claude.** Núcleo visual: `Atmosphere` y `ColorCorrection` **en `Camera`**, sin tocar `Ambient`/`OutdoorAmbient`; escritura a 10–15 Hz y solo si cambia el valor. No pelear con `DayNightService`. | El ciclo día/noche sigue funcionando bajo el agua; sin escrituras por frame; transición suave entre zonas. |
| [ ] | W03 | W01, D4 | **Claude.** Audio y transición: `AmbientReverb = UnderWater`, `SoundGroup` con `EqualizerSoundEffect`, splash y estallido de burbujas al entrar/salir, pulso de FOV y velo que se disipa. | Al cruzar la superficie se oye y se ve la transición; el audio queda apagado al salir. |
| [ ] | W04 | L01, W01 | **Claude.** Partículas: un emisor de nieve marina anclado a la cámara (en vez de 12 en el mundo) y atenuación local de los emisores lejanos según calidad. | Calidad 1: ≤ 300 partículas vivas y sin huecos visibles; calidad 10: mantiene la densidad actual. |
| [ ] | W05 | W04, D1, D5 | **Claude y Codex.** Caústicas (plano que sigue el suelo con `Texture` y `OffsetStuds` animado, solo en los primeros 30 m) y rayos de superficie animados por profundidad y hora. | Se ven en la zona somera, se apagan con la profundidad y de noche, y no aparecen en cuevas. |
| [ ] | W06 | W02, D1 | **Claude.** Post-proceso premium en `Camera`: `Bloom` para bioluminiscencia, `DepthOfField` suave y `SunRays`; solo en calidad alta. | En calidad 1 el efecto se mantiene sin post-proceso; en 10 se nota sin perder legibilidad. |
| [ ] | W07 | W01–W06 | **Claude y Codex.** Calibrar densidad, colores, zonas, audio y transiciones en los tres niveles. Registrar valores finales en `Config`. | Partida completa con 2 y 4 clientes sin errores; valores anotados en la bitácora. |
| [ ] | A07 | D2, D5 | **Codex.** Sumergir `Level_2` y `Level_3` (hoy secos) y construir el arrecife somero de prueba con suelo irregular, roca y techo para cuevas. | El agua cubre los recorridos y la zona somera permite probar caústicas, rayos y transición. |

---

## 4. Diseño de la linterna

### 4.1 Capas

```
LampRig (cliente, no replicado)
├── Origin            parte anclada en carpeta de Workspace; CFrame = origen + mirada
├── SpotLight         derrame ancho y débil (30–34°, sin sombras en baja/media)
├── Hotspot           parte fina en el impacto + SurfaceGui con gradiente radial
│   └── (respaldo)    3 discos Cylinder + Neon concéntricos
├── Bounce            PointLight corto en el impacto           [media/alta]
├── Shaft             Beam con textura suave + motas           [media/alta]
└── Cast              sombras de la SpotLight                  [alta]
```

La `SpotLight` va **más cerrada que el círculo dibujado**: su borde duro queda dentro del círculo brillante y deja de verse.

### 4.2 Parámetros iniciales (a calibrar)

| Parámetro | Valor de partida | Nota |
| --- | --- | --- |
| `LampAngle` | 32° | Cono del motor; el borde queda tapado por el círculo. |
| `LampBrightness` | 4.0 | Sube con la mejora. |
| `LampRange` | 110 | Nunca por encima de 120. |
| `HotspotAngle` | 17° (semiángulo) | Radio = `distancia · tan(17°)`; límites 1,5–28 studs. |
| `HotspotOffset` | 0.05 studs | A lo largo de la normal del impacto. |
| `HotspotBrightness` | 2.0 | `SurfaceGui.Brightness`; sube con la mejora. |
| `BounceRange` | radio × 1.4 | Solo media/alta. |
| `ShaftTransparency` | 0.90 | Solo media/alta. |
| `AimRate` (red) | 10 Hz | Mantiene el límite de 20 Hz del proyecto. |

### 4.3 Textura

Generar `assets_build/textures/lamp_hotspot.png` (256×256, RGBA, blanco al centro con caída suave a transparente), subirla y guardar el ID en `Config`. Si el asset falla o el ID es 0, usar el respaldo `Neon` sin romper el juego.

---

## 5. Diseño del agua

### 5.1 Zonas (profundidad de diseño, a calibrar)

| Zona | Rango | Densidad | Haze | Color | Capas activas |
| --- | --- | --- | --- | --- | --- |
| Surface | 0–15 m | 0.18 | 0.8 | turquesa claro | caústicas, rayos, bloom |
| Reef | 15–80 m | 0.35 | 2.0 | azul verdoso | caústicas atenuadas, partículas |
| Twilight | 80–150 m | 0.55 | 3.5 | azul profundo | partículas, haz de linterna |
| Abyssal | 150+ m | 0.75 | 6.0 | casi negro | bloom de bioluminiscencia |

Transición exponencial a 6/s. Los valores actuales (`SurfaceDensity = 0.12`, `DeepDensity = 0.2`) son demasiado tenues para el aspecto buscado.

### 5.2 Capas por calidad

| Capa | Baja (1–3) | Media (4–7) | Alta (8–10) |
| --- | --- | --- | --- |
| Atmosphere + ColorCorrection en Camera | Sí | Sí | Sí |
| Audio y transición | Sí | Sí | Sí |
| Nieve marina (1 emisor) | Reducida | Media | Completa |
| Caústicas y rayos | No | Sí (cerca) | Sí |
| Bloom / DOF / SunRays | No | Bloom | Todos |
| Haz de linterna y rebote | No | Sí | Sí |

---

## 6. Contratos y assets

- **`Config.luau`:** nuevos bloques `Lamp` y `Water` con los valores de las tablas 4.2 y 5.1. Nada de constantes mágicas en los scripts.
- **Módulos cliente:** `src/StarterPlayer/StarterPlayerScripts/LampRig.luau`, `UnderwaterController.luau` y `QualityTier.luau`. `--!strict` y los nombres del proyecto.
- **Servidor:** `LampService` no cambia de contrato (`ToggleLamp`, `AimLamp`, atributos `LampOn`/`LampDir`). Solo se ajusta la frecuencia si hace falta.
- **Textura:** `lamp_hotspot.png` generada por Claude. La caústica (`caustics_tile.png`) solo si D1 = Completo/Máximo.
- **Codex:** `LampOrigin` dentro del modelo `lamp` (A06); agua y arrecife (A07).
- **Studio:** `Realistic` + prioridad, banco de linterna y `LampQualityOverride`.

---

## 7. Riesgos y conflictos detectados

1. **H07/H08:** `SeaLevelY = 0` no coincide con la superficie real (Y≈128) y los Niveles 2–3 no tienen agua. D2 y A07 deben resolverse antes de calibrar.
2. **H09:** si el nuevo controlador toca `Ambient`, vuelve a romper `DayNightService`. Debe usar solo `ColorCorrection` local.
3. **H03:** cualquier mejora basada en `Range` es invisible por el tope de 120.
4. **H01:** pasar a `Realistic` cambia el aspecto de todo el juego. Verificar el banco de luz y una zona con niebla antes de dar L06 por cerrada.
5. **H06:** el raycast de la linterna debe ignorar `Transparency ≥ 0.99`; si no, el círculo se pega a `Pared_*`.
6. **H10:** 12 emisores de nieve marina siempre activos. W04 debe medir partículas vivas, no solo FPS.
7. **H12:** `PlayerGlow` es una luz dinámica permanente; en calidad baja conviene reducirla o apagarla.
8. **H11:** `DepthOfField` global con foco en 0.05 puede estar desenfocando toda la escena en calidad alta. Confirmar antes de añadir más post-proceso.
9. **Gemini:** su propuesta usa `SEA_LEVEL_Y` fijo, escribe `Ambient` cada frame, asume "auto = gráficos altos" y recrea estado cada frame. No se copia tal cual; se conserva la idea de zonas y capas.

---

## 8. Observaciones de Claude

> Sección reservada. Claude anota aquí conflictos con el código actual, dependencias con A06/A07 y cualquier detalle que cambie las decisiones D1–D5.

| Fecha | Observación | Afecta | Resolución |
| --- | --- | --- | --- |
|  |  |  |  |

---

## 9. Bitácora de pruebas

| Fecha | Tarea | Lugar / commit | Clientes | Calidad | Resultado |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
