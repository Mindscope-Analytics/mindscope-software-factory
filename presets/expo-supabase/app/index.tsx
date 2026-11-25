import { Redirect } from 'expo-router';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { useAuth } from '@/hooks/useAuth';

export default function Home() {
  const { user, loading, signOut } = useAuth();
  if (loading) {
    return (
      <View style={styles.center} testID="loading">
        <ActivityIndicator />
      </View>
    );
  }
  if (!user) return <Redirect href="/auth/login" />;
  return (
    <View style={styles.center} testID="home">
      <Text style={styles.title}>Sesión iniciada</Text>
      <Text style={styles.muted}>{user.email}</Text>
      <Pressable onPress={() => signOut()} style={styles.button} accessibilityRole="button">
        <Text style={styles.buttonText}>Cerrar sesión</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12, padding: 24 },
  title: { fontSize: 22, fontWeight: '600' },
  muted: { color: '#71717a' },
  button: { marginTop: 16, paddingHorizontal: 20, paddingVertical: 12, borderRadius: 10, backgroundColor: '#18181b' },
  buttonText: { color: '#fff', fontWeight: '600' },
});
