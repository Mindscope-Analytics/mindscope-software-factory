import { expect, test } from '@playwright/test';

test('la app arranca y lleva al login sin sesión', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByTestId('login')).toBeVisible({ timeout: 15_000 });
  await expect(page.getByTestId('email')).toBeVisible();
});

test('valida el correo antes de pedir código', async ({ page }) => {
  await page.goto('/auth/login');
  await page.getByTestId('email').fill('no-es-correo');
  await page.getByRole('button', { name: 'Enviar código' }).click();
  await expect(page.getByText('El correo no es válido.')).toBeVisible();
});
