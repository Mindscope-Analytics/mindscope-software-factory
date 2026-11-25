import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';
import { readPublicEnv } from '@/lib/env';

const env = readPublicEnv();

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
