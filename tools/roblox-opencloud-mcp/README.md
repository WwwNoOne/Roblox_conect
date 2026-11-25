# MCP: roblox-opencloud

Servidor MCP local que permite a los agentes **subir y gestionar assets en tu cuenta de Roblox** con una API key de Open Cloud, sin tocar el Creator Hub a mano.

- Runtime: Python (`uv run`, dependencias declaradas dentro del script).
- Protocolo: MCP por stdio, SDK oficial `mcp`.
- Sin dependencias de Studio: funciona con Studio cerrado.

## Instalación (ya hecha)

1. Servidor: `tools/roblox-opencloud-mcp/server.py`.
2. Credenciales: `~/.config/opencode/roblox-opencloud.env` (permisos `600`, fuera del repo).
3. Registro: `~/.config/opencode/opencode.json`, bajo `mcp.servers.roblox-opencloud`.

Comprobar que OpenCode lo ve:

```sh
opencode mcp list        # -> ✓ roblox-opencloud  connected
```

## Configurar la API key

1. Entra en <https://create.roblox.com/dashboard/credentials> → **Open Cloud** → **API Keys** → *Create API Key*.
2. **Access Permissions**: añade `assets` con **Read** y **Write**.
3. **Security**: restringe por IP. Si tu IP es dinámica, tendrás que usar `0.0.0.0/0` o rehacer la key cuando cambie (los `401` vienen de aquí la mitad de las veces).
4. Copia la key y rellena el archivo:

```sh
$EDITOR ~/.config/opencode/roblox-opencloud.env
```

```ini
ROBLOX_API_KEY=aqui_la_key
ROBLOX_USER_ID=12345678          # tu User ID; los assets quedan a tu nombre
# ROBLOX_GROUP_ID=9876543        # alternativa: assets a nombre de un grupo (gana sobre el user)
```

5. Verifica sin subir nada:

```
opencloud_status()      # -> key_check: "accepted (probe answered 404)"
```

`accepted` con 404/400 es lo normal: la sonda consulta un asset que no existe solo para ver si la key pasa.

## Herramientas

| Tool | Para qué |
| --- | --- |
| `opencloud_status` | Comprueba key, creator, carpetas permitidas y si la key responde. |
| `upload_asset` | Sube un archivo y devuelve `assetId` + `rbxassetid://`. |
| `get_operation` | Consulta una subida que quedó en curso (no re-subas el archivo). |
| `get_asset` | Metadatos: tipo, nombre, estado de moderación, creator, versión. |
| `list_asset_versions` | Historial de versiones, la más nueva primero. |
| `update_asset` | Cambia nombre/descripción y/o sube una revisión nueva del contenido. |
| `archive_asset` | Archiva o restaura (`restore=true`). Solo tipos archivables: Model, Animation, Audio. **Las imágenes y decals no se archivan** (`not an archivable asset type`): renómbralas con `update_asset` y bórralas a mano en Creator Hub → Development Items. |

### Tipos aceptados

| `asset_type` | Extensiones |
| --- | --- |
| `Model` | `.glb` `.gltf` `.fbx` |
| `Image` | `.png` `.jpg` `.jpeg` `.gif` |
| `Decal` | `.png` `.jpg` `.jpeg` |
| `Audio` | `.mp3` `.ogg` `.flac` `.wav` |

## Las tres trampas que este servidor evita

1. **`Mesh` no acepta `.glb`/`.fbx`.** Un `.glb` se sube como `assetType: "Model"`. Enviarlo como `Mesh` devuelve un error que parece de permisos, así que se rechaza antes de salir.
2. **Una textura va como `Image`, nunca como `Decal`.** Ambas suben y ambas salen *Approved*, pero el id del `Decal` es distinto del de la imagen que envuelve: asignarlo a `MeshPart.TextureID` no da error y el modelo se ve gris.
3. **Un 200 no es un asset.** `POST /assets/v1/assets` acepta el trabajo; el `assetId` solo existe cuando la operación termina. Por eso `upload_asset` hace polling y, si tarda, devuelve `operation_id` para `get_operation` en vez de duplicar la subida.

## Estado verificado (2026-11-25)

Prueba real contra la cuenta, no simulada:

| Comprobación | Resultado |
| --- | --- |
| Key aceptada | `404` en `GET /assets/v1/assets/1` con la key real vs `401` con una falsa |
| Creator | `userId: 9514396368` (tomado del claim `ownerId` del token) |
| Subida | `upload_asset` de un PNG 1×1 → `assetId=98343397841439`, `moderationState: Approved` |
| Renombrado | `update_asset` → 200 y nombre actualizado |
| Guardrails | ruta fuera del repo rechazada; `assetType: Mesh` rechazado |

El asset de prueba quedó como `MCP test 1x1 (borrar)` porque **las imágenes no se pueden archivar por API**.

## Ojo con la caducidad de la key

La key que muestra Creator Hub no es una cadena opaca: es `keyid` (48 caracteres) + `base64(JWT)`. El JWT lleva los claims `aud`, `iss`, `baseApiKey` (= el keyid), `ownerId`, `iat`, `nbf` y `exp`. Comprobado el 2026-11-25:

| Valor probado como `x-api-key` | Resultado |
| --- | --- |
| keyid de 48 caracteres solo | `401 Invalid API Key` |
| string completo | `404` (autentica) |

Es decir, lo que hay que guardar es el **string completo**, y la caducidad viaja dentro de su firma: `iat` era la hora de creación y `exp` exactamente una hora después.

Si la key caduca, todo responde `401` aunque el archivo de credenciales esté intacto. Al crear la key en Creator Hub pon la **Expiration** en *Never* o en una fecha lejana, y verifica el `exp` del string nuevo antes de darlo por bueno:

```sh
python3 -c "
import base64,json,datetime
k=open('/home/miranda/.config/opencode/roblox-opencloud.env').read().split('ROBLOX_API_KEY=')[1].split()[0]
p=k[48:]; p=base64.b64decode(p+'='*(-len(p)%4)).decode().split('.')[1]
c=json.loads(base64.urlsafe_b64decode(p+'='*(-len(p)%4)))
print('expira:', datetime.datetime.fromtimestamp(c['exp']), '| owner:', c.get('ownerId'))"
```

Cambiar la caducidad de una key ya creada **no reescribe el `exp` del string que ya tienes**: la firma se generó al crearla. Si el `exp` del string ya pasó, genera una key nueva.

## Guardrails
- **Carpeta permitida**: solo se suben archivos dentro del repo (`ROBLOX_UPLOAD_ROOT`, separado por `:` para añadir más). La ruta se resuelve con `realpath`, así que un symlink no escapa. Así un agente no puede mandar `~/.ssh/id_rsa` a un servicio externo.
- **Tamaño**: 20 MB por archivo, el límite de Roblox. Un mesh legal para Roblox pesa mucho menos: si te pasas, falta decimar.
- **La key no se escribe nunca** en la config ni en los logs: solo se lee del archivo `600` o del entorno, y `opencloud_status` la muestra enmascarada.

## Uso desde un agente

```
upload_asset(file_path="assets_build/exports/Caja_Industrial_Rectangular.glb",
             asset_type="Model", display_name="Caja industrial")
# -> assetId=123456789 -> rbxassetid://123456789
```

Después, el `assetId` se usa en Studio: `MeshPart.MeshId`, `ImageLabel.Image`, `Sound.SoundId`, etc. Si el asset es un `Model`, se inserta desde el **Toolbox → Inventory** o con `InsertService:LoadAsset(assetId)`.

## Problemas típicos

| Síntoma | Causa real |
| --- | --- |
| `401` | Key caducada, revocada, o la IP del equipo no está en el allowlist. |
| `403` | Falta el scope `assets:write` o el `creator` no es tuyo. |
| `400` vago al subir | `assetType` no corresponde a la extensión. |
| Modelo gris tras texturizar | Subiste la textura como `Decal`; vuelve a subirla como `Image`. |
| `operation ... still not done` | Moderación lenta. Usa `get_operation`, no resubas. |

## Moverlo o hacerlo global

La config global apunta a la ruta absoluta del repo. Si mueves el proyecto, actualiza `command`/`cwd` en `~/.config/opencode/opencode.json`. Para que funcione en cualquier proyecto, copia el script fuera del repo y apunta ahí:

```sh
mkdir -p ~/.config/opencode/mcp && cp server.py ~/.config/opencode/mcp/roblox-opencloud.py
```

Sin key configurada el servidor igual arranca y responde `opencloud_status` diciendo qué falta, así que nunca rompe el arranque de OpenCode.
