import type { Session, User } from '@supabase/supabase-js';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { supabase } from '@/lib/supabase';
import { normalizeEmail, normalizeOtp } from '@/lib/validators';

/**
 * Auth por email + código OTP (sin contraseña, sin OAuth). Flujo:
 *   requestCode(email) → Supabase envía {{ .Token }} (plantilla supabase/templates/magic_link.html)
 *   verifyCode(email, code) → sesión.
 * Generalizado desde un proyecto previo; sin branding ni campos de dominio.
 */
interface AuthContextValue {
  session: Session | null;
  user: User | null;
  /** true mientras se resuelve la sesión persistida (evita parpadeo al arrancar). */
  loading: boolean;
  /** Envía un código de un solo uso al correo. Crea la cuenta si no existe. */
  requestCode: (email: string) => Promise<void>;
  /** Verifica el código y abre sesión. */
  verifyCode: (email: string, code: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, next) => setSession(next));
    return () => listener.subscription.unsubscribe();
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      loading,
      requestCode: async (emailInput) => {
        const email = normalizeEmail(emailInput);
        if (!email) throw new Error('invalid email');
        const { error } = await supabase.auth.signInWithOtp({ email, options: { shouldCreateUser: true } });
        if (error) throw error;
      },
      verifyCode: async (emailInput, codeInput) => {
        const email = normalizeEmail(emailInput);
        const token = normalizeOtp(codeInput);
        if (!email || !token) throw new Error('otp has expired');
        const { error } = await supabase.auth.verifyOtp({ email, token, type: 'email' });
        if (error) throw error;
      },
      signOut: async () => {
        const { error } = await supabase.auth.signOut();
        if (error) throw error;
      },
    }),
    [session, loading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth debe usarse dentro de <AuthProvider>.');
  return ctx;
}
