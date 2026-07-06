# IT Service Reports · Web App

Aplicación web responsive (mobile-first) para reportes de servicio IT en campo.
Corre desde **GitHub Pages** (hosting gratis) y guarda todo en **Supabase**
(Postgres gratis) para que técnicos y admin vean los mismos reportes desde
cualquier dispositivo.

- **Login real** por email + contraseña (Supabase Auth)
- **Multi-usuario** con roles: Técnico · Supervisor · Admin · Super Admin
- **Sincronización automática**: los reportes se guardan en la nube sin que
  el usuario tenga que "guardar" a mano
- **Modo offline**: si no hay internet, sigue guardando en el navegador y
  sincroniza al volver
- **PDF** listo para imprimir/compartir con el cliente
- **Personalización** de marca (logo, nombre, colores) por dispositivo

---

## 🚀 Puesta en marcha (30 min)

### 1) Crear proyecto en Supabase

1. Entra a <https://supabase.com> y crea una cuenta (con GitHub sirve).
2. **New project** → dale un nombre (`it-service`), guarda la contraseña de
   la base de datos, selecciona la región más cercana (South America - São Paulo).
3. Espera ~2 min a que provisione.

### 2) Correr el schema

1. En el panel del proyecto → **SQL Editor** → **New query**.
2. Abre el archivo `supabase-schema.sql` de este repo, copia TODO el contenido
   y pégalo en el editor.
3. Clic en **Run**. Deberías ver "Success. No rows returned".

### 3) Configurar Auth

1. **Authentication → Providers → Email**
   - Habilita "Email".
   - Desactiva "Confirm email" (para el arranque; luego puedes reactivarlo).
2. **Authentication → Users → Add user → Create new user**
   - Email: `admin@tuempresa.com` (el que quieras)
   - Password: uno fuerte (mínimo 6)
   - Auto Confirm User: ✅
3. Vuelve al **SQL Editor** y corre:
   ```sql
   update public.profiles
     set role = 'super_admin', name = 'Tu Nombre'
     where email = 'admin@tuempresa.com';
   ```
   Ese será el primer Super Admin. Desde la app podrá crear los demás.

### 4) Copiar credenciales a la app

1. **Project Settings → API**
2. Copia:
   - **Project URL** → algo como `https://xxxxx.supabase.co`
   - **anon public key** → un token largo que empieza con `eyJ...`
3. Abre `config.js` en este repo y pega ambas:
   ```js
   window.APP_CONFIG = {
     SUPABASE_URL: 'https://xxxxx.supabase.co',
     SUPABASE_ANON_KEY: 'eyJhbGci...'
   };
   ```
   > La `anon key` es pública por diseño (Supabase la piensa así). La seguridad
   > real está en las políticas RLS que ya vienen en `supabase-schema.sql`.
   > **NO** pongas nunca la `service_role` key en `config.js`.

### 5) Subir a GitHub y activar GitHub Pages

Si aún no tienes repo:

```bash
cd it-service-app
git init
git add -A
git commit -m "primer commit"
```

Luego, en <https://github.com>:

1. **New repository** → nombre `it-service-app` → **Private** (recomendado) → Create.
2. Copia los comandos que te da GitHub y pégalos en la terminal:
   ```bash
   git remote add origin https://github.com/TU_USUARIO/it-service-app.git
   git branch -M main
   git push -u origin main
   ```
3. En el repo → **Settings → Pages**
   - **Source**: "GitHub Actions"
   - Espera ~1 min y GitHub te da la URL: `https://TU_USUARIO.github.io/it-service-app/`

Alternativa más simple (sin GitHub Actions):

- **Settings → Pages → Branch: main / (root)** → Save.
- Misma URL, actualiza cada vez que haces push.

### 6) ¡Listo!

Entra a la URL desde tu celular. Inicia sesión con el Super Admin que creaste.
Desde **Perfil → Gestionar usuarios**, crea las cuentas de los técnicos.
Cada técnico entra desde su celular con su correo/contraseña.

---

## 📱 Instalar como app en el celular (PWA-lite)

- **Android/Chrome**: abre la URL → menú (⋮) → "Añadir a pantalla de inicio".
- **iPhone/Safari**: abre la URL → botón compartir → "Añadir a pantalla de inicio".

Ya queda con icono y se abre a pantalla completa.

---

## 🔒 Roles

| Rol           | Permisos                                                       |
| ------------- | -------------------------------------------------------------- |
| `technician`  | Crea y edita sus propios reportes                              |
| `supervisor`  | Ve y corrige todos los reportes                                |
| `admin`       | Aprueba/factura reportes                                       |
| `super_admin` | Todo lo anterior + gestiona usuarios                           |

Los técnicos solo ven **sus** reportes. Admins y supervisores ven **todos**.
Esto se enforza por RLS en Postgres (no confía en el cliente).

---

## 🧰 Estructura

```
it-service-app/
├─ index.html               ← la app completa (HTML + CSS + JS en un solo archivo)
├─ config.js                ← tu URL + anon key de Supabase
├─ supabase-schema.sql      ← esquema Postgres + RLS (correr una sola vez)
├─ .github/workflows/       ← deploy automático a Pages en cada push
└─ README.md                ← este archivo
```

---

## 🛟 Modo local (sin internet o sin Supabase)

Si `config.js` no está configurado, la app cae automáticamente en modo local:
- El login usa los usuarios demo del código.
- Los datos se guardan en `localStorage`.
- Sirve para probar la UI sin backend.

---

## 🧯 Troubleshooting

- **"Credenciales incorrectas"** aunque el usuario existe: revisa que en
  Supabase esté "Auto Confirm" activo o confirma el correo desde el link.
- **El técnico ve la lista vacía**: normal la primera vez — hasta que un admin
  le asigne reportes o él cree el primero. Si tampoco ve los suyos, revisa
  que `profiles.role` esté bien.
- **"Cuenta sin perfil"**: pasó que el trigger no corrió. Ejecuta manualmente:
  ```sql
  insert into profiles (id, name, email, role)
  values ('<uuid>', 'Nombre', '<email>', 'technician');
  ```
- **Cambios no se ven en otro dispositivo**: cierra sesión y vuelve a entrar
  (la sincronización se dispara al login).

---

## 💾 Backup

Perfil → Exportar backup. Descarga un JSON con TODO. Sirve como respaldo local.
Puedes también hacer un `pg_dump` desde Supabase (Database → Backups).
