import { z } from 'zod';

/**
 * Variables públicas de la app, validadas al arrancar. Si falta alguna, la app falla con un
 * mensaje claro en lugar de un error opaco de red más tarde.
 *
 * Importante: Metro solo inyecta `process.env.EXPO_PUBLIC_*` cuando se accede con el nombre
 * literal (`process.env.EXPO_PUBLIC_SUPABASE_URL`). En el navegador `process` no existe, así
 * que esta función recibe el objeto ya construido con accesos literales (ver lib/supabase.ts).
 */
const schema = z.object({
  EXPO_PUBLIC_SUPABASE_URL: z.string().url(),
  EXPO_PUBLIC_SUPABASE_ANON_KEY: z.string().min(20),
});

export type PublicEnv = z.infer<typeof schema>;

export function readPublicEnv(source: Record<string, string | undefined>): PublicEnv {
  const parsed = schema.safeParse({
    EXPO_PUBLIC_SUPABASE_URL: source.EXPO_PUBLIC_SUPABASE_URL,
    EXPO_PUBLIC_SUPABASE_ANON_KEY: source.EXPO_PUBLIC_SUPABASE_ANON_KEY,
  });
  if (!parsed.success) {
    const missing = parsed.error.issues.map((i) => i.path.join('.')).join(', ');
    throw new Error(
      `[env] Faltan o son inválidas: ${missing}. Copia el archivo de ejemplo a tu entorno local o configúralas con "eas env" (builds).`
    );
  }
  return parsed.data;
}
