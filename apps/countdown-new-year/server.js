'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

loadEnvFile(path.join(__dirname, '.env'));

const PORT = parseInt(process.env.PORT, 10) || 3000;
const TIMEZONE = resolveTimezone(process.env.TIMEZONE || 'UTC');
const PRIMARY_COLOR = resolveColor(process.env.PRIMARY_COLOR, '#7c3aed');
const SECONDARY_COLOR = resolveColor(process.env.SECONDARY_COLOR, '#06b6d4');
const PUBLIC_DIR = path.join(__dirname, 'public');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

// Minimal .env loader so the app also runs outside Docker without dependencies.
// Variables already present in the environment take precedence.
function loadEnvFile(file) {
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!match || process.env[match[1]] !== undefined) continue;
    process.env[match[1]] = match[2].replace(/^(['"])(.*)\1$/, '$2');
  }
}

function resolveTimezone(tz) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return tz;
  } catch {
    console.warn(`TIMEZONE "${tz}" no es válida, usando UTC`);
    return 'UTC';
  }
}

function resolveColor(value, fallback) {
  if (!value) return fallback;
  const valid = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(value) ||
    /^(rgb|rgba|hsl|hsla)\([\d\s.,%]+\)$/i.test(value) ||
    /^[a-z]+$/i.test(value);
  if (!valid) {
    console.warn(`Color "${value}" no es válido, usando ${fallback}`);
    return fallback;
  }
  return value;
}

// Wall-clock parts of `date` as seen in `timeZone`.
function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric', month: 'numeric', day: 'numeric',
    hour: 'numeric', minute: 'numeric', second: 'numeric',
  }).formatToParts(date);
  const get = (type) => parseInt(parts.find((p) => p.type === type).value, 10);
  return { year: get('year'), month: get('month'), day: get('day'),
    hour: get('hour'), minute: get('minute'), second: get('second') };
}

// Offset (ms) between the time zone's wall clock and UTC at instant `date`.
function zoneOffset(date, timeZone) {
  const p = zonedParts(date, timeZone);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return asUtc - Math.floor(date.getTime() / 1000) * 1000;
}

// UTC timestamp of January 1st 00:00:00 of `year` in `timeZone`.
function startOfYear(year, timeZone) {
  const naive = Date.UTC(year, 0, 1);
  let ts = naive - zoneOffset(new Date(naive), timeZone);
  // Second pass corrects for offset changes (DST) around the guess.
  ts = naive - zoneOffset(new Date(ts), timeZone);
  return ts;
}

function countdownConfig() {
  const now = Date.now();
  const { year } = zonedParts(new Date(now), TIMEZONE);
  return {
    timezone: TIMEZONE,
    primaryColor: PRIMARY_COLOR,
    secondaryColor: SECONDARY_COLOR,
    currentYear: year,
    nextYear: year + 1,
    yearStart: startOfYear(year, TIMEZONE),
    newYear: startOfYear(year + 1, TIMEZONE),
    serverNow: now,
  };
}

function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

function serveStatic(req, res) {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const filePath = path.normalize(path.join(PUBLIC_DIR, urlPath === '/' ? 'index.html' : urlPath));
  if (!filePath.startsWith(PUBLIC_DIR + path.sep)) {
    res.writeHead(403).end('Forbidden');
    return;
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': MIME_TYPES[path.extname(filePath)] || 'application/octet-stream' });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405).end('Method not allowed');
    return;
  }
  if (req.url === '/api/config') return sendJson(res, 200, countdownConfig());
  if (req.url === '/health') return sendJson(res, 200, { status: 'ok' });
  serveStatic(req, res);
});

server.listen(PORT, () => {
  console.log(`Cuenta regresiva escuchando en http://localhost:${PORT} (zona horaria: ${TIMEZONE})`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
