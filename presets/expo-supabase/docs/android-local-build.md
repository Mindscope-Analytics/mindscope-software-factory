# Build local de Android (sin consumir créditos de EAS)

`eas build --local` compila en tu máquina con la misma configuración que la nube. Útil para
APKs de prueba rápidos o cuando se agotan los builds gratuitos del mes.

## Requisitos (una vez)

- JDK 17 (`sdk install java 17-tem` con SDKMAN, o el de Android Studio).
- Android SDK + `ANDROID_HOME` apuntando a él (Android Studio lo instala).
- `eas-cli` (`npm i -g eas-cli`) y sesión (`eas login`).
- En WSL: compila dentro de WSL; el APK resultante se copia a Windows para instalarlo.

## APK interno (perfil `preview`)

```bash
# Las EXPO_PUBLIC_* salen del environment "preview" de EAS:
eas build -p android --profile preview --local --output ./build/app-preview.apk
```

Instalar en un dispositivo por USB:

```bash
adb install -r ./build/app-preview.apk
```

## AAB de tienda (perfil `production`)

```bash
eas build -p android --profile production --local --output ./build/app-production.aab
```

## Problemas comunes

| Síntoma | Causa | Arreglo |
|---|---|---|
| `SDK location not found` | falta `ANDROID_HOME` | `export ANDROID_HOME=$HOME/Android/Sdk` y reintenta |
| Falla por memoria en WSL | Gradle sin RAM | `.wslconfig` con `memory=8GB` y `wsl --shutdown` |
| `Unsupported class file major version` | JDK distinto de 17 | usa JDK 17 |
| Variables `EXPO_PUBLIC_*` vacías | perfil sin `environment` o env no creado en EAS | `eas env:list --environment preview` |
