# ProTrainerPlus v2

Nueva versión del portal. Vive en la raíz `https://atletas.headcoachleonardopablo.com/` (el `index.html` principal). El portal anterior se retiró el 29/10/2026: `/anterior/` y `/v2/` solo redirigen a la raíz conservando `#hash` y `?query` (enlaces de correo). Los datos del portal anterior (tablas `plans`, `sessions`, etc.) siguen en Supabase y la app nueva los sigue leyendo.

- Usa el mismo Supabase y el mismo login que el portal actual (`/`).
- No modifica `index.html`, ni las tablas `plans`, `sessions`, `profiles`, `comments` o `evidencias`. Los planes actuales de cada atleta se siguen viendo en el portal de siempre; la v2 muestra un acceso directo a ellos.
- Guarda lo nuevo en tablas con prefijo `pt_`:
  - tareas del calendario
  - biblioteca de ejercicios
  - plantillas
  - disposición y carga
  - mensajes y actividad

## Instalación (una sola vez)

1. Supabase → SQL Editor → New query → pega `supabase-v2.sql` → Run.
2. Publica esta carpeta `v2/` en la rama principal del repo `portal-atletas` (GitHub Pages la sirve sola).
3. Entra a `/v2/` con la cuenta del coach. La primera vez se cargan solas la biblioteca de ejercicios y las plantillas, armadas con los planes reales.

## Archivos

- `index.html` — panel del coach y vista del atleta (según el rol de quien entra).
- `supabase-v2.sql` — tablas nuevas y permisos (RLS). Se puede correr más de una vez.

## Editor de entrenamientos (29/10/2026)

- Cada ejercicio tiene botones − / + para series, reps, RIR, tempo y descanso, y un selector kg / lb.
- Tipos: Aislado, Biserie (2), Triserie (3), Superserie (2), Megaserie (4+) y Dropset. Se guardan en cada ejercicio como `link` (va seguido del siguiente), `gtype` y `drop`; el atleta los ve agrupados (A1, A2…).
- Una sesión ya asignada se edita desde su detalle (botón Editar); puede aplicarse a las siguientes sesiones iguales. Las sesiones editadas a mano no se sobrescriben al guardar el plan.
- Al guardar un plan se actualizan sus sesiones pendientes del calendario (casilla en el editor).
- Excel: `plantilla-entrenamiento.xlsx` (Plantillas → Descargar plantilla Excel / Subir Excel). También se lee la plantilla anterior `plantilla-plan.xlsx`. Cada plan se puede exportar a Excel y volver a cargar.

## Demo privado para coaches

- Se abre solo con el enlace `https://atletas.headcoachleonardopablo.com/#demo=<clave>`. El repo guarda únicamente el hash SHA-256 de la clave (`DEMO.HASH` en `index.html`); para cambiar la clave, genera una nueva y reemplaza el hash.
- No usa Supabase: todo vive en el navegador del visitante (localStorage). Arranca en limpio, sin clientes; solo trae la biblioteca de ejercicios y 3 plantillas base sin nombres de atletas. Cada visitante tiene su propia copia; «Reiniciar demo» la borra.
- Funciona igual que la app real: crear clientes (genera correo y contraseña de demo), planes, tareas, Excel, vista del atleta.

## Eliminar perfil (lo hace la clienta / cliente o el coach)

- En **Mi perfil**, al final, hay un enlace pequeño «Eliminar mi perfil» con dos confirmaciones (casilla + escribir ELIMINAR).
- El coach también puede eliminar a un cliente: Perfil del cliente → «🗑️ Eliminar cliente», con los mismos pasos. Además borra el plan personal del cliente en las plantillas.
- Requiere correr una vez `eliminar-cuenta.sql` en Supabase → SQL Editor. Crea las funciones `delete_my_account()` y `coach_delete_client(correo)` y el permiso para que cada quien borre sus archivos del bucket `evidencias`.
- Borra: tareas, cargas, medidas, foto, ciclo, alimentación, mensajes, actividad, avisos, ficha, plan, sesiones, comentarios, evidencias (filas y archivos), perfil y el usuario de acceso. El coach no puede borrarse por esta vía.
- Después la persona puede registrarse otra vez con el mismo correo y empieza en blanco.

## Cargar desde archivo (ficha del cliente)

- Botón **Cargar desde archivo** en la ficha de cada cliente. Solo acepta Excel (.xlsx/.xls, se valida el contenido, no solo la extensión) con el formato de `plantilla-entrenamiento.xlsx`.
- Lee: hojas de días (plan), «Datos del plan», «Datos del cliente» y «Nutrición». Muestra una vista previa y el coach elige qué aplicar.
- El plan se asigna al cliente y se programa en su calendario desde la fecha elegida (L–V o L–S); reemplaza las sesiones pendientes del plan anterior y conserva las completadas.
- También lee la plantilla anterior `plantilla-plan.xlsx`.

## Trabajo aeróbico

- Categoría «Aeróbico / cardio» en el editor de plan y botón «Agregar bloque aeróbico» en el editor de sesión (también cuenta cualquier bloque llamado Cardio/Aeróbico).
- En esos ejercicios se cambian series/reps/RIR/tempo/descanso por: Máquina, Tiempo (min), Inclinación (solo caminadora), Zona Karvonen (Z1–Z5) y FCE en lpm (se calcula con la edad y la FC en reposo del cliente).
- En el plan, cada fase lleva minutos y zona. El atleta lo ve con 🏃 y lo marca como «Hecho».
- Excel: Grupo = Aeróbico; en F1–F4 Series van los minutos y en F1–F4 Reps la zona; columnas Máquina e Inclinación.

## Aviso de privacidad (LFPDPPP 2025)

- Aviso integral público: `aviso-de-privacidad/index.html` → atletas.headcoachleonardopablo.com/aviso-de-privacidad/ (fuente única; la app lo carga dentro de la ventana).
- Cada cliente (nuevo o actual) ve la ventana al entrar hasta aceptar la versión vigente (`PRIVACY.version` en index.html). Aceptar exige la casilla de consentimiento expreso para datos sensibles (art. 8); finalidades secundarias opcionales. Cancelar bloquea el acceso y permite salir.
- La aceptación se guarda en `pt_evo` (kind `privacy`, versión, fecha, secundarias, navegador). El coach ve el estado en la ficha del cliente.
- Para publicar una nueva versión: edita la página del aviso, sube `PRIVACY.version` y su fecha; todos los clientes lo volverán a aceptar.

## Multi-coach: «Soy coach / Soy atleta» y catálogo de coaches

- Requiere correr una vez `multi-coach.sql` (después de los otros scripts). Antes de correrlo, la app funciona como siempre (un solo coach).
- **Crear cuenta** (en la app nueva, desde «Entrar» o `/#crear-cuenta`): elige «Soy atleta» o «Soy coach». El coach queda activo al instante con 14 días de prueba (`pt_coaches.trial_ends_at`); el cobro automático está pendiente.
- **Cada coach ve solo a sus clientes**: el acceso a las tablas `pt_*` depende del vínculo activo en `pt_links`. Plantillas por coach; biblioteca compartida (solo el coach principal borra).
- **Cliente sin coach** → ve el catálogo (`pt_coach_profiles`) y envía una solicitud; el coach la acepta o rechaza en «Solicitudes». Al darlo de alta el coach: si la cuenta es nueva queda vinculada; si ya existía, se le envía una invitación (evita que un coach tome clientes de otro).
- **Mi perfil de coach**: ficha pública del catálogo (foto, título, especialidades, ciudad, modalidad, precios, bio, sitio, Instagram, visible u oculto).
- Los clientes actuales quedan asignados a coach@headcoachleonardopablo.com. Las tablas del portal anterior no cambian y siguen siendo solo del coach principal.

## Cuenta y planes (29/10/2026)

- Recuperar contraseña, crear nueva contraseña (enlace de recuperación) y enlaces vencidos se resuelven en la app nueva.
- Ficha del cliente → «Plan de entrenamiento»: ver/editar/programar su plan, crear uno a mano, copiar una plantilla o cargar Excel. Al programar se pueden reemplazar las sesiones pendientes del plan anterior.

## Administración, aprobación de coaches, baja del coach y llamada inicial (admin-coaches.sql)
- Correr `v2/admin-coaches.sql` después de `multi-coach.sql` (ya aplicado en producción).
- **Administración:** la cuenta del coach principal (tabla `coaches`) y los correos de `pt_admins` ven la sección 🛡️ Administración: todos los coaches, su estado (Principal / Prueba / Activo / En revisión / Rechazado) y los clientes de cada uno, más los clientes sin coach. Para sumar otro administrador: `insert into pt_admins(email) values ('correo@dominio.com');`.
- **Aprobación:** quien se registra como coach queda `pending` (pantalla «Tu cuenta está en revisión», oculto del catálogo). El administrador ve un aviso arriba y en la sección acepta (empieza la prueba de 14 días y aparece en el catálogo) o rechaza. Los coaches que ya estaban en prueba o activos no cambian.
- **Baja del coach:** «Mi perfil de coach» → 🗑️ Darme de baja (mismo flujo naranja de 2 pasos). Borra su cuenta, perfil y plantillas; sus clientes conservan su historial, reciben un aviso y vuelven a ver el catálogo. La cuenta administradora no se puede dar de baja.
- **Llamada inicial de 15 min:** el coach define días, horario y enlace (Meet/Zoom/WhatsApp) en su perfil. El cliente, al pedir coach, elige día y hora (se evitan horarios ya apartados) y deja un mensaje. Coach y cliente ven la llamada con botones para agregarla a Google Calendar, Apple (.ics) u Outlook.
- **Tema:** verde menta neón (#19e6a4 día / #3dffb9 noche), Red Hat Display y botón ☀️/🌙 en portal, landing, demo, «Conoce tu plan» y aviso de privacidad. La preferencia se guarda en `localStorage` (`ptp-theme`) y se comparte entre páginas del dominio; si no hay, sigue al sistema.

## Registros no verificados (descartar-no-verificados.sql)
- Si una cuenta nueva no confirma su correo en **24 horas**, se descarta sola (acceso, perfil y solicitudes pendientes). Corre cada hora con `pg_cron` (tarea `ptp-descartar-no-verificados`).
- Nunca toca cuentas que ya entraron, con entrenamientos, con coach activo, coaches en prueba/activos ni al coach principal.
- Para correrla a mano: `select public.pt_purge_unverified();` (devuelve cuántas cuentas descartó).

## Perfil del coach, catálogo interactivo y calificaciones (calificaciones.sql)
- **Perfil del coach:** foto de perfil, años de experiencia, certificaciones (una por línea), especialidades, ciudad, modalidad, cuotas por entrenamiento y casilla «Mostrar mis cuotas en el catálogo» (si se desmarca, aparece «Precio a consultar»). Todo vive en `pt_coach_profiles.doc` (`years`, `certs`, `prices`, `showPrices`).
- **Elige a tu coach:** búsqueda libre (nombre, especialidad, ciudad, certificación), chips por especialidad, filtros por calificación mínima, experiencia, ciudad, modalidad, precio máximo y «con certificaciones», y orden (mejor calificados, más experiencia, menor precio, nombre). Cada tarjeta muestra foto, estrellas (1–5) con número de opiniones, experiencia y certificaciones.
- **Calificaciones:** el cliente califica a su coach actual en compromiso, resultados, seguimiento, puntualidad y conocimiento (1–5) + comentario opcional; puede editarla. Es anónima: el catálogo muestra el promedio y el coach ve promedios por aspecto y comentarios sin nombre en «Mi perfil de coach». El administrador ve las estrellas de cada coach. Tabla `pt_coach_ratings`; funciones `pt_rate_coach`, `pt_coach_rating_summary`, `pt_my_coach_reviews`.

## Calendly
- El coach pega su enlace de Calendly en «Mi perfil de coach» (`doc.calendly`, debe empezar con `https://calendly.com/`). Recomendado: en Calendly, ubicación **Google Meet o Zoom** para que el enlace de la llamada llegue en el correo.
- En «Elige a tu coach», los coaches con Calendly muestran «📅 Agenda tu llamada inicial con Calendly». Al pedir coach se abre su calendario incrustado (con nombre y correo del cliente ya llenos). Al agendar, Calendly envía al cliente el **correo de confirmación con el enlace de la llamada** (y al coach su aviso), y el portal envía la solicitud al coach con la nota «Llamada inicial agendada en Calendly».
- El cliente con coach ve «📅 Agendar una llamada con mi coach» (ventana de Calendly).
- Sin Calendly sigue funcionando el selector de horario propio con botones de Google/Apple/Outlook.
- No se requiere llave de API: el widget es público y el aviso de cita agendada se recibe del propio widget.
- **Guía en globo:** si el coach no ha conectado Calendly, junto a «Mi perfil de coach» aparece un globo «📅 Conecta tu Calendly para la llamada inicial» → «Ver los pasos» (7 pasos con enlace a calendly.com/signup). Se puede cerrar («Ahora no») y desaparece solo al guardar el enlace. En el perfil, el botón «❓ ¿Cómo lo creo?» abre los mismos pasos junto al campo.

## Contacto del coach y «Herramientas» del cliente (contacto-coach.sql)
- El coach agrega su **número de contacto** (lada de país + número) en «Mi perfil de coach»; se genera su enlace **wa.me** al momento. Casilla «Mostrar mi WhatsApp en el catálogo» (apagada por defecto). El número vive en `pt_coach_contacts` (no en el perfil público): lo ven sus clientes activos y el administrador; el catálogo solo si el coach lo permite.
- El cliente tiene el icono 🔧 **Herramientas** en su encabezado: **Información del entrenador** (foto, título, estrellas, experiencia, ciudad, modalidad, especialidades, certificaciones y calificación) · **Contacto** (WhatsApp con mensaje listo, llamar, correo, mensajes en la app, Calendly, Instagram y sitio) · **Apariencia** (modo día/oscuro y acceso a Mi perfil).
- El cliente activo ahora puede leer el perfil de su coach aunque el coach esté oculto del catálogo (política `pt_cp_read`).

## Nuevo plan de nutrición, privacidad del ciclo y repetir entrenamientos (18/11/2026)

**Nuevo plan de nutrición (coach):** Ficha del cliente → Nutrición → «+ Nuevo plan de nutrición». Se captura nombre, objetivo, fecha de inicio, macros (g) y kcal objetivo (se calculan solas: 4/4/9). Se parte en blanco o duplicando el plan vigente. El plan anterior pasa a «Planes anteriores» (máx. 12, en `pt_athletes.doc.nutHist`); el atleta los consulta en solo lectura y el coach puede «Volver a usarlo». Avisos si la proteína queda fuera de 1.2–2.5 g/kg o las kcal bajan de 1,200 (no bloquean).

**Privacidad del ciclo menstrual (dos llaves):**
- Coach: casilla «Mostrar el módulo de ciclo menstrual» en la ficha de la clienta (`pt_athletes.doc.cycleMod`, encendido por defecto). Apagado oculta la sección a ambos; no borra datos.
- Atleta: «Compartir con mi coach» en su sección de fase menstrual, con casilla de consentimiento expreso (fila `pt_evo` id `cycpriv_<correo>`). Puede dejar de compartir cuando quiera: en ese momento el coach deja de recibir sus registros y se quitan las marcas de periodo de sus sesiones y actividad.
- Requiere correr una vez `v2/privacidad-ciclo.sql` **antes** de publicar el código: crea `pt_cycle_shared()` y políticas RLS restrictivas en `pt_evo`, y deja «compartiendo» a quienes ya registraban su ciclo (así funcionaba antes).
- El coach ya no registra el periodo al crear una clienta nueva (es un dato de ella).

**Repetir entrenamiento por días:** en «Añadir tarea → Entrenamiento», sección «🔁 Repetir este entrenamiento»: casillas L–D, atajos (L–V, L–S, L·X·V, M·J, Todos, Solo este día), duración de 1 a 12 semanas y vista previa de las fechas. Si un día ya tiene entrenamiento: agregarlo además u omitir ese día. Las sesiones creadas comparten `seriesId`; al editar una, «Aplicar también a las próximas» cambia solo las de esa serie.

**Repetir un bloque (18/11/2026):** cada bloque del editor de entrenamiento tiene el botón «🔁 Repetir bloque» en su encabezado. Se eligen días (L–D, atajos) y semanas; la vista previa muestra las fechas. En los días que ya tienen entrenamiento pendiente, el bloque se suma al final de esa sesión; en los demás se crea una sesión solo con ese bloque (`blockRep`, mismo `seriesId`). Funciona al crear y al editar una sesión. Los días que ya llevan el entrenamiento completo no se duplican.

**Calculadora Harris-Benedict en «Nuevo plan de nutrición» (18/11/2026):** con sexo, edad, peso, estatura, nivel de actividad (factor 1.2–1.9) y grado de entrenamiento (principiante, intermedio, avanzado, competidor) calcula GEB con Harris-Benedict revisada (Roza y Shizgal, 1984), GET = GEB × actividad y kcal del plan = GET × ajuste por objetivo (definición −15%, recomposición −5%, mantenimiento 0, rendimiento +5%, volumen +10%; editable). Macros: proteína 1.6/1.8/2.0/2.2 g/kg según grado (+0.3 en definición, +0.2 en recomposición), grasa 0.8–1.0 g/kg y carbohidratos con las kcal restantes. «Usar estos valores» llena macros y kcal; el cálculo se guarda en `nutrition.calc` y, si se marca, edad, estatura, actividad y `trainLevel` en la ficha.

**Calculadora con botones y bloques de alimentación (18/11/2026):**
- En «Nuevo plan de nutrición» la calculadora muestra la fórmula, el botón «Calcular gasto energético total» (GEB y GET con los números sustituidos) y el ajuste del coach: Déficit / Mantenimiento / Superávit con kcal (−/+ de 50 en 50) y su % del GET. Luego calorías y macros del plan y «Usar estos valores en el plan».
- Cada comida es un bloque editable: horario, nombre, kcal (si se deja vacío se calcula con los macros), proteína, carbohidratos, grasa, alimentos, suplementos y días en que se repite (L–D; «Todos los días», «L–V», «Fin de semana»). Se puede duplicar o borrar. Abajo se ve el total contra la meta del plan.
- El atleta puede ajustar un bloque o agregar uno propio («Ajustar bloque» / «Agregar un bloque de comida»); se guarda en `pt_evo` (`nutadj_<correo>`, kind `nutAdj`) porque el atleta no escribe en `pt_athletes`. El coach ve el aviso y decide «Integrar al plan» o «Descartar sus ajustes».
- Calendario: el coach ve en cada día un recuadro naranja «🍽 n · kcal» (clic abre Nutrición); el atleta ve 🍽 en su calendario y en su agenda el recuadro «Hoy te toca comer» con horario, comida, kcal y macros.

**Cambios 19/11/2026:**
- Nutrición: el plan tiene fecha de inicio y de término (al crearlo y con «📅 Fechas del plan»). Los bloques de comida solo salen en el calendario dentro de ese periodo. «⏹ Terminar este plan» pide fecha y comentarios del porqué; el plan pasa a «Planes anteriores» con su comentario (también se puede escribir un comentario al reemplazarlo por uno nuevo).
- Ciclo: casilla visible «Ocultar recuadro de periodo menstrual» bajo el nombre de la clienta (además de la ficha). Es la misma llave `cycleMod`.
- Repetir: el entrenamiento completo y cada bloque usan periodo con fecha de inicio y término (atajos 1/4/8/12 semanas) en lugar de número de semanas. El bloque repetido siempre se guarda como sesión aparte con el nombre del bloque (ya no se suma a otro entrenamiento) y no se duplica si ese día ya tiene una sesión con ese nombre.

**Semáforo solo para el coach + check-in semanal + recuadro por comida (19/11/2026):**
- El atleta ya no ve el semáforo (se quitó de su pestaña Progreso). El coach lo sigue viendo en lista, ficha, calendario y estadísticas.
- Factores nuevos del semáforo (además de ACWR, cumplimiento, disposición del formulario de inicio, monotonía y pulso): formulario final de cada sesión («¿Cómo te sentiste?» 1–5), check-in semanal (fatiga, sueño, comida, descanso 1–5, el más reciente de 10 días) y apego a comidas (recuadros marcados vs. comidas programadas en 7 días; cumplida = 1, con cambios = 0.5). Umbrales: ≥3.5 → 0 · 2.5–3.4 → 1 · <2.5 → 2; comidas ≥80 % → 0 · 50–79 % → 1 · <50 % → 2.
- Check-in semanal: se abre solo al terminar el último entrenamiento programado de la semana; si no lo responde, queda una tarjeta «Check-in semanal pendiente» en su agenda (semana actual o la anterior). Se guarda en `pt_evo` kind `weekly` e incluye el % de comidas marcadas. El coach lo ve en la tarjeta del semáforo.
- Cada comida tiene un recuadro para marcarla como cumplida (agenda «Hoy te toca comer» y pestaña Nutrición). Se puede marcar hasta 2 días atrás. Usa los mismos registros `kind:'meal'` que los botones existentes.

## Repetir entrenamiento y bloques (21/11/2026)

- **Repetir una sesión ya asignada**: en el detalle de un entrenamiento del calendario hay un botón «🔁 Repetir». Se eligen días de la semana + periodo (inicia / termina) y/o fechas sueltas. Copia el entrenamiento completo (bloques, ejercicios, videos, adjuntos); cada copia empieza sin registros del atleta. Si un día ya tiene entrenamiento: omitir, agregarlo además o reemplazar el pendiente (nunca toca sesiones completadas).
- **Repetir un bloque** (ej. «Músculo rezagado»): ya no crea una sesión aparte con el nombre del bloque en cada día. Ahora se mete dentro del entrenamiento que ya existe ese día, en la misma posición; si esa sesión ya trae un bloque con ese nombre, se actualiza en lugar de duplicarse. Solo se crea una sesión con el nombre del bloque si ese día no hay entrenamiento. Los días que solo tienen sesiones completadas se omiten.

## Arrastrar sesiones a otro día (21/11/2026)

- En el calendario del coach cada tarea se puede arrastrar a otro día. Computadora: clic sostenido y arrastrar. Celular: mantener presionado ~medio segundo y arrastrar.
- Se guarda al soltar (igual que «Mover») y el atleta recibe el aviso. El mensaje de confirmación trae **Deshacer** por 7 segundos.
- Para cambiar de mes mientras arrastras, deja la tarea sobre las flechas ‹ › del calendario.
- Las sesiones ya completadas no se pueden mover. Si el día destino ya tiene otro entrenamiento, el aviso lo indica.

## Volumen total del entrenamiento (21/11/2026)

- Recuadro «📊 Volumen total» al final de cada entrenamiento (detalle de la sesión, vista coach) y en el editor (se actualiza mientras escribes).
- Suma series totales, repeticiones totales, ejercicios y minutos aeróbicos, con desglose por bloque.
- Reps «12» = 12 por serie; «8-12» se suma como rango mínimo–máximo; «12/10/8» suma cada serie. Reps por tiempo («30 s») o AMRAP no suman reps (sí series).
- En sesiones con registros del atleta muestra también series hechas y tonelaje (peso anotado × reps × series hechas; lb se convierte a kg).

## Nota opcional por ejercicio (21/11/2026)

- En el editor de sesión y en el editor de plantillas, cada ejercicio (incluido el aeróbico) tiene el botón «📝 ＋ Nota». Abre un campo de texto (máx. 400 caracteres) para casos especiales; el bote de basura la quita.
- El atleta la ve en un recuadro amarillo debajo de series × reps, y el ícono 📝 aparece junto al nombre del ejercicio aunque esté cerrado.
- Las notas de una plantilla pasan a las sesiones al asignar el plan. Excel: columna «Nota» al final (exportar y cargar).

## Unir bloques repetidos ya cargados (21/11/2026)

- Al entrar el coach, si hay sesiones sueltas creadas por el «Repetir bloque» anterior (sesión con el nombre del bloque en un día que ya tiene entrenamiento), aparece «🔁 Unir bloques repetidos» con el conteo por cliente.
- «Unir» mete el bloque dentro del entrenamiento de ese día (activación/rezagado/calentamiento al inicio; si ya lo trae, lo actualiza) y quita la sesión suelta. «Ahora no» lo vuelve a ofrecer en la siguiente sesión del navegador.
- Solo pendientes sin registros del atleta; las completadas no se tocan. Las sesiones de historial (plan anterior) no se pueden arrastrar.
