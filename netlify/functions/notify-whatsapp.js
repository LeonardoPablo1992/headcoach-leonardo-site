// Netlify Function: notifica por WhatsApp cuando alguien llena el
// formulario de contacto del sitio (usa Netlify Forms + Meta WhatsApp
// Cloud API). Netlify Forms llama a esta función automáticamente vía
// el "Outgoing webhook" configurado en Site settings → Forms → Notifications.
//
// Variables de entorno requeridas (configurar en Netlify, nunca en el código):
//   WHATSAPP_TOKEN         -> access token permanente de la app de Meta
//   WHATSAPP_PHONE_ID      -> phone_number_id del número de WhatsApp Business
//   WHATSAPP_TO_NUMBER     -> número de Leonardo en formato E.164 sin "+" (ej: 15647558301)
//   WHATSAPP_TEMPLATE_NAME -> nombre de la plantilla aprobada en Meta (ej: "nuevo_contacto")
//   WHATSAPP_TEMPLATE_LANG -> código de idioma de la plantilla (ej: "es" o "es_MX")

exports.handler = async function (event) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (e) {
    console.error('Webhook payload inválido:', event.body);
    return { statusCode: 400, body: 'Payload inválido' };
  }

  // Netlify Forms envía el payload con esta forma:
  // { form_name, data: { nombre, email, mensaje, ... }, ... }
  const data = payload.data || {};
  const nombre = String(data.nombre || 'Alguien').slice(0, 200);
  const email = String(data.email || 'Sin email').slice(0, 200);
  const mensaje = String(data.mensaje || '').slice(0, 500);

  const token = process.env.WHATSAPP_TOKEN;
  const phoneId = process.env.WHATSAPP_PHONE_ID;
  const toNumber = process.env.WHATSAPP_TO_NUMBER;
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME;
  const templateLang = process.env.WHATSAPP_TEMPLATE_LANG || 'es';

  if (!token || !phoneId || !toNumber || !templateName) {
    console.error('Faltan variables de entorno de WhatsApp. Revisa WHATSAPP_TOKEN, WHATSAPP_PHONE_ID, WHATSAPP_TO_NUMBER, WHATSAPP_TEMPLATE_NAME.');
    // Devolvemos 200 para que Netlify no reintente indefinidamente el webhook.
    return { statusCode: 200, body: 'Configuración de WhatsApp incompleta' };
  }

  // Mensaje vía plantilla aprobada (necesario para iniciar conversación sin
  // que el destinatario haya escrito primero). La plantilla debe tener 3
  // variables de cuerpo: {{1}} nombre, {{2}} email, {{3}} mensaje.
  const body = {
    messaging_product: 'whatsapp',
    to: toNumber,
    type: 'template',
    template: {
      name: templateName,
      language: { code: templateLang },
      components: [
        {
          type: 'body',
          parameters: [
            { type: 'text', text: nombre },
            { type: 'text', text: email },
            { type: 'text', text: mensaje || '(sin mensaje)' }
          ]
        }
      ]
    }
  };

  try {
    const resp = await fetch(
      'https://graph.facebook.com/v20.0/' + phoneId + '/messages',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify(body)
      }
    );

    const result = await resp.json();

    if (!resp.ok) {
      console.error('Error de Meta WhatsApp API:', JSON.stringify(result));
      return { statusCode: 200, body: 'Error al enviar WhatsApp (ver logs)' };
    }

    console.log('WhatsApp enviado:', JSON.stringify(result));
    return { statusCode: 200, body: 'OK' };
  } catch (err) {
    console.error('Error de conexión al enviar WhatsApp:', err);
    return { statusCode: 200, body: 'Error de conexión' };
  }
};
