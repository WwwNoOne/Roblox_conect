# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=1.9,<2", "httpx>=0.27"]
# ///
"""MCP server for Roblox Open Cloud (assets).

Lets an agent upload and manage assets on your Roblox account with an Open Cloud
API key: models (.glb/.gltf/.fbx), images (.png/.jpg), audio (.mp3/.ogg/.flac)
and metadata operations (get, update, archive, versions, operations).

Design notes that come from real failures with this API:

1. `assetType: "Mesh"` only takes Roblox-native content. A .glb/.gltf/.fbx goes
   up as `Model`. Sending a .glb as `Mesh` returns something that reads like a
   permissions error, so it is refused up front here.
2. A texture must be uploaded as `Image`, not `Decal`. Both succeed, but only the
   Image id works in `MeshPart.TextureID`; a Decal id renders grey with no error.
3. A 200 on POST /assets/v1/assets means the job was *accepted*, not finished.
   The asset id only exists once the operation completes, so the upload polls by
   default instead of reporting success off the first response.

Configuration (real environment wins over the env file):

    ROBLOX_API_KEY   Open Cloud key with asset:read + asset:write
    ROBLOX_USER_ID   creator id (assets filed under a user)
    ROBLOX_GROUP_ID  creator id (assets filed under a group; wins over user)
    ROBLOX_ENV_FILE  KEY=VALUE file to read the above from
                     (default: ~/.config/opencode/roblox-opencloud.env)
    ROBLOX_UPLOAD_ROOT  folders uploads may read from, pathsep separated
                        (default: the repository this file lives in)
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
from pathlib import Path

from mcp.server.fastmcp import FastMCP

ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATION_URL = "https://apis.roblox.com/assets/v1/operations/{op}"

DEFAULT_ENV_FILE = Path.home() / ".config" / "opencode" / "roblox-opencloud.env"

# Roblox assigns the id later, so an accepted upload is not a finished one.
MAX_UPLOAD_MB = 20

# Content types Roblox accepts, by extension. A wrong one is a vague 400.
CONTENT_TYPES = {
    ".glb": "model/gltf-binary",
    ".gltf": "model/gltf+json",
    ".fbx": "model/fbx",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".mp3": "audio/mpeg",
    ".ogg": "audio/ogg",
    ".flac": "audio/flac",
    ".wav": "audio/wav",
}

# assetType -> extensions Roblox actually accepts for it.
ALLOWED_TYPES = {
    "Model": {".glb", ".gltf", ".fbx"},
    "Image": {".png", ".jpg", ".jpeg", ".gif"},
    "Decal": {".png", ".jpg", ".jpeg"},
    "Audio": {".mp3", ".ogg", ".flac", ".wav"},
}

mcp = FastMCP("roblox-opencloud")


# --------------------------------------------------------------------------- #
# configuration
# --------------------------------------------------------------------------- #

def _read_env_file() -> dict[str, str]:
    path = Path(os.environ.get("ROBLOX_ENV_FILE") or DEFAULT_ENV_FILE).expanduser()
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def _config() -> dict[str, str]:
    from_file = _read_env_file()
    merged = {**from_file, **{k: v for k, v in os.environ.items() if k.startswith("ROBLOX_")}}
    return {k: v for k, v in merged.items() if v}


def _api_key() -> str:
    key = _config().get("ROBLOX_API_KEY", "")
    if not key:
        raise RuntimeError(
            "ROBLOX_API_KEY is not set. Put it in "
            f"{os.environ.get('ROBLOX_ENV_FILE') or DEFAULT_ENV_FILE} "
            "as ROBLOX_API_KEY=... (chmod 600), or export it. "
            "The key needs the asset:read and asset:write scopes."
        )
    return key


def _creator(explicit: str | None = None) -> dict[str, str]:
    """Resolve the creationContext creator: 'user:<id>' or 'group:<id>'."""
    if explicit:
        kind, _, value = explicit.partition(":")
        kind = kind.lower().strip()
        value = value.strip()
        if kind not in ("user", "group") or not value.isdigit():
            raise RuntimeError(
                f"creator must look like 'user:123456' or 'group:7890', got {explicit!r}"
            )
        return {"groupId" if kind == "group" else "userId": value}

    cfg = _config()
    if cfg.get("ROBLOX_GROUP_ID"):
        return {"groupId": cfg["ROBLOX_GROUP_ID"]}
    if cfg.get("ROBLOX_USER_ID"):
        return {"userId": cfg["ROBLOX_USER_ID"]}
    raise RuntimeError(
        "No creator configured. Set ROBLOX_USER_ID (or ROBLOX_GROUP_ID) in the env "
        "file, or pass creator='user:<id>' to the tool."
    )


def _repo_root() -> Path:
    # tools/roblox-opencloud-mcp/server.py -> repository root
    return Path(__file__).resolve().parents[2]


def _upload_roots() -> list[Path]:
    raw = _config().get("ROBLOX_UPLOAD_ROOT", "")
    if raw:
        roots = [Path(p).expanduser() for p in raw.split(os.pathsep) if p.strip()]
    else:
        roots = [_repo_root()]
    return [p.resolve() for p in roots]


def _resolve_upload_path(file_path: str) -> Path:
    """Refuse anything outside the allowed folders, resolved through realpath.

    Uploading sends a local file to an external service and, for models, cannot
    be undone. The agent should not be able to pick an arbitrary path.
    """
    path = Path(file_path).expanduser()
    if not path.is_absolute():
        path = (_repo_root() / path).resolve()
    else:
        path = path.resolve()
    if not path.is_file():
        raise RuntimeError(f"file not found: {path}")

    roots = _upload_roots()
    if not any(path == r or r in path.parents for r in roots):
        allowed = ", ".join(str(r) for r in roots)
        raise RuntimeError(
            f"{path} is outside the folders uploads may read from ({allowed}). "
            "Copy it inside, or add the folder to ROBLOX_UPLOAD_ROOT."
        )

    size_mb = path.stat().st_size / 1e6
    if size_mb > MAX_UPLOAD_MB:
        raise RuntimeError(
            f"{path.name} is {size_mb:.1f} MB, over the {MAX_UPLOAD_MB} MB per-upload "
            "limit. A Roblox-legal mesh is normally far smaller: decimate first."
        )
    return path


def _content_type(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix not in CONTENT_TYPES:
        raise RuntimeError(
            f"no content type known for {suffix}. Known: {', '.join(sorted(CONTENT_TYPES))}"
        )
    return CONTENT_TYPES[suffix]


def _check_asset_type(asset_type: str, path: Path) -> None:
    if asset_type == "Mesh":
        raise RuntimeError(
            "assetType 'Mesh' takes Roblox-native content only. Upload a .glb/.gltf/.fbx "
            "as assetType 'Model'."
        )
    if asset_type not in ALLOWED_TYPES:
        raise RuntimeError(
            f"assetType {asset_type!r} is not uploadable here. Use one of "
            f"{', '.join(ALLOWED_TYPES)}."
        )
    suffix = path.suffix.lower()
    if suffix not in ALLOWED_TYPES[asset_type]:
        allowed = ", ".join(sorted(ALLOWED_TYPES[asset_type]))
        raise RuntimeError(f"assetType {asset_type} does not take {suffix}. It takes {allowed}.")


def _headers() -> dict[str, str]:
    return {"x-api-key": _api_key()}


# --------------------------------------------------------------------------- #
# http helpers
# --------------------------------------------------------------------------- #

def _post(url: str, *, key: str, request: dict, file_path: Path | None, method: str = "POST") -> dict:
    import httpx

    files: dict[str, tuple] = {
        "request": (None, json.dumps(request), "application/json"),
    }
    if file_path is not None:
        files["fileContent"] = (
            file_path.name,
            file_path.read_bytes(),
            _content_type(file_path),
        )
    resp = httpx.request(
        method,
        url,
        headers={"x-api-key": key},
        files=files,
        timeout=180.0,
    )
    return _handle(resp)


def _handle(resp) -> dict:
    if resp.status_code >= 400:
        hint = ""
        if resp.status_code in (401, 403):
            hint = (
                "\nA 401/403 here is as often a wrong assetType or a missing scope as a "
                "wrong key. Confirm assetType, then the key's assets:write scope and its "
                "IP allowlist."
            )
        raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:800]}{hint}")
    if not resp.text.strip():
        return {}
    try:
        return resp.json()
    except ValueError:
        return {"raw": resp.text[:2000]}


def _operation_id(body: dict) -> str:
    op = body.get("operationId") or body.get("path", "").rsplit("/", 1)[-1]
    if not op:
        raise RuntimeError(f"no operation id in response: {json.dumps(body)[:600]}")
    return op


def _poll(op: str, key: str, wait_seconds: float) -> dict | None:
    """Wait for the operation. Returns the response, or None if still running."""
    import httpx

    deadline = time.time() + max(wait_seconds, 0)
    delay = 2.0
    while True:
        resp = httpx.get(OPERATION_URL.format(op=op), headers={"x-api-key": key}, timeout=60.0)
        body = _handle(resp)
        if body.get("done"):
            if "error" in body:
                raise RuntimeError(f"asset job failed: {json.dumps(body['error'])[:800]}")
            return body.get("response", body)
        if time.time() >= deadline:
            return None
        time.sleep(delay)
        delay = min(delay * 1.5, 10.0)


def _summary(line: str, payload: dict) -> str:
    return f"{line}\n\n{json.dumps(payload, indent=2)[:4000]}"


# --------------------------------------------------------------------------- #
# tools
# --------------------------------------------------------------------------- #

@mcp.tool()
def opencloud_status(verify_key: bool = True) -> str:
    """Report the current Open Cloud configuration and, optionally, whether the key is accepted.

    Use this first: it says which creator assets will be filed under, which folders
    uploads may read from, and whether the API key answers. An expired or revoked
    key, or a request from an IP the key does not allow, comes back as 401.
    """
    import httpx

    cfg = _config()
    report: dict = {
        "env_file": str(Path(os.environ.get("ROBLOX_ENV_FILE") or DEFAULT_ENV_FILE)),
        "env_file_exists": Path(
            os.environ.get("ROBLOX_ENV_FILE") or DEFAULT_ENV_FILE
        ).expanduser().is_file(),
        "api_key_set": bool(cfg.get("ROBLOX_API_KEY")),
        "api_key_preview": (
            f"{cfg.get('ROBLOX_API_KEY', '')[:6]}…{cfg.get('ROBLOX_API_KEY', '')[-4:]}"
            if cfg.get("ROBLOX_API_KEY")
            else None
        ),
        "upload_roots": [str(p) for p in _upload_roots()],
    }
    try:
        report["creator"] = _creator()
    except RuntimeError as exc:
        report["creator"] = None
        report["creator_problem"] = str(exc)

    if not cfg.get("ROBLOX_API_KEY"):
        report["key_check"] = "skipped: no key configured"
        return _summary("Open Cloud is NOT configured yet.", report)

    if not verify_key:
        report["key_check"] = "skipped: verify_key=False"
        return _summary("Open Cloud configuration.", report)

    # A probe against a non-existent asset: 401 means the key is the problem,
    # anything else means the key itself was accepted.
    try:
        resp = httpx.get(f"{ASSETS_URL}/1", headers={"x-api-key": cfg["ROBLOX_API_KEY"]}, timeout=30.0)
        if resp.status_code == 401:
            report["key_check"] = f"REJECTED (401): {resp.text[:300]}"
        elif resp.status_code == 403:
            report["key_check"] = (
                f"key accepted but not allowed (403): {resp.text[:300]} "
                "Check the assets:read scope and the key's IP allowlist."
            )
        else:
            report["key_check"] = f"accepted (probe answered {resp.status_code})"
    except Exception as exc:  # network problems should not look like a bad key
        report["key_check"] = f"could not probe: {exc}"

    return _summary("Open Cloud configuration.", report)


@mcp.tool()
def upload_asset(
    file_path: str,
    asset_type: str = "Model",
    display_name: str | None = None,
    description: str = "Uploaded by an Open Cloud agent.",
    creator: str | None = None,
    wait_seconds: int = 90,
) -> str:
    """Upload a local file to the Roblox account and return its assetId.

    file_path must be inside an allowed upload folder (see opencloud_status).
    asset_type is Model (.glb/.gltf/.fbx), Image (.png/.jpg), Decal or Audio.
    For a texture use Image, never Decal: a Decal id silently renders grey in
    MeshPart.TextureID. creator looks like 'user:123456' or 'group:7890' and
    defaults to ROBLOX_USER_ID / ROBLOX_GROUP_ID.

    Waits up to wait_seconds for the upload to finish. If it is still running,
    the operation_id comes back instead: call get_operation rather than
    uploading the file again, because re-uploading creates duplicate assets.
    """
    path = _resolve_upload_path(file_path)
    _check_asset_type(asset_type, path)
    key = _api_key()
    name = display_name or path.stem
    size_mb = path.stat().st_size / 1e6

    request = {
        "assetType": asset_type,
        "displayName": name,
        "description": description,
        "creationContext": {"creator": _creator(creator)},
    }
    body = _post(ASSETS_URL, key=key, request=request, file_path=path)
    op = _operation_id(body)
    result = _poll(op, key, wait_seconds)

    if result is None:
        return _summary(
            f"Upload of {path.name} ({size_mb:.2f} MB) as {asset_type} was accepted but is "
            f"still running. Poll it with get_operation(operation_id='{op}').",
            {"operation_id": op, "asset_type": asset_type, "display_name": name},
        )

    asset_id = result.get("assetId") or result.get("assetid")
    if not asset_id:
        return _summary(
            "The upload operation completed but returned no assetId. Read the body.",
            result,
        )
    return _summary(
        f"Uploaded {path.name} ({size_mb:.2f} MB) as {asset_type}. "
        f"assetId={asset_id} -> rbxassetid://{asset_id}",
        result,
    )


@mcp.tool()
def get_operation(operation_id: str, wait_seconds: int = 30) -> str:
    """Poll an upload or update operation and return the resulting assetId once done.

    Use this instead of uploading again when an earlier upload came back
    "still running".
    """
    key = _api_key()
    result = _poll(operation_id, key, wait_seconds)
    if result is None:
        return f"Operation {operation_id} is still running. Poll again in a few seconds."
    asset_id = result.get("assetId") or result.get("assetid")
    if asset_id:
        return _summary(f"assetId={asset_id} -> rbxassetid://{asset_id}", result)
    return _summary("Operation finished.", result)


@mcp.tool()
def get_asset(asset_id: str) -> str:
    """Read an asset's metadata: type, display name, moderation state, creator, versions."""
    import httpx

    resp = httpx.get(f"{ASSETS_URL}/{asset_id}", headers=_headers(), timeout=60.0)
    return _summary(f"Asset {asset_id}.", _handle(resp))


@mcp.tool()
def list_asset_versions(asset_id: str) -> str:
    """List the versions of an asset, newest first. Useful to confirm a re-upload landed."""
    import httpx

    resp = httpx.get(f"{ASSETS_URL}/{asset_id}/versions", headers=_headers(), timeout=60.0)
    body = _handle(resp)
    versions = body.get("assetVersions") or body.get("versions") or []
    return _summary(f"Asset {asset_id} versions ({len(versions)}).", body)


@mcp.tool()
def update_asset(
    asset_id: str,
    display_name: str | None = None,
    description: str | None = None,
    file_path: str | None = None,
    wait_seconds: int = 90,
) -> str:
    """Update asset metadata and/or replace its content with a new version.

    Changing the file creates a new version and takes a while: pass wait_seconds
    or use the returned operation_id with get_operation.
    """
    key = _api_key()
    # PATCH rejects a body without the id: "AssetId in url doesn't match the body".
    request: dict = {"assetId": asset_id}
    mask: list[str] = []
    if display_name is not None:
        request["displayName"] = display_name
        mask.append("displayName")
    if description is not None:
        request["description"] = description
        mask.append("description")

    path = _resolve_upload_path(file_path) if file_path else None
    if path is not None:
        # A new revision must be the same kind of content as the asset.
        _content_type(path)
    if not mask and path is None:
        raise RuntimeError("Nothing to update: pass display_name, description or file_path.")

    url = f"{ASSETS_URL}/{asset_id}"
    if mask:
        url = f"{url}?updateMask={','.join(mask)}"
    body = _post(url, key=key, request=request, file_path=path, method="PATCH")
    op = body.get("operationId") or body.get("path", "").rsplit("/", 1)[-1]
    if not op:
        return _summary(f"Asset {asset_id} metadata updated (no operation returned).", body)

    result = _poll(op, key, wait_seconds)
    if result is None:
        return _summary(
            f"Update of asset {asset_id} is running. Poll it with "
            f"get_operation(operation_id='{op}').",
            {"operation_id": op},
        )
    return _summary(f"Asset {asset_id} updated.", result)


@mcp.tool()
def archive_asset(asset_id: str, restore: bool = False) -> str:
    """Archive an asset (hidden from Creator Hub, not deleted) or restore it.

    Only Roblox's archivable types accept this: Models, Animations and Audio do;
    Images and Decals answer `Asset 123 is not an archivable asset type`. For
    those, delete them by hand in Creator Hub -> Development Items, and rename
    them first with update_asset so they are easy to find.
    """
    import httpx

    action = "restore" if restore else "archive"
    resp = httpx.post(
        f"{ASSETS_URL}/{asset_id}:{action}", headers=_headers(), timeout=60.0
    )
    if resp.status_code == 400 and "archivable" in resp.text:
        raise RuntimeError(
            f"Asset {asset_id} is not an archivable type (Images and Decals are not). "
            "Rename it with update_asset and delete it from Creator Hub -> "
            "Development Items by hand."
        )
    body = _handle(resp)
    return _summary(f"Asset {asset_id}: {action} requested.", body)


if __name__ == "__main__":
    if os.environ.get("OPENCLOUD_MCP_SELFTEST"):
        print(json.dumps({"ok": True, "roots": [str(p) for p in _upload_roots()]}))
        sys.exit(0)
    mcp.run()
