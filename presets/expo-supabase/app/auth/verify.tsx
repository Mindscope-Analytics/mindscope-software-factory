import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuth } from '@/hooks/useAuth';
import { authErrorMessage, normalizeOtp } from '@/lib/validators';

const RESEND_COOLDOWN_S = 60;

export default function Verify() {
  const { email } = useLocalSearchParams<{ email: string }>();
  const { verifyCode, requestCode } = useAuth();
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [cooldown, setCooldown] = useState(RESEND_COOLDOWN_S);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  async function onVerify() {
    if (!email) return router.replace('/auth/login');
    if (!normalizeOtp(code)) return setError('El código debe tener 6 dígitos.');
    setBusy(true);
    setError('');
    try {
      await verifyCode(email, code);
      router.replace('/');
    } catch (e) {
      setError(authErrorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function onResend() {
    if (!email || cooldown > 0) return;
    try {
      await requestCode(email);
      setCooldown(RESEND_COOLDOWN_S);
    } catch (e) {
      setError(authErrorMessage(e));
    }
  }

  return (
    <View style={styles.center}>
      <View style={styles.card} testID="verify">
        <Text style={styles.title}>Revisa tu correo</Text>
        <Text style={styles.muted}>Escribe el código que enviamos a {email}.</Text>
        <TextInput
          testID="otp"
          style={styles.input}
          placeholder="123456"
          keyboardType="number-pad"
          autoComplete="one-time-code"
          maxLength={6}
          value={code}
          onChangeText={setCode}
          onSubmitEditing={onVerify}
        />
        {error ? <Text style={styles.error}>{error}</Text> : null}
        <Pressable onPress={onVerify} disabled={busy} style={[styles.button, busy && styles.disabled]} accessibilityRole="button">
          <Text style={styles.buttonText}>{busy ? 'Verificando…' : 'Entrar'}</Text>
        </Pressable>
        <Pressable onPress={onResend} disabled={cooldown > 0} accessibilityRole="button">
          <Text style={styles.link}>{cooldown > 0 ? `Reenviar código en ${cooldown}s` : 'Reenviar código'}</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  card: { width: '100%', maxWidth: 400, gap: 12 },
  title: { fontSize: 26, fontWeight: '700' },
  muted: { color: '#71717a' },
  input: { borderWidth: 1, borderColor: '#d4d4d8', borderRadius: 10, padding: 12, fontSize: 22, letterSpacing: 6, textAlign: 'center' },
  error: { color: '#b91c1c' },
  button: { paddingVertical: 14, borderRadius: 10, backgroundColor: '#18181b', alignItems: 'center' },
  disabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontWeight: '600' },
  link: { color: '#2563eb', textAlign: 'center', paddingVertical: 8 },
});
