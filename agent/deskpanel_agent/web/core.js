/* DeskPanel desk page, core: connection to the laptop agent, the live topic store, the
   concept 16 building blocks (glass card, ring, bar, slider, buttons, icons, charts), the
   shell (sidebar, title, wallpaper) and the binding refresh loop.

   Pages (pages_*.js) register with DP.page(id, { render, sig, title?, sub? }):
   - render() returns the page HTML, built only from DP.T (topics) and DP.S (page state).
   - sig() returns a short string of the page's *structure* (ids, statuses, play state...);
     the page is re-rendered only when it changes. Fast-changing numbers go through
     bindings instead, refreshed in place on every update and every second:
       data-b="name"   text from DP.B[name]()
       data-p="name"   CSS --p (0..1) from DP.PB[name]()  (bars, sliders)
       data-arc="name" ring fill from DP.PB[name]()
       data-c="name"   chart SVG from DP.charts[name](el)
   - Clicks: data-act="name" data-v="value" calls DP.A[name](value, event, element).
   Everything shown from the agent goes through DP.esc() (Slack text, titles, ...). */
(() => {
'use strict';

/* ---------- Small helpers ---------- */
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pad = n => String(n).padStart(2, '0');
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const DAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const DAY3 = DAY.map(d => d.slice(0, 3));
const MONTH = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const MON3 = MONTH.map(m => m.slice(0, 3));
const H12 = (() => { try { return new Intl.DateTimeFormat(undefined, { hour: 'numeric' }).resolvedOptions().hour12 !== false; } catch { return true; } })();
const now = () => new Date();
const clock = d => H12 ? (d.getHours() % 12 || 12) + ':' + pad(d.getMinutes()) : pad(d.getHours()) + ':' + pad(d.getMinutes());
const ampm = d => H12 ? (d.getHours() < 12 ? 'AM' : 'PM') : '';
const timeStr = d => H12 ? `${clock(d)} ${ampm(d)}` : clock(d);
const hourStr = d => H12 ? `${d.getHours() % 12 || 12} ${ampm(d)}` : pad(d.getHours()) + ':00';
const dur = min => { min = Math.max(0, Math.round(min)); const h = Math.floor(min / 60), m = min % 60; if (h >= 48) return `${Math.floor(h / 24)}d ${h % 24}h`; return h ? `${h}h ${m}m` : `${m}m`; };
const ms = s => { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ':' + pad(s % 60); };
const ago = t => { if (!t) return 'never'; const m = (Date.now() - t) / 60000; if (m < 1) return 'just now'; if (m < 60) return `${Math.round(m)} min ago`; if (m < 48 * 60) return `${Math.round(m / 60)} h ago`; return `${Math.round(m / 1440)} days ago`; };
const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
/* Bytes (sizes): "3.2 GB". Rates in bytes/s: {v:"1.8", u:"MB/s"}. Bits/s (speed tests): Mbps. */
const bytes = (b, dp = 1) => { b = +b || 0; const u = ['B', 'KB', 'MB', 'GB', 'TB']; let i = 0; while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; } return (i ? b.toFixed(b >= 100 ? 0 : dp) : Math.round(b)) + ' ' + u[i]; };
const rate = bps => { bps = +bps || 0; if (bps >= 1e6) return { v: (bps / 1e6).toFixed(bps >= 1e8 ? 0 : 1), u: 'MB/s' }; return { v: String(Math.round(bps / 1e3)), u: 'KB/s' }; };
const compact = n => { n = +n || 0; const a = Math.abs(n); return a >= 1e9 ? (n / 1e9).toFixed(1) + 'B' : a >= 1e6 ? (n / 1e6).toFixed(1) + 'M' : a >= 1e4 ? Math.round(n / 1e3) + 'K' : a >= 1e3 ? (n / 1e3).toFixed(1) + 'K' : String(Math.round(n)); };
const mbps = bps => { const m = (+bps || 0) / 1e6; return m >= 100 ? m.toFixed(0) : m.toFixed(1); };
const hash = s => { let h = 2166136261; for (const c of String(s || '')) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; };
const store = {
  get(k, d) { try { const v = localStorage.getItem('dp.' + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('dp.' + k, JSON.stringify(v)); } catch { /* private mode */ } }
};

/* ---------- State ---------- */
const T = {};          // topic -> latest data (full snapshot from the agent)
const S = {            // page state
  page: store.get('page', 'home'), sysTab: 'pc', conn: 'connecting', glass: store.get('glass', 'clear'),
  host: '', agent: null, offset: 0, lastSync: null
};

/* ---------- Icons (24px, stroke = currentColor): the concept's set plus a few for live data ---------- */
const P = {
  home: '<path d="M3.5 10.5 12 3.5l8.5 7V20a.5.5 0 0 1-.5.5h-5v-6H9v6H4a.5.5 0 0 1-.5-.5z"/>',
  system: '<path d="M3 16.5 8 11l4 3.5 4.5-6.5 4.5 4"/><path d="M3 20.5h18"/>',
  claude: '<path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6 5.6 18.4"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  weather: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
  music: '<path d="M9 18V5.5l11-2V16"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
  hotspot: '<path d="M12 12v9M8.5 21h7"/><circle cx="12" cy="10" r="1.6"/><path d="M8.2 6.2a5.4 5.4 0 0 0 0 7.6M15.8 6.2a5.4 5.4 0 0 1 0 7.6M5.4 3.4a9.4 9.4 0 0 0 0 13.2M18.6 3.4a9.4 9.4 0 0 1 0 13.2"/>',
  timer: '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 9.5v4l2.5 2M9.5 2.5h5"/>',
  slack: '<path d="M4.5 5.5h15a1 1 0 0 1 1 1v9.5a1 1 0 0 1-1 1h-9l-4.5 3.5V17h-1.5a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1z"/><path d="M8 10h8M8 13h5"/>',
  github: '<circle cx="12" cy="12" r="3.5"/><path d="M2.5 12h6M15.5 12h6"/>',
  shortcuts: '<rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/>',
  monitor: '<rect x="2.5" y="4" width="19" height="12.5" rx="2"/><path d="M8.5 20.5h7M12 16.5v4"/>',
  wifi: '<path d="M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.7 15.8a5 5 0 0 1 6.6 0"/><circle cx="12" cy="19.3" r="1.1" fill="currentColor" stroke="none"/>',
  usb: '<path d="M9 2.5v4.5M15 2.5v4.5M6.5 7h11v4a5.5 5.5 0 0 1-11 0zM12 16.5v5"/>',
  off: '<path d="M2.5 9a14 14 0 0 1 4.2-2.8M10.5 5.6A14 14 0 0 1 21.5 9M8.7 15.8a5 5 0 0 1 6.6 0M3 3l18 18"/>',
  cloud: '<path d="M7 18.5h10.5a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.6 9.7 4.4 4.4 0 0 0 7 18.5z"/>',
  partly: '<path d="M9.5 6.5V4.5M4.4 8.6l-1.4-1.4M14.6 8.6 16 7.2M3.5 13.5h-1"/><path d="M6.4 12.3a3.8 3.8 0 0 1 6.9-2.8"/><path d="M9 20h9a3.3 3.3 0 0 0 .5-6.55A5 5 0 0 0 8.8 12.7 3.7 3.7 0 0 0 9 20z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
  moon: '<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"/>',
  rain: '<path d="M7 15h10.5a3.6 3.6 0 0 0 .5-7.15A5.5 5.5 0 0 0 7.4 7.2 3.9 3.9 0 0 0 7 15z"/><path d="M8.5 18l-1 2.5M12.5 18l-1 2.5M16.5 18l-1 2.5"/>',
  storm: '<path d="M7 14h10.5a3.6 3.6 0 0 0 .5-7.15A5.5 5.5 0 0 0 7.4 6.2 3.9 3.9 0 0 0 7 14z"/><path d="M12.5 14.5 10 18.5h4l-2.5 4"/>',
  snow: '<path d="M7 14h10.5a3.6 3.6 0 0 0 .5-7.15A5.5 5.5 0 0 0 7.4 6.2 3.9 3.9 0 0 0 7 14z"/><path d="M8.5 18h.01M12 20h.01M15.5 18h.01M10 21.5h.01M14 21.5h.01" stroke-width="2.6"/>',
  fog: '<path d="M4 9.5h16M3 13.5h18M5 17.5h14"/>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5v3.5"/>',
  micOff: '<path d="M15 10V6a3 3 0 0 0-5.7-1.3M9 9v2a3 3 0 0 0 4.9 2.3M5.5 11a6.5 6.5 0 0 0 10.9 4.8M18.5 11c0 .7-.1 1.4-.3 2M12 17.5v3.5M3.5 3.5l17 17"/>',
  speaker: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9.5a3.5 3.5 0 0 1 0 5M18 7a7 7 0 0 1 0 10"/>',
  speakerOff: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9.5l5 5M20.5 9.5l-5 5"/>',
  volDown: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 12h5"/>',
  volUp: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 12h5M18 9.5v5"/>',
  shot: '<path d="M4 8.5V5.5a1 1 0 0 1 1-1h3M16 4.5h3a1 1 0 0 1 1 1v3M20 15.5v3a1 1 0 0 1-1 1h-3M8 19.5H5a1 1 0 0 1-1-1v-3"/><circle cx="12" cy="12" r="2.5"/>',
  terminal: '<rect x="2.5" y="4" width="19" height="16" rx="2"/><path d="M7 9.5l2.8 2.5L7 14.5M12.5 15h4.5"/>',
  folder: '<path d="M3 6.5a1 1 0 0 1 1-1h5l2 2.2h9a1 1 0 0 1 1 1V18a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/>',
  lock: '<rect x="4.5" y="10.5" width="15" height="10" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
  play: '<path d="M8 5.2v13.6L19 12z" fill="currentColor"/>',
  pause: '<rect x="6.5" y="5" width="3.8" height="14" rx="1" fill="currentColor" stroke="none"/><rect x="13.7" y="5" width="3.8" height="14" rx="1" fill="currentColor" stroke="none"/>',
  prev: '<path d="M6 5.5v13"/><path d="M18.5 5.5 9 12l9.5 6.5z" fill="currentColor"/>',
  next: '<path d="M18 5.5v13"/><path d="M5.5 5.5 15 12l-9.5 6.5z" fill="currentColor"/>',
  reset: '<path d="M4 12a8 8 0 1 0 2.6-5.9L4 8.5M4 3.5v5h5"/>',
  flame: '<path d="M12 3s5 4.3 5 9.3a5 5 0 0 1-10 0c0-2.8 2-3.9 2.3-6.3C10.8 7.3 12 3 12 3z"/>',
  thermo: '<path d="M10 14.3V5a2 2 0 0 1 4 0v9.3a4 4 0 1 1-4 0z"/>',
  down: '<path d="M12 4.5v15M6.5 14l5.5 5.5 5.5-5.5"/>',
  up: '<path d="M12 19.5v-15M6.5 10 12 4.5l5.5 5.5"/>',
  drop: '<path d="M12 3.5s6 6.3 6 10.5a6 6 0 0 1-12 0c0-4.2 6-10.5 6-10.5z"/>',
  wind: '<path d="M3 8.5h10.5a2.5 2.5 0 1 0-2.5-2.5M3 12.5h15a2.5 2.5 0 1 1-2.5 2.5M3 16.5h7"/>',
  users: '<circle cx="9" cy="8.5" r="3.2"/><path d="M3 19.5a6 6 0 0 1 12 0M15.5 5.6a3.2 3.2 0 0 1 0 5.8M17.5 14a6 6 0 0 1 3.5 5.5"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  pin: '<path d="M12 21s6.5-6 6.5-11a6.5 6.5 0 0 0-13 0c0 5 6.5 11 6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
  battery: '<rect x="2.5" y="7" width="17" height="10" rx="2.2"/><path d="M21.5 10.5v3"/>',
  bolt: '<path d="M13 2.5 5.5 13.5H12l-1 8 7.5-11H12z"/>',
  signal: '<path d="M4 20v-3M9 20v-6M14 20v-9M19 20V5"/>',
  check: '<path d="M4.5 12.5 9.5 17.5 19.5 6.5"/>',
  checks: '<path d="M2.5 12.5 7 17l10-11M11.5 16 13 17.5l9-11"/>',
  open: '<path d="M14 4.5h5.5V10M19.5 4.5 11 13M18.5 14.5v4a1 1 0 0 1-1 1h-12a1 1 0 0 1-1-1v-12a1 1 0 0 1 1-1h4"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5l5 5"/>',
  alert: '<path d="M12 3.5 2.5 20h19z"/><path d="M12 10v4.5"/><circle cx="12" cy="17.3" r=".9" fill="currentColor" stroke="none"/>',
  at: '<circle cx="12" cy="12" r="3.8"/><path d="M15.8 12v1.6a2.6 2.6 0 0 0 5.2 0V12a9 9 0 1 0-3.6 7.2"/>',
  hash: '<path d="M9.5 3.5 7.5 20.5M16.5 3.5l-2 17M4 9h16.5M3.5 15H20"/>',
  vol_down: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 12h5"/>',
  vol_up: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 12h5M18 9.5v5"/>',
  screenshot: '<path d="M4 8.5V5.5a1 1 0 0 1 1-1h3M16 4.5h3a1 1 0 0 1 1 1v3M20 15.5v3a1 1 0 0 1-1 1h-3M8 19.5H5a1 1 0 0 1-1-1v-3"/><circle cx="12" cy="12" r="2.5"/>',
  bolt2: '<path d="M13 2.5 5.5 13.5H12l-1 8 7.5-11H12z"/>'
};
const icon = (n, cls = '') => `<svg class="ic ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[n] || P.shortcuts}</svg>`;

/* ---------- Generated cover art (the concept's "sun over hills"), seeded by a title ---------- */
let uid = 0;
function art(hue, seed = 1, opts = {}) {
  const id = 'a' + (++uid), W = opts.w || 100, k = W / 100;
  const sx = (28 + (seed * 37) % 44) * k, sy = 30 + (seed * 13) % 14;
  const sat = opts.sat ?? 58;
  return `<svg class="art" viewBox="0 0 ${W} 100" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="hsl(${hue} ${sat}% 20%)"/><stop offset="1" stop-color="hsl(${hue + 18} ${sat + 8}% 44%)"/></linearGradient></defs>
    <rect width="${W}" height="100" fill="url(#${id})"/>
    <circle cx="${sx}" cy="${sy}" r="15" fill="hsl(44 96% 82%)"/>
    <g transform="scale(${k} 1)"><path d="M0 64 C 22 55 42 70 66 60 S 100 56 100 56 V100 H0z" fill="hsl(${hue + 6} ${sat - 10}% 30%)"/>
    <path d="M0 78 C 28 70 58 86 100 72 V100 H0z" fill="hsl(${hue} ${sat}% 15%)"/></g></svg>`;
}

/* ---------- Chart helpers ---------- */
function linePath(vals, w, h, lo, hi, pad = 2) {
  vals = vals.map(v => v == null || !isFinite(v) ? lo : v);
  if (vals.length < 2) vals = [vals[0] ?? lo, vals[0] ?? lo];
  const n = vals.length, dx = w / (n - 1);
  const y = v => pad + (h - 2 * pad) * (1 - (clamp(v, lo, hi) - lo) / (hi - lo || 1));
  let d = `M0 ${y(vals[0]).toFixed(1)}`;
  for (let i = 1; i < n; i++) {
    const x0 = (i - 1) * dx, x1 = i * dx, xm = (x0 + x1) / 2;
    d += ` C${xm.toFixed(1)} ${y(vals[i - 1]).toFixed(1)} ${xm.toFixed(1)} ${y(vals[i]).toFixed(1)} ${x1.toFixed(1)} ${y(vals[i]).toFixed(1)}`;
  }
  return d;
}
function arc(cx, cy, r, a0, a1) {
  const p = a => [cx + r * Math.cos((a - 90) * Math.PI / 180), cy + r * Math.sin((a - 90) * Math.PI / 180)];
  const [x0, y0] = p(a0), [x1, y1] = p(a1);
  return `M${x0.toFixed(2)} ${y0.toFixed(2)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`;
}
const size = el => [Math.max(10, el.clientWidth), Math.max(10, el.clientHeight)];

/* ---------- Concept building blocks ---------- */
const card = (inner, o = {}) => `<div class="glass card ${o.cls || ''}" style="${o.st || ''}" ${o.go ? `role="button" tabindex="0" data-act="go" data-v="${o.go}"` : ''}>${inner}</div>`;
const ring = (k, inner, sz, o = {}) => `<div class="ring" style="width:${sz}px"><svg viewBox="0 0 100 100" aria-hidden="true"><circle cx="50" cy="50" r="42" fill="none" stroke="rgba(255,255,255,.2)" stroke-width="${o.sw || 9}"/>
  <circle class="fill" ${k ? `data-arc="${k}"` : ''} cx="50" cy="50" r="42" pathLength="100" stroke-dasharray="100 100" ${o.p != null ? `style="stroke-dashoffset:${(100 - clamp(o.p, 0, 1) * 100).toFixed(2)}"` : ''} fill="none" stroke="${o.c || '#fff'}" stroke-width="${o.sw || 9}" stroke-linecap="round"/></svg><div style="position:relative;text-align:center">${inner}</div></div>`;
const bar = (p, c = '#fff', st = '') => `<div class="bar" ${p ? `data-p="${p}"` : ''} style="--bc:${c};${st}"><i></i></div>`;
const slider = (k, act = '', st = '', label = 'Seek') => `<div class="slider" data-p="${k}" ${act ? `data-act="${act}" role="slider" aria-label="${label}"` : ''} style="${st}"><div class="trk"><i></i></div><div class="glass knob lensed"></div></div>`;
const gbtn = (inner, act, v = '', cls = '', attr = '') => `<button class="glass gbtn lensed ${cls}" data-act="${act}" ${v !== '' ? `data-v="${esc(v)}"` : ''} ${attr}><span style="display:inline-flex;align-items:center;gap:8px">${inner}</span></button>`;
const seg = (items, cur, act) => `<div class="glass seg">${items.map(([v, l]) => `<button data-act="${act}" data-v="${v}" aria-pressed="${v === cur}">${l}</button>`).join('')}</div>`;
const pill = (inner, st = '') => `<span class="glass pill" style="${st}">${inner}</span>`;
/* A card body for a topic that isn't "ok": loading, not set up, error. */
function note(topic, what) {
  const d = T[topic];
  if (!d) return `<div class="note"><b>${S.conn === 'live' ? 'Loading…' : 'Waiting for the laptop'}</b><span>${what}</span></div>`;
  const head = { unconfigured: 'Not set up yet', error: 'Something went wrong', unsupported: 'Not available on this laptop', starting: 'Starting…' }[d.status] || 'Unavailable';
  return `<div class="note"><b>${head}</b><span>${esc(d.message || what)}</span></div>`;
}
const ok = topic => T[topic] && T[topic].status === 'ok' ? T[topic] : null;

/* ---------- Live derived values used across pages ---------- */
const media = () => { const m = ok('media'); return m && m.title ? m : null; };
const posMs = () => { const m = media(); if (!m) return 0; let p = m.position_ms || 0; if (m.playing && m.position_at) p += (Date.now() + S.offset - m.position_at) * (m.rate || 1); return clamp(p, 0, m.duration_ms || p); };
const artFor = (m, opts) => {
  const a = T['media.art'];
  if (m && a && a.b64 && a.art_id === m.art_id) return `<img class="art" alt="" src="data:${a.mime || 'image/jpeg'};base64,${a.b64}">`;
  const h = hash(m ? m.album || m.title : 'none');
  return art(h % 360, (h >>> 9) % 7 + 1, opts);
};
const cpuTemp = s => s && s.cpu && s.cpu.temp_c != null ? Math.round(s.cpu.temp_c) + '°C' : '';
const calEvents = () => { const c = ok('calendar'); return c ? (c.events || []).slice().sort((a, b) => a.start - b.start) : []; };
const dayBounds = () => { const a = new Date(); a.setHours(0, 0, 0, 0); return [a.getTime(), a.getTime() + 864e5]; };
/* Timed events touching today (including ones that started yesterday and run into today). */
const todayEvents = () => { const [a, b] = dayBounds(); return calEvents().filter(e => !e.all_day && e.start < b && (e.end || e.start) > a); };
const nextEvent = () => { const t = Date.now(); return todayEvents().find(e => (e.end || e.start) > t) || null; };

/* ---------- Weather (browser-side, Open-Meteo: free, no key). °C, km/h. ---------- */
const WMO = c => c === 0 ? ['sun', 'Clear'] : c <= 2 ? ['partly', c === 1 ? 'Mostly clear' : 'Partly cloudy'] : c === 3 ? ['cloud', 'Overcast']
  : c <= 48 ? ['fog', 'Fog'] : c <= 57 ? ['rain', 'Drizzle'] : c <= 67 ? ['rain', 'Rain'] : c <= 77 ? ['snow', 'Snow'] : c <= 82 ? ['rain', 'Showers']
  : c <= 86 ? ['snow', 'Snow showers'] : ['storm', 'Thunderstorm'];
const WX = { place: store.get('wx.place', null), data: null, at: 0, err: null, busy: false };
async function wxFetch(force = false) {
  if (!WX.place || WX.busy || (!force && Date.now() - WX.at < 15 * 60e3)) return;
  WX.busy = true;
  try {
    const p = WX.place, q = new URLSearchParams({ latitude: p.lat.toFixed(4), longitude: p.lon.toFixed(4),
      current: 'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,is_day',
      hourly: 'temperature_2m,weather_code', daily: 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset',
      timezone: 'auto', forecast_days: '7', wind_speed_unit: 'kmh' });
    const r = await fetch('https://api.open-meteo.com/v1/forecast?' + q);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const j = await r.json(), c = j.current, [ic, cond] = WMO(c.weather_code);
    const start = c.time.slice(0, 13), i0 = Math.max(0, j.hourly.time.findIndex(t => t.slice(0, 13) >= start));
    WX.data = {
      temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature), humidity: Math.round(c.relative_humidity_2m),
      wind: Math.round(c.wind_speed_10m), windDir: c.wind_direction_10m, icon: !c.is_day && ic === 'sun' ? 'moon' : ic, cond,
      hours: j.hourly.time.slice(i0, i0 + 12).map((t, k) => ({ t: new Date(t), temp: Math.round(j.hourly.temperature_2m[i0 + k]), icon: WMO(j.hourly.weather_code[i0 + k])[0] })),
      days: j.daily.time.slice(0, 6).map((t, k) => ({ t: new Date(t + 'T12:00'), hi: Math.round(j.daily.temperature_2m_max[k]), lo: Math.round(j.daily.temperature_2m_min[k]),
        rain: j.daily.precipitation_probability_max[k] || 0, icon: WMO(j.daily.weather_code[k])[0] })),
      sunrise: j.daily.sunrise?.[0], sunset: j.daily.sunset?.[0], updated: Date.now()
    };
    WX.at = Date.now(); WX.err = null;
  } catch (e) { WX.err = 'Couldn’t load the forecast. Retrying in a few minutes.'; WX.at = Date.now() - 12 * 60e3; }
  WX.busy = false; changed('weather');
}
async function wxSearch(q) {
  const r = await fetch('https://geocoding-api.open-meteo.com/v1/search?' + new URLSearchParams({ name: q, count: '6', language: 'en', format: 'json' }));
  const j = await r.json();
  return (j.results || []).map(x => ({ name: x.name, region: [x.admin1, x.country].filter(Boolean).join(', '), lat: x.latitude, lon: x.longitude }));
}
function wxSet(place) { WX.place = place; store.set('wx.place', place); WX.data = null; WX.at = 0; wxFetch(true); changed('weather'); }
const wxDir = d => d == null ? '' : ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][Math.round(d / 45) % 8];

/* ---------- Focus timer (browser-side, survives reloads) ---------- */
const TMODES = [{ id: 'focus', label: 'Focus', min: 25 }, { id: 'short', label: 'Short break', min: 5 }, { id: 'long', label: 'Long break', min: 15 }];
const TM = Object.assign({ mode: 'focus', left: 25 * 60, endsAt: 0, sessions: 0, day: '' }, store.get('timer', {}));
const tMode = () => TMODES.find(m => m.id === TM.mode) || TMODES[0];
const tLeft = () => TM.endsAt ? Math.max(0, (TM.endsAt - Date.now()) / 1000) : TM.left;
const tSave = () => store.set('timer', TM);
function tTick() {
  const today = new Date().toDateString();
  if (TM.day !== today) { TM.day = today; TM.sessions = 0; tSave(); }
  if (TM.endsAt && Date.now() >= TM.endsAt) {
    const m = tMode(); TM.endsAt = 0; TM.left = m.min * 60;
    if (m.id === 'focus') TM.sessions = Math.min(4, TM.sessions + 1);
    tSave(); toast(`${m.label} finished`); chime(); changed('timer');
  }
}
function chime() {
  try { const a = new AudioContext(), o = a.createOscillator(), g = a.createGain(); o.frequency.value = 880; g.gain.setValueAtTime(.0001, a.currentTime);
    g.gain.exponentialRampToValueAtTime(.2, a.currentTime + .02); g.gain.exponentialRampToValueAtTime(.0001, a.currentTime + 1.2); o.connect(g).connect(a.destination); o.start(); o.stop(a.currentTime + 1.3); } catch { /* no audio */ }
}

/* ---------- Bindings ---------- */
const B = {
  clock: () => clock(now()), ampm: () => ampm(now()),
  date: () => { const d = now(); return `${DAY[d.getDay()]}, ${MONTH[d.getMonth()]} ${d.getDate()}`; },
  dateShort: () => { const d = now(); return `${DAY3[d.getDay()]} ${MON3[d.getMonth()]} ${d.getDate()}`; },
  cpu: () => Math.round(ok('system')?.cpu?.pct ?? 0), gpu: () => Math.round(ok('system')?.gpu?.pct ?? 0),
  cpuTemp: () => cpuTemp(ok('system')), gpuTemp: () => { const g = ok('system')?.gpu; return g && g.temp_c != null ? Math.round(g.temp_c) + '°C' : ''; },
  ram: () => ((ok('system')?.ram?.used || 0) / 1e9).toFixed(1), ramPct: () => { const r = ok('system')?.ram; return r ? Math.round(r.used / r.total * 100) : 0; },
  vram: () => ((ok('system')?.gpu?.vram_used || 0) / 1e9).toFixed(1), vramPct: () => { const g = ok('system')?.gpu; return g && g.vram_total ? Math.round(g.vram_used / g.vram_total * 100) : 0; },
  down: () => rate(ok('system')?.net?.down_bps).v, downU: () => rate(ok('system')?.net?.down_bps).u,
  up: () => rate(ok('system')?.net?.up_bps).v, upU: () => rate(ok('system')?.net?.up_bps).u,
  latency: () => { const l = ok('network')?.latency; return l && l.ms != null ? Math.round(l.ms) : '–'; },
  jitter: () => { const l = ok('network')?.latency; return l && l.jitter_ms != null ? l.jitter_ms.toFixed(1) : '–'; },
  fiveReset: () => { const f = ok('claude')?.limits?.five_hour; return !f ? '–' : f.expired ? 'reset' : f.resets_at ? dur((f.resets_at - Date.now()) / 60000) : '–'; },
  weekReset: () => { const w = ok('claude')?.limits?.seven_day; if (!w || (!w.expired && !w.resets_at)) return '–'; if (w.expired) return 'reset'; const d = new Date(w.resets_at); return `${DAY3[d.getDay()]} ${timeStr(d)}`; },
  nextTitle: () => nextEvent()?.title || 'Nothing else today',
  nextIn: () => { const e = nextEvent(); if (!e) return 'Free'; const m = (e.start - Date.now()) / 60000; return m <= 0 ? 'Now' : m < 1 ? 'Starting now' : `in ${dur(m)}`; },
  trTitle: () => media()?.title || 'Nothing playing', trArtist: () => media()?.artist || '', trAlbum: () => media()?.album || '',
  trPos: () => ms(posMs() / 1000), trLen: () => ms((media()?.duration_ms || 0) / 1000), trLeft: () => '-' + ms(((media()?.duration_ms || 0) - posMs()) / 1000),
  vol: () => ok('shortcuts')?.volume_pct ?? '–',
  timer: () => ms(tLeft()), tLabel: () => TM.endsAt ? 'Pause' : (TM.left < tMode().min * 60 ? 'Resume' : 'Start'),
  connLong: () => ({ live: `Connected to ${S.host || 'your laptop'}`, connecting: 'Connecting…', off: 'Laptop not connected', key: 'Needs the desk link' }[S.conn]),
  lastSync: () => S.lastSync ? 'Last data ' + ago(S.lastSync) : '',
  wxTemp: () => WX.data ? WX.data.temp + '°' : '–'
};
const PB = {
  cpu: () => (ok('system')?.cpu?.pct || 0) / 100, gpu: () => (ok('system')?.gpu?.pct || 0) / 100,
  ram: () => { const r = ok('system')?.ram; return r ? r.used / r.total : 0; },
  vram: () => { const g = ok('system')?.gpu; return g && g.vram_total ? g.vram_used / g.vram_total : 0; },
  disk: () => (ok('system')?.disk?.pct || 0) / 100,
  five: () => { const f = ok('claude')?.limits?.five_hour; return f && !f.expired ? f.used_pct / 100 : 0; },
  week: () => { const w = ok('claude')?.limits?.seven_day; return w && !w.expired ? w.used_pct / 100 : 0; },
  music: () => { const m = media(); return m && m.duration_ms ? posMs() / m.duration_ms : 0; },
  vol: () => (ok('shortcuts')?.volume_pct || 0) / 100,
  timer: () => 1 - tLeft() / (tMode().min * 60),
  sessions: () => TM.sessions / 4
};
const charts = {};
/* Sidebar values, one per page (see PAGES). */
const SB = {
  home: () => clock(now()),
  system: () => B.cpu() + '%',
  claude: () => { const f = ok('claude')?.limits?.five_hour; return f && !f.expired ? Math.round(f.used_pct) + '%' : ''; },
  calendar: () => { const e = nextEvent(); if (!e) return calEvents().length || ok('calendar') ? 'Free' : ''; const m = Math.max(0, Math.ceil((e.start - Date.now()) / 60000)); return m === 0 ? 'Now' : m >= 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m}m`; },
  weather: () => WX.data ? WX.data.temp + '°' : '',
  music: () => { const m = media(); return !m ? '' : m.playing ? B.trPos() : 'Paused'; },
  hotspot: () => { const h = ok('hotspot'); return !h ? '' : !h.online ? 'Offline' : h.internet === false ? 'No net' : h.score != null ? h.score + '' : 'Online'; },
  timer: () => TM.endsAt || TM.left < tMode().min * 60 ? ms(tLeft()) : '',
  slack: () => { const s = ok('slack'); return s && s.unread ? `<span class="badge">${s.unread}</span>` : ''; },
  github: () => { const g = ok('github'); return g && g.streak ? g.streak.current + 'd' : ''; },
  shortcuts: () => { const v = ok('shortcuts')?.volume_pct; return v == null ? '' : v + '%'; }
};

/* ---------- Pages and shell ---------- */
const PAGES = [['home', 'Overview', 'home'], ['system', 'System', 'system'], ['claude', 'Claude', 'claude'], ['calendar', 'Calendar', 'calendar'],
  ['weather', 'Weather', 'weather'], ['music', 'Music', 'music'], ['hotspot', 'Hotspot', 'hotspot'], ['timer', 'Timer', 'timer'],
  ['slack', 'Slack', 'slack'], ['github', 'GitHub', 'github'], ['shortcuts', 'Controls', 'shortcuts']];
const WALL = { home: ['#5B6CFF', '#FF6FB5', '#2FD3C5', '#1B1640'], system: ['#1C8CA8', '#3D63FF', '#0F5F6E', '#0B1830'], claude: ['#FF8A5B', '#D9466F', '#8E3B8C', '#2A1230'],
  calendar: ['#7C5CFF', '#FF7AA8', '#4B7BFF', '#1C1846'], weather: ['#6F8DBA', '#A9BFDC', '#4C6A9A', '#22324F'], music: ['#6A3FD1', '#2A1A6E', '#C27BFF', '#140C30'],
  hotspot: ['#FFB547', '#FF6B3D', '#C9822E', '#2E1E10'], timer: ['#FF5F6D', '#FFC371', '#C2477F', '#2B1426'], slack: ['#4A154B', '#E01E5A', '#36C5F0', '#1A0B1C'],
  github: ['#2EA043', '#1F6FEB', '#0E7A62', '#0B1A28'], shortcuts: ['#4B5170', '#6B5BFF', '#2E7A8C', '#12131C'] };
const pages = {};
const A = {};
let screen, view, nav, lastSig = '', lastIdx = null, wallKey = '';

function page(id, def) { pages[id] = def; }
function cur() { return pages[S.page] || pages.home; }

function render() {
  if (!pages[S.page]) S.page = 'home';
  screen.dataset.page = S.page;
  const p = cur();
  try { view.innerHTML = p.render(); } catch (e) { console.error(e); view.innerHTML = card(`<div class="note"><b>This page hit a problem</b><span>${esc(e.message)}</span></div>`); }
  try { lastSig = p.sig ? p.sig() : ''; } catch { lastSig = ''; }
  refresh();
  requestAnimationFrame(() => refresh());
}
function go(id) { if (!pages[id]) return; S.page = id; store.set('page', id); render(); view.scrollTop = 0; }

/* A topic (or local data) changed: re-render the page if its structure changed, else refresh numbers. */
let pending = false;
function changed() {
  if (pending) return; pending = true;
  requestAnimationFrame(() => {
    pending = false;
    let sig = ''; try { sig = cur().sig ? cur().sig() : ''; } catch { sig = '?'; }
    if (sig !== lastSig) render(); else refresh();
  });
}

function refresh(root = screen) {
  if (!root) return;
  root.querySelectorAll('[data-b]').forEach(el => { const f = B[el.dataset.b]; if (f) { let v; try { v = String(f()); } catch { v = ''; } if (el.textContent !== v) el.textContent = v; } });
  root.querySelectorAll('[data-p]').forEach(el => { const f = PB[el.dataset.p]; if (f) { let v = 0; try { v = f(); } catch { /* */ } el.style.setProperty('--p', clamp(v || 0, 0, 1).toFixed(4)); } });
  root.querySelectorAll('[data-arc]').forEach(el => { const f = PB[el.dataset.arc]; if (f) { let p = 0; try { p = clamp(f() || 0, 0, 1); } catch { /* */ } el.style.strokeDashoffset = (100 - p * 100).toFixed(2); el.style.opacity = p < .004 ? 0 : 1; } });
  root.querySelectorAll('[data-c]').forEach(el => { const f = charts[el.dataset.c]; if (f && el.clientWidth) { let h = ''; try { h = f(el); } catch (e) { console.error(e); } if (el._h !== h) { el.innerHTML = h; el._h = h; } } });
  root.querySelectorAll('[data-sb]').forEach(el => { const f = SB[el.dataset.sb]; if (f) { let v = ''; try { v = String(f() ?? ''); } catch { /* */ } if (el._v !== v) { el._v = v; el.innerHTML = v; } } });
  shell();
}

function shell() {
  screen.dataset.glass = S.glass;
  screen.dataset.conn = S.conn === 'live' ? 'on' : 'off';
  const idx = Math.max(0, PAGES.findIndex(p => p[0] === S.page)), c = WALL[S.page] || WALL.home;
  ['--c1', '--c2', '--c3', '--c4'].forEach((k, i) => screen.style.setProperty(k, c[i]));
  const wall = screen.querySelector('.wall'), m = media(), a = T['media.art'];
  const key = S.page === 'music' && m && a && a.b64 && a.art_id === m.art_id ? 'm' + m.art_id : 'b';
  if (wall && key !== wallKey) { wallKey = key; wall.innerHTML = key === 'b' ? '<i></i><i></i><i></i>' : artFor(m); }
  const t = screen.querySelector('#ttl'), p = cur(), sub = p.sub ? p.sub() : '';
  const tk = S.page + '|' + sub;
  if (t && t.dataset.k !== tk) { t.dataset.k = tk; t.innerHTML = `<h1>${PAGES[idx][1]}</h1><span class="sub">${sub}</span>`; }
  t?.querySelectorAll('[data-b]').forEach(el => { const v = String(B[el.dataset.b]?.() ?? ''); if (el.textContent !== v) el.textContent = v; });
  nav.querySelectorAll('.items button').forEach(b => { const on = b.dataset.v === S.page; if (on !== b.hasAttribute('aria-current')) on ? b.setAttribute('aria-current', 'page') : b.removeAttribute('aria-current'); });
  const drop = nav.querySelector('.vdrop');
  if (drop && drop.dataset.i !== String(idx)) { const from = lastIdx == null ? idx : lastIdx; drop.dataset.i = idx; drop.style.transition = 'none'; drop.style.transform = `translateY(${from * 40}px)`; void drop.offsetWidth; drop.style.transition = ''; drop.style.transform = `translateY(${idx * 40}px)`; }
  lastIdx = idx;
  const gm = screen.querySelector('#gm');
  if (gm && gm.dataset.m !== S.glass) { gm.dataset.m = S.glass; gm.innerHTML = `${icon('drop')}<span>${S.glass === 'clear' ? 'Clear' : 'Tinted'}</span>`; gm.setAttribute('aria-label', `Glass: ${S.glass}. Click to switch`); }
  const ban = screen.querySelector('.offline-banner');
  if (ban) ban.querySelector('span').textContent = S.lastSync ? `Showing the last data received (${ago(S.lastSync)}). Reconnecting…` : 'Is the DeskPanel agent running on this Mac? Reconnecting…';
}

function toast(msg) {
  screen.querySelector('.toast')?.remove();
  const t = document.createElement('div'); t.className = 'toast'; t.setAttribute('role', 'status'); t.textContent = msg;
  screen.appendChild(t); setTimeout(() => t.classList.add('out'), 2200); setTimeout(() => t.remove(), 2700);
}

/* ---------- Connection to the agent ---------- */
const KEY_RE = /^[A-Za-z0-9_-]{16,64}$/;
const HASH = location.hash;
let key = (() => {
  const m = /[#&]k=([A-Za-z0-9_-]+)/.exec(location.hash);
  if (m && KEY_RE.test(m[1])) { store.set('key', m[1]); history.replaceState(null, '', location.pathname); return m[1]; }
  return store.get('key', null);
})();
let ws = null, rid = 0, lastIn = 0, backoff = 1000, seq = {};
const waiting = new Map();

function connect() {
  if (!key) { S.conn = 'key'; gate(); return; }
  S.conn = S.conn === 'live' ? 'connecting' : S.conn;
  try { ws = new WebSocket(`ws://${location.host}/ws`); } catch { retry(); return; }
  ws.onopen = () => ws.send(JSON.stringify({ t: 'hello', proto: 1, token: key, client: { name: 'Desk page', platform: 'web', app_version: '0.1.0' } }));
  ws.onmessage = e => {
    lastIn = Date.now();
    let m; try { m = JSON.parse(e.data); } catch { return; }
    if (m.t === 'welcome') {
      S.conn = 'live'; S.host = m.host || ''; S.agent = m; S.offset = (m.server_time || Date.now()) - Date.now(); backoff = 1000; seq = {};
      ws.send(JSON.stringify({ t: 'sub', topics: m.topics || [] }));
      gate(); changed();
    } else if (m.t === 'evt') {
      if (seq[m.topic] != null && m.seq != null && m.seq <= seq[m.topic]) return;
      seq[m.topic] = m.seq; T[m.topic] = m.data; S.lastSync = Date.now(); changed(m.topic);
    } else if (m.t === 'res') {
      const w = waiting.get(m.id); if (!w) return; waiting.delete(m.id); clearTimeout(w.timer);
      m.ok ? w.resolve(m.result || {}) : w.reject(Object.assign(new Error(m.error?.message || 'The laptop couldn’t do that'), { code: m.error?.code }));
    } else if (m.t === 'prog') {
      waiting.get(m.id)?.onProg?.(m.data);
    } else if (m.t === 'ping') {
      ws.send(JSON.stringify({ t: 'pong', ts: m.ts }));
    } else if (m.t === 'error' && m.code === 'auth_failed') {
      key = null; store.set('key', null); S.conn = 'key'; gate();
    }
  };
  ws.onclose = () => {
    for (const [, w] of waiting) { clearTimeout(w.timer); w.reject(new Error('Laptop disconnected')); }
    waiting.clear(); ws = null;
    if (S.conn !== 'key') { S.conn = 'off'; changed(); retry(); }
  };
}
function retry() { setTimeout(connect, backoff); backoff = Math.min(backoff * 2, 10000); }
setInterval(() => {
  if (!ws || ws.readyState !== 1) return;
  ws.send(JSON.stringify({ t: 'ping', ts: Date.now() }));
  if (S.conn === 'live' && Date.now() - lastIn > 12000) ws.close();
}, 5000);

/* Run an agent action. Errors show a toast and reject. */
function req(action, params = {}, o = {}) {
  return new Promise((resolve, reject) => {
    if (!ws || ws.readyState !== 1 || S.conn !== 'live') { toast('The laptop isn’t connected'); reject(new Error('offline')); return; }
    const id = 'w-' + (++rid);
    const timer = setTimeout(() => { waiting.delete(id); reject(new Error('timeout')); toast('The laptop didn’t answer'); }, o.timeout || 10000);
    waiting.set(id, { resolve, reject: e => { if (!o.quiet) toast(e.message); reject(e); }, onProg: o.onProg, timer });
    ws.send(JSON.stringify({ t: 'req', id, action, params }));
  });
}

/* The "needs the link" screen when the page was opened without its key. */
function gate() {
  screen.querySelector('.gate')?.remove();
  if (S.conn !== 'key') return;
  const g = document.createElement('div'); g.className = 'gate';
  g.innerHTML = card(`<h2>Open DeskPanel from your Mac</h2><div class="mu">This page needs its private link. In Terminal on the Mac running the DeskPanel agent, run</div>
    <div class="note" style="height:auto"><code>deskpanel-agent desk</code></div><div class="mu">It opens this page with the key. Bookmark it after that; the key is remembered in this browser.</div>`);
  screen.appendChild(g);
}

/* ---------- Shared actions ---------- */
const lensOn = !!(navigator.userAgentData?.brands || []).find(b => /Chromium/.test(b.brand));
Object.assign(A, {
  go: v => go(v),
  tab: v => { S.sysTab = v; render(); },
  glass: () => { S.glass = S.glass === 'clear' ? 'tinted' : 'clear'; store.set('glass', S.glass); shell(); toast(S.glass === 'clear' ? 'Clear glass' : 'Tinted glass, easier to read'); },
  play: () => req('media.play_pause').catch(() => {}),
  next: () => req('media.next').catch(() => {}),
  prev: () => req('media.prev').catch(() => {}),
  seek: (v, e, el) => {
    const m = media(); if (!m || !m.duration_ms) return;
    const r = el.getBoundingClientRect(), pos = Math.round(clamp((e.clientX - r.left) / r.width, 0, 1) * m.duration_ms);
    m.position_ms = pos; m.position_at = Date.now() + S.offset; refresh();
    req('media.seek', { position_ms: pos }).catch(() => {});
  },
  volset: (v, e, el) => {
    const r = el.getBoundingClientRect(), pct = Math.round(clamp((e.clientX - r.left) / r.width, 0, 1) * 100);
    const s = ok('shortcuts'); if (s) s.volume_pct = pct; refresh();
    req('volume.set', { pct }).catch(() => {});
  },
  sc: v => {
    if (A.ccRun) { A.ccRun(v); return; }  // the Controls page's version: flips toggles at once, says "Microphone muted"
    req('shortcut.run', { id: v }).then(r => {
      if (r && r.open_url) window.open(r.open_url, '_blank', 'noopener');
      toast(r?.message || (ok('shortcuts')?.tiles || []).find(t => t.id === v)?.label || 'Done');
    }).catch(() => {});
  },
  reconnect: () => { if (S.conn === 'off') { backoff = 1000; connect(); } }
});

/* ---------- Boot ---------- */
function fit() {
  const W = innerWidth, H = innerHeight, sc = clamp(Math.min(W / 1440, H / 900), .62, 2.4);
  screen.style.width = W / sc + 'px'; screen.style.height = H / sc + 'px'; screen.style.transform = `scale(${sc})`;
}
const mapSvg = (ex, ey) => encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' width='200' height='200' viewBox='0 0 200 200' preserveAspectRatio='none'><defs><linearGradient id='x'><stop offset='0' stop-color='#ff0000'/><stop offset='${ex}' stop-color='#800000'/><stop offset='${1 - ex}' stop-color='#800000'/><stop offset='1' stop-color='#000000'/></linearGradient><linearGradient id='y' x2='0' y2='1'><stop offset='0' stop-color='#00ff00'/><stop offset='${ey}' stop-color='#008000'/><stop offset='${1 - ey}' stop-color='#008000'/><stop offset='1' stop-color='#000000'/></linearGradient></defs><rect width='200' height='200' fill='url(#x)'/><rect width='200' height='200' fill='url(#y)' style='mix-blend-mode:screen'/></svg>`);
const lensDefs = `<svg width="0" height="0" style="position:absolute" aria-hidden="true">
  <filter id="lens" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB"><feImage href="data:image/svg+xml,${mapSvg(.22, .3)}" x="0" y="0" width="100%" height="100%" preserveAspectRatio="none" result="m"/><feDisplacementMap in="SourceGraphic" in2="m" scale="34" xChannelSelector="R" yChannelSelector="G"/></filter>
  <filter id="lens-soft" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB"><feImage href="data:image/svg+xml,${mapSvg(.06, .08)}" x="0" y="0" width="100%" height="100%" preserveAspectRatio="none" result="m"/><feDisplacementMap in="SourceGraphic" in2="m" scale="30" xChannelSelector="R" yChannelSelector="G"/></filter></svg>`;

function boot() {
  screen = document.getElementById('screen');
  if (lensOn) screen.classList.add('lens-on');
  screen.innerHTML = `${lensDefs}<div class="wall"><i></i><i></i><i></i></div>
  <div class="app"><nav id="nav" class="glass side" aria-label="Pages"></nav><div class="mainc"><div class="top"><div id="ttl" class="row" style="align-items:baseline;gap:0"></div><span class="sp"></span>
    <button class="glass pill lensed" id="gm" data-act="glass"></button><span class="glass pill"><span data-b="clock"></span>&nbsp;<span data-b="ampm"></span></span></div><main id="view" class="view"></main></div></div>
  <div class="offline-banner" role="status"><strong>Laptop not connected.</strong> <span></span></div>`;
  view = screen.querySelector('#view'); nav = screen.querySelector('#nav');
  nav.innerHTML = `<div class="brand"><i></i>DeskPanel</div><div class="items"><span class="glass vdrop lensed" data-i=""></span>${PAGES.map(([id, l, ic]) => `<button data-act="go" data-v="${id}">${icon(ic)}<span>${l}</span><span data-sb="${id}"></span></button>`).join('')}</div>
    <button class="foot" data-act="reconnect" aria-label="Connection status"><b><span class="dot"></span><span data-b="connLong"></span></b>Served by the agent on this Mac at ${esc(location.host)}</button>`;
  screen.addEventListener('click', e => {
    const el = e.target.closest('[data-act]'); if (!el || !screen.contains(el) || el.disabled) return;
    A[el.dataset.act]?.(el.dataset.v, e, el);
  });
  screen.addEventListener('keydown', e => {
    const el = e.target.closest('[role="button"][data-act],[role="slider"][data-act]');
    if (el && (e.key === 'Enter' || e.key === ' ') && el.getAttribute('role') === 'button') { e.preventDefault(); A[el.dataset.act]?.(el.dataset.v, e, el); }
  });
  addEventListener('keydown', e => {
    if (e.target.closest('input,textarea') || e.metaKey || e.ctrlKey || e.altKey) return;
    const n = parseInt(e.key, 10); if (n >= 1 && n <= 9) go(PAGES[n - 1][0]); else if (e.key === '0') go(PAGES[9][0]);
  });
  fit(); render(); connect();
  addEventListener('resize', () => { fit(); refresh(); });
  setInterval(() => { tTick(); refresh(); }, 1000);
  wxFetch(); setInterval(wxFetch, 60e3);
  document.fonts?.ready.then(() => refresh());
}

window.DP = { HASH, T, S, B, PB, A, SB, charts, pages, page, go, render, refresh, changed, toast, req, ok, note, media, posMs, artFor, art, icon,
  card, ring, bar, slider, gbtn, seg, pill, linePath, arc, size, clamp, esc, pad, dur, ms, ago, clock, ampm, timeStr, hourStr, sameDay, bytes, rate, mbps, compact, hash,
  DAY, DAY3, MONTH, MON3, H12, now, store, cpuTemp, calEvents, todayEvents, nextEvent, WX, wxFetch, wxSearch, wxSet, wxDir, TM, TMODES, tMode, tLeft, tSave, boot };
})();
