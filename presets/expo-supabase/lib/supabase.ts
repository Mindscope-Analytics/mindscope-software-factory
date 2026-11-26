import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';
import { readPublicEnv } from '@/lib/env';

// Accesos literales: Metro los sustituye en build (web y nativo). No pasar `process.env` entero.
const env = readPublicEnv({
  EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
  EXPO_PUBLIC_SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
});

/**
 * Cliente Supabase para la app (anon key + sesión del usuario → RLS).
 * Nativo: la sesión se persiste en AsyncStorage (SecureStore limita a 2 KB y los tokens lo
 * superan). Web: storage por defecto de supabase-js (localStorage; memoria si no hay window).
 * `detectSessionInUrl: false` porque el flujo es OTP, sin URL de callback.
 */
export const supabase = createClient(env.EXPO_PUBLIC_SUPABASE_URL, env.EXPO_PUBLIC_SUPABASE_ANON_KEY, {
  auth: {
    ...(Platform.OS === 'web' ? {} : { storage: AsyncStorage }),
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
