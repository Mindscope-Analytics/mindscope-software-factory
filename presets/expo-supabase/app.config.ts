import type { ExpoConfig, ConfigContext } from 'expo/config';

/**
 * Configuración dinámica de Expo.
 * Regla: aquí NO van valores de entorno (URLs, keys). Las variables EXPO_PUBLIC_* las
 * inyecta EAS (eas env) en build y el archivo de entorno local (ignorado por git) en
 * desarrollo. Lo que sí va aquí: identidad de la app, permisos, plugins y el owner de EAS.
 */
const APP_NAME = process.env.APP_NAME ?? 'App';
const SLUG = process.env.APP_SLUG ?? 'app';
const SCHEME = process.env.APP_SCHEME ?? 'app';
const BUNDLE_ID = process.env.APP_BUNDLE_ID ?? 'com.mindscopeanalytics.app';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: APP_NAME,
  slug: SLUG,
  owner: 'mindscopeanalytics',
  version: '0.1.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  scheme: SCHEME,
  userInterfaceStyle: 'automatic',
  newArchEnabled: true,
  splash: {
    image: './assets/splash-icon.png',
    resizeMode: 'contain',
    backgroundColor: '#ffffff',
  },
  ios: {
    supportsTablet: false,
    bundleIdentifier: BUNDLE_ID,
    infoPlist: {
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  android: {
    package: BUNDLE_ID,
    adaptiveIcon: {
      foregroundImage: './assets/adaptive-icon.png',
      backgroundColor: '#ffffff',
    },
    edgeToEdgeEnabled: true,
    predictiveBackGestureEnabled: false,
  },
  web: {
    bundler: 'metro',
    // 'single' = SPA: no se prerrenderiza en Node (evita módulos nativos en SSG). Cloudflare
    // Pages necesita entonces dist/_redirects con "/* /index.html 200" (lo genera export:web).
    output: 'single',
    favicon: './assets/favicon.png',
  },
  plugins: ['expo-router', 'expo-font', 'expo-splash-screen'],
  experiments: {
    typedRoutes: true,
  },
  extra: {
    router: {},
    // eas.projectId se añade con `eas init`; no lo hardcodees aquí en el template.
    // La URL/anon key de Supabase llegan por EXPO_PUBLIC_* (EAS env), no por `extra`.
  },
});
