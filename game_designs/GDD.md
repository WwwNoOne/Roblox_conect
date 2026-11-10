### Core Loop: Ocean Depth Explorer

1. **Acción (Riesgo):** Bucear en zonas de naufragios para capturar peces y recolectar tesoros, gestionando el oxígeno y esquivando criaturas hostiles.
2. **Recompensa (Loot & Escape):** Retornar a la superficie con el inventario lleno de botín antes de quedarse sin oxígeno o morir.
3. **Inversión (Progreso):** Vender el botín en el puerto para comprar mejoras (tanques de oxígeno, trajes de presión, luz y arpones).
4. **Retorno (Nuevo Desafío):** Descender a fosas oceánicas más profundas para acceder a nuevos naufragios y especies de mayor valor.
## 2. Mecánicas de Juego (Gameplay & Control)

### Movimiento y Controles
* **Cámara:** [tercera y primera persona]
* **Controles PC:** `WASD` (Movimiento), `Espacio` (Salto), `E` (Interacción)
* **Controles Mobile:** Touch Joystick + Botones de pantalla dedicados

### Habilidades y Reglas
* **Mecánica A:** [Arpon para capturar los peces y una lampara para ilimunar cuando se haga de noche]
* **Mecánica B:** [bestias marinas que merodean la zona evita que te atrapen mientras recolectas tesoros y  peces y no te quedes sin oxigeno  al inicio el oxigeno te permite estar  6 minutos bajo el agua]

---

## 3. Arquitectura de Datos & Eventos (Roblox Spec)

### Leaderstats (Datos Visibles)
| Nombre Variable | Tipo | Valor Inicial | Descripción |
| :--- | :--- | :--- | :--- |
| `Coins` | IntValue | 0 | Moneda principal del juego |
| `Stage` | IntValue | 1 | Nivel actual alcanzado |

### DataStore (Guardado Permanente)
* **Clave de guardado:** `PlayerSave_v1`
* **Tablas a guardar:** `{Coins, Stage, InventoryTable}`

### Eventos Cliente-Servidor (RemoteEvents / RemoteFunctions)
* `RequestPurchase` (RemoteFunction): Cliente solicita comprar ítem -> Servidor valida saldo y entrega.
* `UpdateHUD` (RemoteEvent): Servidor notifica cambio de stats al cliente.
