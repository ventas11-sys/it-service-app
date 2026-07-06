/* ============================================================
   CONFIGURACIÓN DE SUPABASE
   ============================================================
   1. Crea un proyecto gratis en https://supabase.com
   2. Ve a: Project Settings → API
   3. Copia "Project URL" y "anon public key"
   4. Pégalas aquí abajo
   5. Corre el archivo supabase-schema.sql en el SQL Editor del proyecto
   6. Sube este repo a GitHub y activa GitHub Pages

   ⚠️ Este archivo se sube al repo — la anon key es pública por diseño.
   La seguridad real está en las políticas RLS del schema. NO pongas
   aquí la "service role" key.
   ============================================================ */

window.APP_CONFIG = {
  SUPABASE_URL: 'https://YOUR-PROJECT.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR-ANON-KEY'
};
