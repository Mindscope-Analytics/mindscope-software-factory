# ADR-0001: Node 22 fijo y pnpm con workspaces

- Estado: Aceptado
- Fecha: 2026-11-24
- Decisores: Arturo Magdiel (owner)

## Contexto

La auditoría HO-001 encontró tres versiones de Node en un mismo repo (CI 18.17, `engines`
≥20.9, `.node-version` 22) y dos apps acopladas por `watchFolders` sin workspaces. Ninguno de
los repos existentes tenía gestor de paquetes común.

## Opciones consideradas

1. npm con workspaces: sin instalación extra, pero lento y sin `engine-strict` fiable.
2. pnpm con workspaces: rápido, `engine-strict`, `node-linker=hoisted` resuelve Metro.
3. pnpm + turbo: añade caché de tareas, pero es complejidad innecesaria en v0.1.

## Decisión

Node 22 en todas partes: `.nvmrc = 22`, `engines ">=22 <23"`, `setup-node` con
`node-version-file`. Gestor: pnpm con `pnpm-workspace.yaml` y sin turbo en v0.1.

## Consecuencias

- Positivas: una sola versión que verificar; `pnpm install` falla si la versión no coincide.
- Negativas: Expo necesita `node-linker=hoisted` en `.npmrc`; se documenta en el preset.
- Reversa: cambiar `.nvmrc` y `engines` en un solo PR; CI lo propaga.

## Verificación

```bash
cat .nvmrc            # 22
jq -r .engines.node package.json   # >=22 <23
grep -n "node-version-file" .github/workflows/*.yml
```
