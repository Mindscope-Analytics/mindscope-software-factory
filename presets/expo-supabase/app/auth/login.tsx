import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuth } from '@/hooks/useAuth';
import { authErrorMessage, normalizeEmail } from '@/lib/validators';

export default function Login() {
  const { requestCode } = useAuth();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit() {
    const normalized = normalizeEmail(email);
    if (!normalized) return setError('El correo no es válido.');
    setBusy(true);
    setError('');
    try {
      await requestCode(normalized);
      router.push({ pathname: '/auth/verify', params: { email: normalized } });
    } catch (e) {
      setError(authErrorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.center}>
      <View style={styles.card} testID="login">
        <Text style={styles.title}>Entrar</Text>
        <Text style={styles.muted}>Te enviaremos un código de 6 dígitos a tu correo.</Text>
        <TextInput
          testID="email"
          style={styles.input}
          placeholder="tu@correo.com"
          autoCapitalize="none"
          autoComplete="email"
          keyboardType="email-address"
          value={email}
          onChangeText={setEmail}
          onSubmitEditing={onSubmit}
        />
        {error ? <Text style={styles.error}>{error}</Text> : null}
        <Pressable onPress={onSubmit} disabled={busy} style={[styles.button, busy && styles.disabled]} accessibilityRole="button">
          <Text style={styles.buttonText}>{busy ? 'Enviando…' : 'Enviar código'}</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  card: { width: '100%', maxWidth: 400, gap: 12 },
  title: { fontSize: 26, fontWeight: '700' },
  muted: { color: '#71717a' },
  input: { borderWidth: 1, borderColor: '#d4d4d8', borderRadius: 10, padding: 12, fontSize: 16 },
  error: { color: '#b91c1c' },
  button: { paddingVertical: 14, borderRadius: 10, backgroundColor: '#18181b', alignItems: 'center' },
  disabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontWeight: '600' },
});
