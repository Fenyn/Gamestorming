// Takes an in-game bug or feedback report and posts it to a Discord forum channel, where each
// report opens its own thread. The webhook URL is a Worker secret and never ships in the game.
//
// POST /report, JSON:
//   kind         "bug" | "feedback"
//   title        the thread title
//   description  what the player wrote
//   details      game details as plain text (version, platform, scene, duel state, log tail)
//   screenshot   optional base64 JPEG
//   version, platform  short strings for the post's footer line

const MAX_BODY = 6 * 1024 * 1024;
const MAX_SCREENSHOT = 4 * 1024 * 1024;
const MAX_TITLE = 90;
const MAX_DESCRIPTION = 6000;
const MAX_DETAILS = 60000;
// Discord's limits: a thread name is at most 100 characters, a message at most 2000.
const THREAD_NAME = 100;
const POST_TEXT = 1800;
const KINDS = { bug: "Bug", feedback: "Feedback" };

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Zenith-Key",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/report") {
      return reply(404, "not found");
    }
    const webhook = webhookUrl(env.DISCORD_WEBHOOK);
    if (!webhook) {
      return reply(500, "the report channel is not set up");
    }
    if (request.headers.get("X-Zenith-Key") !== env.REPORT_KEY) {
      return reply(403, "this build cannot send reports");
    }
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    if (env.REPORT_LIMIT) {
      const { success } = await env.REPORT_LIMIT.limit({ key: ip });
      if (!success) {
        return reply(429, "too many reports in a short time; please wait a minute");
      }
    }
    if (Number(request.headers.get("Content-Length") || 0) > MAX_BODY) {
      return reply(413, "the report is too large");
    }

    let report;
    try {
      report = await request.json();
    } catch {
      return reply(400, "the report could not be read");
    }

    const kind = KINDS[report.kind] ? report.kind : "bug";
    const title = clean(report.title, MAX_TITLE) || "Untitled report";
    const description = clean(report.description, MAX_DESCRIPTION, true);
    const details = clean(report.details, MAX_DETAILS, true);
    const footer = [clean(report.version, 40), clean(report.platform, 40)].filter(Boolean).join(" · ");

    let text = description || "(no description)";
    if (text.length > POST_TEXT) {
      text = text.slice(0, POST_TEXT) + "\n… (the full text is in report.txt)";
    }
    if (footer) {
      text += "\n-# " + footer;
    }

    const payload = {
      thread_name: `[${KINDS[kind]}] ${title}`.slice(0, THREAD_NAME),
      content: text,
      // Nothing a player types may ping anyone.
      allowed_mentions: { parse: [] },
    };
    const tag = kind === "bug" ? env.TAG_BUG : env.TAG_FEEDBACK;
    if (tag) {
      payload.applied_tags = [tag];
    }

    const form = new FormData();
    form.append("payload_json", JSON.stringify(payload));
    const fullText = `${KINDS[kind]}: ${title}\n\n${description}\n\n--- Game details ---\n${details}\n`;
    form.append("files[0]", new Blob([fullText], { type: "text/plain" }), "report.txt");
    if (typeof report.screenshot === "string" && report.screenshot.length > 0) {
      const shot = decodeBase64(report.screenshot);
      if (shot && shot.length <= MAX_SCREENSHOT) {
        form.append("files[1]", new Blob([shot], { type: "image/jpeg" }), "screenshot.jpg");
      }
    }

    webhook.searchParams.set("wait", "true");
    const sent = await fetch(webhook, { method: "POST", body: form });
    if (!sent.ok) {
      console.log("discord refused the report", sent.status, await sent.text());
      return reply(502, "the report channel refused the report");
    }
    return reply(200, "sent");
  },
};

// The secret as a Discord webhook URL, or null when it is missing or is not one (a blank or
// mangled paste at `wrangler secret put`).
function webhookUrl(secret) {
  try {
    const url = new URL(String(secret || "").trim());
    const discord = url.hostname === "discord.com" || url.hostname === "discordapp.com" || url.hostname.endsWith(".discord.com");
    return url.protocol === "https:" && discord && url.pathname.startsWith("/api/webhooks/") ? url : null;
  } catch {
    return null;
  }
}

function reply(status, message) {
  return new Response(JSON.stringify({ ok: status === 200, message }), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// A string, trimmed and capped, with control characters dropped (newlines kept when `multiline`).
function clean(value, max, multiline = false) {
  if (typeof value !== "string") {
    return "";
  }
  const pattern = multiline ? /[\u0000-\u0008\u000B-\u001F\u007F]/g : /[\u0000-\u001F\u007F]/g;
  return value.replace(pattern, "").trim().slice(0, max);
}

function decodeBase64(text) {
  try {
    const raw = atob(text);
    const bytes = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) {
      bytes[i] = raw.charCodeAt(i);
    }
    return bytes;
  } catch {
    return null;
  }
}
