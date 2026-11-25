> Diseño histórico de Ocean Depth Explorer v1.3. El diseño vigente está en [GDD.md](../GDD.md).

### Core Loop: Ocean Depth Explorer

1. **Acción (Riesgo):** Bucear en zonas de naufragios para capturar peces y recolectar tesoros, gestionando el oxígeno y esquivando criaturas hostiles.
2. **Recompensa (Loot & Escape):** Retornar a la superficie con el inventario lleno de botín antes de quedarse sin oxígeno o morir.
3. **Inversión (Progreso):** Vender el botín en el puerto para comprar mejoras (tanques de oxígeno, trajes de presión, luz y arpones).
4. **Retorno (Nuevo Desafío):** Descender a fosas oceánicas más profundas para acceder a nuevos naufragios y especies de mayor valor.
## identidad
Ocean Depth Explorer
Género: Supervivencia, terror psicológico, exploración y aventura.

Jugadores: Solitario y multijugador cooperativo.

Combate: Mínimo. Esconderse, distraer enemigos y escapar.

Objetivo: Explorar las profundidades, descubrir secretos, recuperar recursos y regresar con vida.

Estilo visual: Low-poly estilizado, con iluminación y atmósfera de terror.

Plataformas: PC y dispositivos móviles.
---

## Ocean Depth Explorer — Game Design Document

**Versión:** 1.3 — borrador consolidado para revisión
**Estado:** preproducción, sin programación aprobada
**Fuente:** decisiones de diseño tomadas en conversación; documento independiente, no sincronizado con GitHub
**Leyenda:** **CONFIRMADO** = elección explícita del creador; **PROPUESTO** = valor o solución sugerida pendiente de validar; **PENDIENTE** = decisión abierta.

## 1. Visión
**CONFIRMADO.** Videojuego Roblox de supervivencia exigente pero equilibrada, terror ambiental y exploración submarina. Se juega en solitario o en cooperación. Combate mínimo; esconderse y escapar son centrales. Se busca un mundo vivo donde el jugador ordinario se gana la vida explorando el océano, y la curiosidad puede llevarlo a historias de terror opcionales.

**Principios:** libertad con consecuencias; peligro advertido y comprensible; progresión mediante equipamiento y conocimiento, no bloqueos arbitrarios de nivel; retorno a puerto como cierre de una expedición; compatible con PC y móvil.

## 2. Mundo e historia
**CONFIRMADO.** Humanos quedaron varados en un planeta mayormente oceánico tras el choque de una nave, ahora inutilizable debido a daños y radiación. Fundaron una colonia en una isla cercana. Solo una isla habitada en el alcance inicial. El personaje es un ciudadano común que se aventura para sobrevivir. No hay campaña principal obligatoria. Se pueden investigar por iniciativa propia relatos y rastros de expediciones desaparecidas. El futuro narrativo queda abierto.

**PROPUESTO.** La nave estrellada se contempla a distancia desde la costa y es una región restringida; taberna, mercado, taller, puerto y viviendas hacen creíble a la colonia. Una primera historia opcional de un submarino desaparecido.

## 3. Mundo oceánico
**CONFIRMADO.** Mapa fijo, diseñado a mano; océano continuo, sin biomas procedurales. Regiones de riesgo creciente, determinadas principalmente por profundidad, equipamiento y fauna. Es posible ingresar antes de estar preparado y morir por ello. El límite exterior es un Vacío oscuro protegido por leviatanes, sin recompensas imprescindibles.

**PROPUESTO.** Regiones y profundidades aproximadas, con transiciones superpuestas: costa/arrecifes 0–80 m; naufragios 60–200 m; mar profundo 180–450 m; fosas abisales 400–900 m. El Vacío no es un área de farmeo: terreno en caída, visibilidad casi nula, advertencias ambientales y leviatanes territoriales. La geometría no será concéntrica ni uniforme. Para el primer lanzamiento, priorizar dos regiones jugables completas y una porción funcional del Vacío.

## 4. Ciclos ambientales
**CONFIRMADO.** Ciclo día/noche en isla y aguas superficiales, profundidades permanentemente oscuras. Clima sencillo con lluvia ocasional, sin tormentas complejas iniciales.

**PROPUESTO.** Día de 40 min reales: 5 min amanecer, 18 día, 5 atardecer y 12 noche. Atenuación gradual de luz: 0–80 m variación clara, 80–200 m luz reducida, 200–450 m penumbra y oscuridad creciente, >450 m oscuridad. Lluvia principalmente visual/sonora. Especies diurnas y nocturnas en aguas superficiales, fauna abisal independiente de la hora.

## 5. Bucle de juego
**CONFIRMADO.** Preparar equipo en la isla → salir a explorar → capturar peces y reunir recursos/tesoros/planos → evitar criaturas, vigilar oxígeno y presión → regresar al puerto → almacenar, vender, fabricar o reparar → repetir hacia zonas más peligrosas. Investigar historias es opcional. Expediciones libres, sin misión obligatoria.

## 6. Progresión y tecnologías
**CONFIRMADO.** La capacidad de sobrevivir depende de trajes, tanques, vehículos y herramientas. La experiencia o `Stage` no prohíbe entrar en zonas. Las tecnologías nuevas se desbloquean mediante exploración y hallazgo de planos, no mediante una ruta principal de investigación en taller. Los materiales son característicos de cada región.

**PROPUESTO.** Los planos esenciales para alcanzar una región deben encontrarse con equipo obtenible en la anterior. Descubrir un plano es permanente; fabricarlo exige recursos y Coins. `Stage` puede representar progreso tecnológico o descubrimientos, pero su definición exacta sigue **PENDIENTE**.

## 7. Oxígeno, salud, presión y energía
**CONFIRMADO.** Tanque básico de 6 minutos. Dificultad exigente y equilibrada. Oxígeno, salud, presión y batería son sistemas centrales; sin hambre, sed ni sueño por ahora.

**PROPUESTO — equilibrio inicial a probar:**
- **Oxígeno:** 360 s básicos; nado normal consume a ritmo estándar, nado rápido +25%; reposición en superficie o desde vehículo operativo; advertencias a 90 s y 30 s; a cero, asfixia de 10 HP/s; tanque medio 9 min y avanzado 12 min; cápsula consumible de +30 s.
- **Salud:** 100 HP, sin aumento automático por nivel; criatura pequeña 10–20 HP por ataque, territorial 25–40, grande 50–80, leviatán del Vacío normalmente letal. Botiquín +30 HP en 4 s; enfriamiento 20 s, acción interrumpida por daño. Curación completa en colonia.
- **Presión:** límites de traje básico 80 m, reforzado 200 m, profundidad 450 m, abisal 900 m. En los primeros 10 m excedidos: aviso sin daño; entre +10 y +30 m: 2 HP/s; +30 a +60 m: 6 HP/s; más de +60 m: 15 HP/s. Al volver a profundidad segura cesa el daño. Prohibir curación mientras se recibe daño por presión.
- **Vehículos:** casco con límite propio de profundidad; excederlo daña primero la estructura; no confundir oxígeno del conductor con aire de cabina.
- **Batería:** alimenta linterna, sonar y dispositivos; autonomía y recarga exactas **PENDIENTES**.

## 8. Sigilo, comportamiento animal y leviatanes
**CONFIRMADO.** Combate mínimo. Peces pacíficos, evasivos y defensivos; depredadores territoriales, cazadores de emboscada y especies migratorias. Leviatanes del Vacío como barrera terrorífica no derrotables de forma ordinaria.

**PROPUESTO.** Detección por sonido, línea de visión/luz y vibraciones según especie. Inmóvil = muy poco ruido; nado lento = bajo; normal = medio; propulsor y sonar = alto; señuelos = muy alto. Un enemigo que pierde línea de visión y contacto entra en búsqueda local durante ~10 s, no conoce mágicamente al jugador. Estados IA: patrulla, sospecha, investigación, persecución, ataque, retirada. Los leviatanes patrullan regiones del Vacío, avisan con sonido/sombra antes del ataque y vuelven a su territorio. No se generan súbitamente delante de la cámara.

## 9. Muerte y pertenencias
**CONFIRMADO.** El inventario transportado queda en contenedor recuperable en la posición de muerte; contenedor persistente entre desconexiones. Marcador de posición **exacta**, incluida profundidad. Pueden recuperarlo el dueño y compañeros de la expedición autorizados; otros jugadores no pueden saquearlo. Se conservan nivel, Coins depositadas, planos y mapa. Respawn en isla con kit básico gratuito. Submarinos averiados persisten y pueden recuperarse y repararse.

**PROPUESTO.** Autorización de compañeros capturada en el momento de la muerte; objetos rescatados conservan la propiedad original. Tres contenedores activos visibles; al crearse un cuarto, el más antiguo pasa a registro inactivo, preservando contenidos y retornando a activo cuando haya espacio. Se debe verificar que no permita duplicación, depósito seguro gratuito ni sobrecarga de datos. Destrucción de vehículos: la carga se conserva dentro del vehículo averiado hasta recuperarse; si el jugador muere fuera, su mochila va al contenedor personal. **PENDIENTE:** qué sucede con contenido que deja de ser recuperable físicamente por fallos de geometría, y política de restauración de emergencia.

## 10. Cooperativo y rescates
**CONFIRMADO.** Experiencia tanto solitaria como cooperativa; los compañeros autorizados pueden ayudar a recuperar los contenedores. No se exige grupo para el progreso principal.

**PROPUESTO.** Hasta cuatro jugadores por expedición. Cuando daño no instantáneamente letal agota salud, estado incapacitado hasta 30 s; estabilización por otro jugador usando botiquín durante 5 s. Asfixia, presión extrema y ataque terminal de leviatán excluyen rescate. Las tareas en grupo son flexibles, sin clases obligatorias. El juego debe funcionar de forma satisfactoria en solitario.

## 11. Inventario y almacenamiento
**CONFIRMADO.** Pertenencias transportadas están en riesgo; lo asegurado en la isla no. El espacio limitado da sentido a volver a puerto.

**PROPUESTO.** Mochila 12 espacios; almacén de isla 60; minisubmarino 16; submarino de expedición 48. Algunos materiales se apilan y los objetos voluminosos ocupan más espacios. En lanzamiento evitar simulación detallada de peso. Registro de especies y relatos separado del inventario físico. Depósito en isla para asegurar botín.

## 12. Economía, comercio y fabricación
**CONFIRMADO.** Moneda principal `Coins`; sistema **mixto**: compra básica en tiendas, fabricación de equipo/mejoras con materiales y Coins. Comercio entre jugadores de peces, minerales y recursos, no vehículos ni equipamiento avanzado. Planos obtenidos explorando. Recursos regionales.

**PROPUESTO.** Recursos: chatarra metálica en naufragios, fibra marina en arrecifes, cristal conductor en mar profundo, aleación abisal en fosas, componentes electrónicos en tecnología abandonada. Valores de venta y costos de fabricación son meras hipótesis sujetas a pruebas; evitar economía pay-to-win. Intercambio seguro solo en colonia, doble confirmación que se reinicia al modificar oferta, sin comerciar monedas inicialmente. Los planos ya aprendidos no se pierden. Peces y minerales reaparecen en ubicaciones de aparición prediseñadas; el terreno es fijo.

## 13. Herramientas y vehículos
**CONFIRMADO.** Linterna, arpón para pesca, y herramientas para escapar y explorar. Vehículos desbloqueados progresivamente; submarinos dañados quedan averiados y requieren recuperación y reparación.

**PROPUESTO.** Progresión: buceo a pie → propulsor → minisubmarino → submarino cooperativo. Propulsor no ofrece aire ni protección de presión. Minisubmarino de 1 ocupante, 300 m y 16 espacios iniciales; vehículo cooperativo 4 ocupantes, 700 m y 48 espacios antes de mejoras. Mejoras de casco, batería, carga y reducción de ruido. Vehículos emiten ruido y pueden atraer fauna. Estados operativo, dañado, crítico, averiado, recuperado. Reparación de campo limitada; reparación completa o rescate de taller con costo. Parámetros numéricos y funcionamiento de remolque **PENDIENTES**.

## 14. Mapa, balizas y navegación
**CONFIRMADO.** Cada jugador revela su propio mapa visitando zonas; compañeros comparten **balizas**, no geografía descubierta. Marcadores manuales propios y posición exacta automática para el contenedor de muerte. Mapa fijo sin generación procedural.

**PROPUESTO.** 10 balizas manuales iniciales (ubicación, peligro, recurso, ruta). Marcadores de recuperación no ocupan ese cupo. Sonar local, no revela todo el mapa a distancia. Brújula, mapa portátil y balizas de seguimiento. Descubrimientos geográficos permanentes por jugador; los POI aparecen cuando se encuentran. Compartir una baliza no transfiere desbloqueos ni planos.

## 15. Interfaz, accesibilidad y controles
**PROPUESTO.** HUD de buceo minimalista: oxígeno (tiempo restante), salud, batería, profundidad y advertencias de presión. En submarino: casco, energía, aire, profundidad, estado de motor. En isla: Coins, tiendas, almacén. Menús: inventario, mapa, taller, mercado, expedición, registro. Alertas por sonido, texto/iconos y señales visuales accesibles (no solo color). PC: WASD, espacio ascender, Ctrl descender, E interactuar, F linterna, Tab inventario; controles táctiles separados en móvil. Sin minimapa que revele enemigos constantemente.

## 16. Primera versión jugable (MVP)
**PROPUESTO, sujeto a alcance.** Una isla compacta con puerto/mercado/taller; arrecifes y naufragios completos; seis especies capturables; dos depredadores menores, un cazador de emboscada y un leviatán de borde; tres trajes; propulsor y minisubmarino; herramientas básicas; ciclo día/noche con lluvia ocasional; contenedores persistentes y rescate cooperativo; comercio limitado y fabricación; un misterio opcional; mapa personal y balizas. Las fosas extensas, vehículos grandes y más historias quedan para fases futuras. **Restricción:** el MVP debe contener un bucle entero de progresión y un límite temporal de mapa creíble, aunque otras regiones solo se desarrollen después.

## 17. Calidad, seguridad y equidad
**PROPUESTO.** Validación de inventarios, compras, transacciones, contenedores y daños en servidor; diseño anti-duplicación; guardado de estado confiable con reintentos y manejo de errores; rendimiento móvil; criaturas simuladas eficientemente a distancia; suavizar efectos de oscuridad y proporcionar alternativas visuales a alarmas auditivas. No hacer pagos reales obligatorios para recuperar bienes perdidos. Evitar muertes no anticipadas y bucles de frustración.

## 18. Pendientes antes de pasar a programación
1. **APROBAR O AJUSTAR** reglas cuantitativas de oxígeno/salud/presión, incapacitación y tamaño del equipo.
2. Definir energía y baterías: duración, recarga y consumo de herramientas.
3. Resolver con precisión fallos de recuperación: contenedores inaccesibles y política del registro inactivo.
4. Acordar medidas físicas del mapa, velocidad de nado y tiempos de travesía; luego equilibrar tanque de 6 min.
5. Establecer lista nominal de 6 peces, 3 depredadores y leviatán; tabla de aparición, comportamientos y drop.
6. Definir catálogo mínimo de ítems, fórmulas de precios, venta, costes y planos concretos.
7. Decidir si `Stage` se usa como estadística de progreso tecnológico o se sustituye por otra métrica.
8. Resolver coordinación del tiempo global entre servidores, persistencia de vehículos y reglas de grupo.
9. Diseñar wireframes definitivos de mapa, inventario, taller, HUD de submarino e intercambio.
10. Revisar el MVP y firmar el alcance; no escribir scripts ni modelos definitivos antes de esta revisión.

## 19. Notas respecto al repositorio actual
La estructura conocida del repositorio `WwwNoOne/Roblox_conect` incluye `game_designs/GDD.md`, `game_designs/assets/ui_design.md`, `game_designs/assets/model_design.md`, `AGENTS.md`, `arranque.md`, `Docs/CLAUDE.md` y `Docs/CODEX.md`. Los dos archivos de diseño de assets estaban vacíos al revisarlos. `AGENTS.md` asigna programación Luau a Claude y modelado 3D a Codex; este documento respeta esa separación de funciones. El documento actual **no fue escrito en GitHub**.