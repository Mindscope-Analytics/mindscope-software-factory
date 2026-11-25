-- seed.sql — datos locales de desarrollo. Corre tras las migraciones en `supabase db reset`.
-- Reglas:
--   · Nada de datos reales ni correos de personas.
--   · Los usuarios de prueba se crean desde la app o con la Admin API, no aquí
--     (insertar en auth.users a mano depende del esquema interno de Auth).
--   · Añade aquí catálogos y datos de referencia del dominio cuando existan.
select 1;
