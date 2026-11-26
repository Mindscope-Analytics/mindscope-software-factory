import { z } from 'zod';

/** Email normalizado (trim + minúsculas). */
export const emailSchema = z.string().trim().toLowerCase().email({ message: 'El correo no es válido.' });

/** Código OTP de 6 dígitos tal como lo envía Supabase Auth. */
export const otpSchema = z.string().trim().regex(/^\d{6}$/, { message: 'El código debe tener 6 dígitos.' });

export function normalizeEmail(input: string): string | null {
  const r = emailSchema.safeParse(input);
  return r.success ? r.data : null;
}

export function normalizeOtp(input: string): string | null {
  const r = otpSchema.safeParse(input.replace(/\s+/g, ''));
  return r.success ? r.data : null;
}

/**
 * Traduce errores de Supabase Auth a mensajes para la persona. Cae a un mensaje genérico.
 * (Origen: hook de auth de un proyecto previo, sin branding.)
 */
export function authErrorMessage(error: unknown): string {
  const message =
    typeof error === 'object' && error !== null && 'message' in error
      ? String((error as { message: unknown }).message)
      : '';
  const m = message.toLowerCase();

  if (m.includes('invalid login credentials')) return 'Correo o código incorrectos.';
  if (m.includes('email not confirmed')) return 'Debes confirmar tu correo antes de iniciar sesión.';
  if (m.includes('user already registered')) return 'Ya existe una cuenta con este correo.';
  if (m.includes('signups not allowed')) return 'El registro está cerrado por ahora.';
  if (m.includes('unable to validate email') || m.includes('invalid email')) return 'El correo no es válido.';
  if (m.includes('token has expired') || m.includes('otp_expired') || m.includes('otp has expired'))
    return 'El código no es válido o ya expiró. Solicita uno nuevo.';
  if (m.includes('rate limit') || m.includes('for security purposes'))
    return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
  if (m.includes('network') || m.includes('fetch')) return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  return 'Algo salió mal. Inténtalo de nuevo.';
}
