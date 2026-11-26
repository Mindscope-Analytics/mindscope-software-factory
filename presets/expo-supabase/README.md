# Preset `expo-supabase`

App móvil + web con **Expo SDK 54**, **expo-router**, **TypeScript** y **Supabase** (auth por
email + código OTP). Se aplica con:

```bash
bash scripts/apply-preset.sh expo-supabase --module supabase-base
pnpm install
cp .env.example .env   # rellena los valores locales (el archivo está ignorado por git)
pnpm start
```

## Qué trae

| Ruta | Qué es |
|---|---|
| `app/` | expo-router: `index` (gate de sesión), `auth/login`, `auth/verify`. |
| `hooks/useAuth.tsx` | Proveedor de sesión; `requestCode` / `verifyCode` / `signOut`. |
| `lib/supabase.ts` | Cliente con AsyncStorage (nativo) y variables validadas por Zod (`lib/env.ts`). |
| `lib/validators.ts` | Email, OTP y traducción de errores de Auth a español. |
| `tests/` | jest-expo; ejemplo sobre lógica pura. |
| `e2e/` + `playwright.config.ts` | Humo web sobre `expo export -p web`. |
| `.maestro/smoke.yaml` | Humo móvil con Maestro. |
| `eas.json` | Perfiles `development`, `preview` (APK, internal), `production` (store). **Cero valores**: cada perfil declara su `environment` de EAS. |
| `app.config.ts` | Identidad por variables (`APP_NAME`, `APP_SLUG`, `APP_SCHEME`, `APP_BUNDLE_ID`), `owner: mindscopeanalytics`, web como SPA. |
| `assets/` | Placeholders neutros; sustitúyelos (ver `assets/README.md`). |
| `docs/EAS-IOS-SETUP.md`, `docs/android-local-build.md` | Runbooks de TestFlight y build local. |
| `ci/steps.yml` | Pasos de CI que `apply-preset.sh` inserta en `.github/workflows/ci.yml`. |

## Variables de entorno

Solo `EXPO_PUBLIC_*` (públicas; la RLS pone el alcance). En local van en el archivo de entorno
ignorado por git; en builds, en **EAS environments**:

```bash
eas env:create --scope project --environment preview --name EXPO_PUBLIC_SUPABASE_URL --value https://<ref>.supabase.co --visibility plaintext
eas env:create --scope project --environment preview --name EXPO_PUBLIC_SUPABASE_ANON_KEY --value <anon-key> --visibility sensitive
```

Jamás `SUPABASE_SERVICE_ROLE_KEY` en la app: vive solo en Edge Functions o servidor.

## Scripts

```bash
pnpm lint          # expo lint (eslint-config-expo)
pnpm typecheck     # tsc --noEmit
pnpm test          # jest
pnpm export:web    # expo export -p web → dist/ (+ _redirects para SPA)
pnpm e2e:web       # playwright sobre dist/
pnpm e2e:mobile    # maestro test .maestro/
```

## Deploy web: Cloudflare Pages

El export de Expo web es estático; se publica en **Cloudflare Pages** con wrangler (sin
Railway en este preset).

```bash
# una vez: crear el proyecto (o desde el dashboard de Cloudflare)
npx -y wrangler@4 login
npx -y wrangler@4 pages project create <nombre> --production-branch main

# cada deploy
pnpm export:web
CF_PAGES_PROJECT=<nombre> pnpm deploy:web
```

La app web es una SPA (`web.output: 'single'` en `app.config.ts`); `pnpm export:web` genera
`dist/_redirects` con `/* /index.html 200` para que Cloudflare Pages sirva las rutas de
expo-router. En CI, usa `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID` como secrets del
repo (nunca en el código).

## Builds nativos

- iOS / TestFlight: `docs/EAS-IOS-SETUP.md`.
- Android local sin créditos: `docs/android-local-build.md`.
- APK interno en la nube: `eas build -p android --profile preview`.

## Primer arranque con Supabase local

```bash
supabase start            # módulo supabase-base
# EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321 y la anon key que imprime `supabase status`
pnpm start
# El código OTP llega al buzón local: http://127.0.0.1:54324
```
