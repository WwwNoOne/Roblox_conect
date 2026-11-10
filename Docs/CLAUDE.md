# Claude Code Guidelines (Roblox Luau)

- Usar modo estricto de tipo (`--!strict`) en todos los ModuleScripts.
- Separar estrictamente la lógica de ServerScriptService y ReplicatedStorage.
- Limitar las llamadas a RemoteEvents para no saturar la red (máximo 20 Hz por cliente).
- Estilo de código: PascalCase para servicios y módulos, camelCase para funciones locales.