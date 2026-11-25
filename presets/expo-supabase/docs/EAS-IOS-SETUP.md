# Build de tienda iOS + TestFlight

`eas.json` ya tiene el perfil **`production`** con `distribution: store` (build `.ipa` para App
Store Connect / TestFlight) y el bloque **`submit.production.ios`**. Falta **una sola vez**:
autenticar con Apple (crea las credenciales en EAS) y rellenar 3 valores para el submit.

## 0) Variables de entorno en EAS (no en el repo)

Las `EXPO_PUBLIC_*` viven en EAS environments (`development`, `preview`, `production`), nunca
en `eas.json` ni `app.config.ts`:

```bash
eas env:create --scope project --environment production --name EXPO_PUBLIC_SUPABASE_URL --value https://<ref>.supabase.co --visibility plaintext
eas env:create --scope project --environment production --name EXPO_PUBLIC_SUPABASE_ANON_KEY --value <anon-key> --visibility sensitive
# repite para preview y development
```

## 1) Rellenar `submit.production.ios` en `eas.json`

| Campo | Qué es | Dónde sacarlo |
|---|---|---|
| `appleId` | Email del Apple ID del Apple Developer Program | tu cuenta Apple |
| `ascAppId` | **App ID numérico** en App Store Connect | App Store Connect → tu app → App Information → "Apple ID" |
| `appleTeamId` | **Team ID** de 10 caracteres | developer.apple.com → Membership → Team ID |

> Si la app aún no existe en App Store Connect, créala primero (Apps → +) con el bundle id que
> declara `app.config.ts` (`APP_BUNDLE_ID`). Luego copia su Apple ID numérico a `ascAppId`.

## 2) Build de tienda (interactivo la primera vez: crea credenciales iOS)

```bash
eas build -p ios --profile production
```

La primera vez pide **iniciar sesión con tu Apple ID** (+ 2FA) y crea en EAS el Distribution
Certificate y el Provisioning Profile de tienda. Después puede correr `--non-interactive`.

## 3) Subir a TestFlight

```bash
eas submit -p ios --profile production --latest
```

Al terminar, la build aparece en **App Store Connect → TestFlight** tras unos minutos de
"Processing". Desde ahí se agrega a un grupo de testers.

## Notas

- **`preview` es interno (ad-hoc)**: instala por link/UDID, no va a TestFlight. Requiere
  registrar el UDID del dispositivo.
- El **versionado** lo gestiona EAS (`appVersionSource: remote` + `autoIncrement` en
  production). La versión de marketing sale de `app.config.ts` (`version`).
- Android `production` genera un **.aab** (Play Store). El APK de reparto directo sale del
  perfil `preview`.
