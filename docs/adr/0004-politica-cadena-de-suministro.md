# ADR-0004: Política de cadena de suministro en pnpm

- Estado: Aceptado
- Fecha: 2026-11-24
- Decisores: Arturo Magdiel (owner)

## Contexto

Semgrep (`p/default`) recomienda tres ajustes de pnpm: `minimumReleaseAge: 10080` (7 días),
`trustPolicy: no-downgrade` y `blockExoticSubdeps: true`, además de `cooldown` en Dependabot.
Al probarlos con el preset `expo-supabase` (Expo SDK 54):

- `minimumReleaseAge: 10080` falla la instalación: `@babel/helpers@7.29.15` y otros parches
  publicados hace 4 días son las únicas versiones que satisfacen los rangos de Expo.
- `trustPolicy: no-downgrade` rechaza `@expo/cli@54.0.28` y `@expo/config-plugins@54.0.6`
  por "trust downgrade" (cambio en la procedencia de publicación de Expo), y
  `undici-types@6.21.0` vía `@types/node`.
- `blockExoticSubdeps: true` no rompe nada.

## Decisión

- `minimumReleaseAge: 1440` (24 h): cubre la ventana típica en que un paquete comprometido
  se detecta y retira, sin bloquear los trenes de parches de Expo/Babel.
- `blockExoticSubdeps: true`.
- `trustPolicy: no-downgrade` **no** se activa en v0.1; se anota para revisar en v0.2 cuando
  Expo publique con procedencia estable.
- Dependabot con `cooldown: default-days: 7` (ahí sí aplica: solo retrasa PRs de actualización).
- Las dos desviaciones llevan `# nosemgrep` con el id de la regla, para que el hallazgo no
  reaparezca y la excepción quede visible en el archivo.

## Consecuencias

- Positivas: `pnpm install` funciona en proyectos nuevos; se bloquean fuentes exóticas.
- Negativas: una ventana de 24 h en lugar de 7 días. Mitigación: Dependabot con cooldown de
  7 días es quien propone las actualizaciones, así que en la práctica las versiones nuevas
  llegan al repo con una semana de antigüedad.
- Reversa: subir `minimumReleaseAge` y activar `trustPolicy` en `pnpm-workspace.yaml`.

## Verificación

```bash
grep -nE "minimumReleaseAge|blockExoticSubdeps" pnpm-workspace.yaml
grep -n "cooldown" .github/dependabot.yml
pnpm install --frozen-lockfile
```
