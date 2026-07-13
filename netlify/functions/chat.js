// Netlify Function: chatbot del sitio de Leonardo Pablo (Head Coach)
// Usa la API gratuita de Google Gemini. La API key vive en la variable
// de entorno GEMINI_API_KEY (configurada en Netlify, nunca en el código).

const SYSTEM_CONTEXT = `
Eres el asistente virtual del sitio web de Leonardo Pablo, "Head Coach",
entrenador personal con más de 12 años de experiencia.

Información del negocio:
- Planes: Fuerza y Musculación, Preparación Deportiva (fondos largos y cortos:
  running, triatlón, ciclismo, aguas abiertas), Entrenamiento Femenino,
  Cambio de Hábito, y Capacitación a Gimnasios y Entrenadores.
- Metodología: mesociclos de 12 semanas (Semanas 1-4 Adaptación, 5-8
  Acumulación, 9-12 Rendimiento), siempre acompañados de un perfil
  nutricional personalizado.
- Cada atleta tiene una página de seguimiento personalizada con
  estadísticas de progreso mensuales.
- Contacto: teléfono 564 755 8301, email leonardotorres_lt@icloud.com,
  o el formulario de la sección "Contacto" del sitio.

Instrucciones de estilo:
- Responde en español, de forma breve, cercana y profesional (máximo
  4-5 oraciones).
- No inventes precios, horarios ni disponibilidad específica: si te
  preguntan por precio o para agendar, invita a dejar sus datos en el
  formulario de contacto o a escribir directamente a Leonardo.
- No des consejos médicos ni planes de entrenamiento detallados;
  anima a agendar una valoración con Leonardo.
- Si la pregunta no tiene relación con el entrenamiento o el sitio,
  responde brevemente y redirige la conversación hacia cómo Leonardo
  puede ayudar.
`.trim();

exports.handler = async function (event) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (e) {
    return { statusCode: 400, body: JSON.stringify({ reply: 'Solicitud inválida.' }) };
  }

  const message = String(payload.message || '').slice(0, 1000).trim();
  const history = Array.isArray(payload.history) ? payload.history.slice(-10) : [];

  if (!message) {
    return { statusCode: 400, body: JSON.stringify({ reply: 'Escribe un mensaje.' }) };
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return {
      statusCode: 500,
      body: JSON.stringify({ reply: 'El asistente todavía no está configurado. Escríbeme a leonardotorres_lt@icloud.com.' })
    };
  }

  const contents = [
    { role: 'user', parts: [{ text: SYSTEM_CONTEXT }] },
    { role: 'model', parts: [{ text: 'Entendido, responderé como el asistente virtual de Leonardo Pablo siguiendo esas indicaciones.' }] }
  ];

  history.forEach(function (h) {
    contents.push({
      role: h && h.role === 'model' ? 'model' : 'user',
      parts: [{ text: String((h && h.text) || '').slice(0, 1000) }]
    });
  });

  contents.push({ role: 'user', parts: [{ text: message }] });

  try {
    const resp = await fetch(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=' + apiKey,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: contents,
          generationConfig: { maxOutputTokens: 300, temperature: 0.6 }
        })
      }
    );

    const data = await resp.json();

    if (!resp.ok) {
      console.error('Gemini API error:', JSON.stringify(data));
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reply: 'No pude generar una respuesta en este momento. Escríbeme directo a leonardotorres_lt@icloud.com.' })
      };
    }

    const reply =
      data &&
      data.candidates &&
      data.candidates[0] &&
      data.candidates[0].content &&
      data.candidates[0].content.parts &&
      data.candidates[0].content.parts[0] &&
      data.candidates[0].content.parts[0].text;

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        reply: reply || 'No pude generar una respuesta en este momento. Escríbeme directo a leonardotorres_lt@icloud.com.'
      })
    };
  } catch (err) {
    console.error('Chat function error:', err);
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reply: 'Ocurrió un error de conexión. Intenta de nuevo en un momento.' })
    };
  }
};
