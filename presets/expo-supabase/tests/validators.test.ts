import { authErrorMessage, normalizeEmail, normalizeOtp } from '../lib/validators';
import { readPublicEnv } from '../lib/env';

describe('normalizeEmail', () => {
  it('recorta y pasa a minúsculas', () => {
    expect(normalizeEmail('  Ana@Example.COM ')).toBe('ana@example.com');
  });
  it('rechaza correos inválidos', () => {
    expect(normalizeEmail('ana@')).toBeNull();
    expect(normalizeEmail('')).toBeNull();
    expect(normalizeEmail('sin arroba')).toBeNull();
  });
});

describe('normalizeOtp', () => {
  it('acepta 6 dígitos y quita espacios', () => {
    expect(normalizeOtp('123 456')).toBe('123456');
    expect(normalizeOtp(' 000000 ')).toBe('000000');
  });
  it('rechaza otras longitudes o letras', () => {
    expect(normalizeOtp('12345')).toBeNull();
    expect(normalizeOtp('1234567')).toBeNull();
    expect(normalizeOtp('12a456')).toBeNull();
  });
});

describe('authErrorMessage', () => {
  it('traduce errores conocidos', () => {
    expect(authErrorMessage({ message: 'Token has expired or is invalid' })).toMatch(/expiró/);
    expect(authErrorMessage({ message: 'For security purposes, you can only request this after 60 seconds' })).toMatch(/Demasiados/);
  });
  it('cae a un mensaje genérico', () => {
    expect(authErrorMessage(new Error('boom'))).toBe('Algo salió mal. Inténtalo de nuevo.');
    expect(authErrorMessage(undefined)).toBe('Algo salió mal. Inténtalo de nuevo.');
  });
});

describe('readPublicEnv', () => {
  it('valida las variables públicas', () => {
    expect(
      readPublicEnv({
        EXPO_PUBLIC_SUPABASE_URL: 'https://example.supabase.co',
        EXPO_PUBLIC_SUPABASE_ANON_KEY: 'x'.repeat(32),
      })
    ).toEqual({
      EXPO_PUBLIC_SUPABASE_URL: 'https://example.supabase.co',
      EXPO_PUBLIC_SUPABASE_ANON_KEY: 'x'.repeat(32),
    });
  });
  it('falla con mensaje claro si faltan', () => {
    expect(() => readPublicEnv({})).toThrow(/EXPO_PUBLIC_SUPABASE_URL/);
  });
});
