'use strict';

(() => {
  const $ = (id) => document.getElementById(id);
  const els = {
    nextYear: $('next-year'), currentYear: $('current-year'), timezone: $('timezone'),
    days: $('days'), hours: $('hours'), minutes: $('minutes'), seconds: $('seconds'),
    percent: $('percent'), fill: $('fill'), bar: $('bar'), remaining: $('remaining'),
    celebration: $('celebration'),
  };

  let config = null;
  let clockSkew = 0; // serverNow - clientNow, so the client follows the server's clock
  let timer = null;
  let celebrating = false;

  async function loadConfig() {
    const res = await fetch('/api/config', { cache: 'no-store' });
    config = await res.json();
    clockSkew = config.serverNow - Date.now();

    const root = document.documentElement.style;
    root.setProperty('--primary', config.primaryColor);
    root.setProperty('--secondary', config.secondaryColor);

    els.nextYear.textContent = config.nextYear;
    els.currentYear.textContent = config.currentYear;
    els.timezone.textContent = config.timezone;
    document.title = `Cuenta regresiva a ${config.nextYear}`;
  }

  const pad = (n) => String(n).padStart(2, '0');

  function setValue(el, text) {
    if (el.textContent === text) return;
    el.textContent = text;
    el.classList.remove('tick');
    void el.offsetWidth; // restart the animation
    el.classList.add('tick');
  }

  function render() {
    const now = Date.now() + clockSkew;
    const remainingMs = Math.max(0, config.newYear - now);
    const total = config.newYear - config.yearStart;
    const progress = Math.min(100, Math.max(0, ((now - config.yearStart) / total) * 100));

    const secs = Math.floor(remainingMs / 1000);
    setValue(els.days, String(Math.floor(secs / 86400)));
    setValue(els.hours, pad(Math.floor((secs % 86400) / 3600)));
    setValue(els.minutes, pad(Math.floor((secs % 3600) / 60)));
    setValue(els.seconds, pad(secs % 60));

    els.fill.style.width = `${progress}%`;
    els.bar.setAttribute('aria-valuenow', progress.toFixed(2));
    els.percent.textContent = `${progress.toFixed(4)}%`;
    els.remaining.textContent = remainingMs > 0
      ? `Falta el ${(100 - progress).toFixed(4)}% del año para llegar a ${config.nextYear}`
      : `¡Bienvenido ${config.nextYear}!`;

    if (remainingMs === 0 && !celebrating) celebrate();
  }

  function celebrate() {
    celebrating = true;
    els.celebration.classList.remove('hidden');
    launchConfetti(15000);
    // After the party, restart the countdown for the following year.
    setTimeout(async () => {
      celebrating = false;
      els.celebration.classList.add('hidden');
      await loadConfig();
      render();
    }, 60000);
  }

  function launchConfetti(duration) {
    const canvas = $('confetti');
    const ctx = canvas.getContext('2d');
    const colors = [config.primaryColor, config.secondaryColor, '#facc15', '#f472b6', '#ffffff'];
    const resize = () => { canvas.width = innerWidth; canvas.height = innerHeight; };
    resize();
    addEventListener('resize', resize);

    const pieces = Array.from({ length: 220 }, () => ({
      x: Math.random() * canvas.width,
      y: Math.random() * -canvas.height,
      size: 6 + Math.random() * 6,
      speed: 2 + Math.random() * 4,
      drift: -1 + Math.random() * 2,
      rotation: Math.random() * 360,
      spin: -6 + Math.random() * 12,
      color: colors[Math.floor(Math.random() * colors.length)],
    }));

    const end = performance.now() + duration;
    (function frame(t) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const p of pieces) {
        p.y += p.speed;
        p.x += p.drift;
        p.rotation += p.spin;
        if (p.y > canvas.height && t < end) { p.y = -20; p.x = Math.random() * canvas.width; }
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate((p.rotation * Math.PI) / 180);
        ctx.fillStyle = p.color;
        ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
        ctx.restore();
      }
      if (t < end || pieces.some((p) => p.y <= canvas.height)) requestAnimationFrame(frame);
      else { ctx.clearRect(0, 0, canvas.width, canvas.height); removeEventListener('resize', resize); }
    })(performance.now());
  }

  async function start() {
    try {
      await loadConfig();
    } catch (err) {
      els.remaining.textContent = 'No se pudo cargar la configuración del servidor.';
      console.error(err);
      return;
    }
    render();
    clearInterval(timer);
    timer = setInterval(render, 250);
  }

  start();
})();
