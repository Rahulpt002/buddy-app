/* Claude, Calendar, Weather, Music: concept 16 desktop (pages.claude / calendar / weather / music),
   live data instead of the concept's mock. Everything from the agent or Open-Meteo goes through esc(). */
(() => {
'use strict';
const { T, B, PB, A, charts, page, card, ring, bar, slider, gbtn, pill, icon, esc, ok, note, media, artFor, art, hash, clamp,
  dur, ms, compact, timeStr, hourStr, DAY, DAY3, WX, wxSearch, wxSet, wxDir, store, render } = DP;

/* ---------- Shared bits ---------- */
const COLOR_RE = /^(#[0-9a-f]{3,8}|[a-z]{3,20}|(rgb|hsl)a?\([\d\s.,%a-z]*\))$/i;
const col = (c, d = '#5AA9FF') => { const v = String(c ?? '').trim(); return COLOR_RE.test(v) ? v : d; };
const CLAMP = n => `display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:${n};overflow:hidden;`;
const Z = 'position:relative;z-index:3;';   // content inside a hand-made .glass box sits above its rim
/* Text width at 100px, for sizing big numbers and titles to their box. */
const mctx = document.createElement('canvas').getContext('2d');
const ROUNDED = 'ui-rounded, "SF Pro Rounded", -apple-system, "Inter", sans-serif', SANS = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", system-ui, sans-serif';
const textW = (s, weight, fam) => { try { mctx.font = `${weight} 100px ${fam}`; return mctx.measureText(s).width || s.length * 60; } catch { return s.length * 60; } };
const fitPx = (s, w, max, min) => clamp(Math.floor(w * 100 / Math.max(1, textW(s, 700, ROUNDED)) * .96), min, max);

/* ---------- Claude ---------- */
const cl = () => ok('claude');
const lim = k => cl()?.limits?.[k] || null;
const win = k => { const w = lim(k); return !w ? 'none' : w.expired ? 'reset' : 'ok'; };
const pct = k => { const w = lim(k); return w && !w.expired && w.used_pct != null ? Math.round(w.used_pct) : '–'; };
Object.assign(B, {
  clFive: () => pct('five_hour'), clWeek: () => pct('seven_day'),
  clFiveIn: () => { const w = lim('five_hour'); return !w || !w.resets_at ? '–' : w.expired ? 'reset' : dur((w.resets_at - Date.now()) / 60000); },
  clWeekAt: () => { const w = lim('seven_day'); if (!w || !w.resets_at) return '–'; const d = new Date(w.resets_at), t = new Date();
    return `${d.toDateString() === t.toDateString() ? 'today' : DAY3[d.getDay()]} ${timeStr(d)}`; },
  clTok: () => compact(cl()?.today?.tokens), clOut: () => compact(cl()?.today?.output_tokens),
  clMsg: () => compact(cl()?.today?.messages), clHour: () => compact(cl()?.today?.last_hour_tokens)
});
/* Model pills: tokens today per family, biggest first. */
charts.clModels = () => {
  const by = {};
  (cl()?.models_today || []).forEach(m => {
    const f = String(m?.family || m?.model || 'Other'), k = f.charAt(0).toUpperCase() + f.slice(1);
    by[k] = (by[k] || 0) + (+m?.tokens || 0);
  });
  return Object.entries(by).filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]).slice(0, 4)
    .map(([k, v]) => pill(`<span>${esc(k)} ${compact(v)}</span>`, 'height:28px;font-size:12.5px;flex:none')).join('');
};
/* Seven day bars, oldest first, the last one is today. */
charts.clDays = () => {
  const d = (cl()?.days || []).slice(-7);
  if (!d.length) return '<div class="mu" style="grid-column:1/-1;align-self:center;text-align:center">No Claude Code use in the last 7 days</div>';
  const mx = Math.max(1, ...d.map(x => +x?.tokens || 0)), last = d.length - 1;
  return d.map((x, i) => {
    const v = +x?.tokens || 0, t = i === last, dt = new Date(String(x?.date) + 'T12:00'), lab = t ? 'Today' : isNaN(dt) ? '' : DAY3[dt.getDay()];
    return `<div style="display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;gap:6px;min-width:0"><span class="rnd" style="font-size:13px;${t ? '' : 'opacity:.7'}">${compact(v)}</span>
      <i style="width:100%;max-width:40px;border-radius:99px;height:${(v / mx * 72).toFixed(1)}%;min-height:10px;background:${t ? '#fff' : 'rgba(255,255,255,.4)'};box-shadow:${t ? '0 0 16px rgba(255,255,255,.5)' : 'none'}"></i>
      <span class="mu" style="font-size:12.5px;${t ? 'color:#fff;font-weight:700' : ''}">${lab}</span></div>`;
  }).join('');
};

page('claude', {
  sub: () => 'Plan limits',
  sig: () => [T.claude?.status, win('five_hour'), win('seven_day'), !!lim('five_hour')?.resets_at, !!lim('seven_day')?.resets_at, !!cl()?.today].join('|'),
  render: () => {
    const c = cl();
    if (!c) return `<div class="g">${card(`<div class="lab">Claude</div>${note('claude', 'Plan limits and token use from Claude Code on this Mac.')}`)}</div>`;
    const f = win('five_hour'), w = win('seven_day');
    const center = f === 'ok' ? '<div class="rnd" style="font-size:72px"><span data-b="clFive"></span>%</div><div class="mu" style="font-size:16px">used</div>'
      : `<div class="rnd" style="font-size:72px">–</div><div class="mu" style="font-size:16px">${f === 'reset' ? 'reset' : 'no data'}</div>`;
    const fiveFoot = f === 'ok' ? (lim('five_hour').resets_at ? 'Resets in <b data-b="clFiveIn"></b>' : '<span class="mu">Reset time not reported</span>')
      : f === 'reset' ? 'Reset. Starts again with your next message.'
      : '<span class="mu" style="font-size:14px">Limits come from Claude Code’s status line (Pro and Max plans). Run <b style="color:#fff">deskpanel-agent install-statusline</b> on the Mac.</span>';
    const weekFoot = w === 'ok' ? (lim('seven_day').resets_at ? 'Resets <span data-b="clWeekAt"></span>' : 'Reset time not reported') : w === 'reset' ? 'Reset. A new week starts with your next message.' : 'No weekly limit reported yet';
    return `<div class="g" style="grid-template-columns:1.1fr 1fr 1fr;grid-template-rows:1fr 1fr">
      ${card(`<div class="lab">5-hour limit</div><div style="flex:1;display:grid;place-items:center;min-height:0">${ring('five', center, 300, { sw: 7, p: PB.five() })}</div><div style="text-align:center;font-size:17px">${fiveFoot}</div>`, { st: 'grid-row:1/3' })}
      ${card(`<div class="lab">Weekly limit</div><div class="big rnd" style="font-size:72px;margin:8px 0 14px">${w === 'ok' ? '<span data-b="clWeek"></span><small>%</small>' : '–'}</div>${bar('week', '#FFD36E', 'height:10px')}<div class="mu" style="margin-top:10px">${weekFoot}</div>`)}
      ${card(`<div class="lab">Today</div><div class="big rnd" style="font-size:56px;margin-top:8px"><span data-b="clTok"></span><small>tokens</small></div>
        <div style="margin-top:auto;display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px">${[['Output', 'clOut'], ['Messages', 'clMsg'], ['Last hour', 'clHour']].map(([k, b]) => `<div style="min-width:0"><div class="mu" style="font-size:12.5px">${k}</div><b class="rnd" style="font-size:22px" data-b="${b}"></b></div>`).join('')}</div>`)}
      ${card(`<div class="row" style="min-height:28px"><span class="lab" style="flex:none">Tokens, last 7 days</span><div class="row" data-c="clModels" style="flex:1;min-width:0;gap:6px;justify-content:flex-end;overflow:hidden"></div></div>
        <div data-c="clDays" style="flex:1;display:grid;grid-template-columns:repeat(7,1fr);gap:14px;align-items:end;margin-top:10px;min-height:0"></div>`, { st: 'grid-column:2/4' })}
    </div>`;
  }
});

/* ---------- Calendar ---------- */
const dayStart = (d = new Date()) => { d = new Date(d); return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); };
const addDays = (t, n) => { const d = new Date(t); d.setDate(d.getDate() + n); return d.getTime(); };
const evs = () => (ok('calendar')?.events || []).filter(e => e && isFinite(e.start) && isFinite(e.end)).slice().sort((a, b) => a.start - b.start);
const todays = () => { const a = dayStart(), b = addDays(a, 1); return evs().filter(e => !e.all_day && e.start < b && e.end > a); };
const allDay = () => { const a = dayStart(), b = addDays(a, 1); return evs().filter(e => e.all_day && e.start < b && Math.max(e.end, e.start + 1) > a); };
const calNext = () => { const t = Date.now(); return todays().find(e => e.end > t) || null; };
const laterWeek = () => { const a = addDays(dayStart(), 1), b = addDays(dayStart(), 8); return evs().filter(e => e.start >= a && e.start < b); };
const whenLabel = e => {
  const d = new Date(e.start), n = Math.round((dayStart(d) - dayStart()) / 864e5);
  return `${n === 1 ? 'Tomorrow' : n >= 7 ? 'Next ' + DAY[d.getDay()] : DAY[d.getDay()]}, ${e.all_day ? 'all day' : timeStr(d)}`;
};
const endStr = e => { const s = new Date(e.start), en = new Date(e.end); return dayStart(s) === dayStart(new Date(e.end - 1)) ? timeStr(en) : `${DAY3[en.getDay()]} ${timeStr(en)}`; };
B.calIn = () => {
  const e = calNext(); if (!e) return 'Free'; const t = Date.now();
  if (e.start > t) { const m = (e.start - t) / 60000; return m < 1 ? 'Starting now' : `in ${dur(m)}`; }
  return `${dur(Math.max(1, (e.end - t) / 60000))} left`;
};
/* The concept's 110px "in 25m", shrunk to fit when the text is longer ("in 1h 25m", "45m left"). */
charts.calBig = el => { const t = B.calIn(); return `<div class="big rnd" style="font-size:${fitPx(t, el.clientWidth, 110, 40)}px;white-space:nowrap">${esc(t)}</div>`; };

function timeline(list) {
  const now = Date.now(), a = dayStart(), b = addDays(a, 1);
  const hod = t => t <= a ? 0 : t >= b ? 24 : (d => d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600)(new Date(t));
  const nowH = hod(now);
  let h0 = Math.min(8, nowH), h1 = Math.max(18, nowH);
  list.forEach(e => { h0 = Math.min(h0, hod(e.start)); h1 = Math.max(h1, hod(e.end)); });
  /* A block is at least 34px tall: about 34/700 of the timeline. Keep those short blocks inside too. */
  const minH = () => 34 / 700 * (h1 - h0);
  list.forEach(e => { h1 = Math.max(h1, Math.min(24, hod(e.start) + minH())); });
  const span0 = Math.ceil(h1) - Math.floor(h0), step = span0 <= 6 ? 1 : span0 <= 12 ? 2 : 3;
  h0 = Math.max(0, Math.floor(h0 / step) * step); h1 = Math.min(24, Math.ceil(h1 / step) * step);
  const span = h1 - h0 || 1, y = h => ((h - h0) / span * 100).toFixed(2) + '%', mh = minH();
  /* Overlapping events sit side by side: greedy lanes inside each overlapping group. */
  const items = list.map(e => { const s = hod(e.start), en = Math.max(hod(e.end), s); return { e, s, en, ve: Math.max(en, s + mh), lane: 0, n: 1 }; });
  let group = [], lanes = [], gEnd = -1;
  const close = () => { group.forEach(it => { it.n = lanes.length; }); group = []; lanes = []; };
  items.forEach(it => {
    if (group.length && it.s >= gEnd) close();
    let l = lanes.findIndex(t => t <= it.s + 1e-6); if (l < 0) { l = lanes.length; lanes.push(0); }
    lanes[l] = it.ve; it.lane = l; group.push(it); gEnd = Math.max(gEnd, it.ve);
  });
  close();
  const labels = []; for (let h = h0; h <= h1; h += step) labels.push(h);
  const d0 = new Date(a);
  return [labels.map(h => `<span class="mu" style="position:absolute;left:-56px;top:${y(h)};transform:translateY(-50%);font-size:12px;white-space:nowrap">${hourStr(new Date(d0.getFullYear(), d0.getMonth(), d0.getDate(), h))}</span><i style="position:absolute;left:0;right:0;top:${y(h)};border-top:1px dashed var(--sep)"></i>`).join('')
    + items.map(({ e, s, en, lane, n }) => {
      const past = e.end <= now, live = e.start <= now && e.end > now, tall = en - s >= mh * 2.1;
      const left = n > 1 ? `calc(12px + (100% - 12px) * ${(lane / n).toFixed(4)})` : '12px', width = n > 1 ? `calc((100% - 12px) / ${n} - 6px)` : 'calc(100% - 12px)';
      const when = timeStr(new Date(e.start)), where = e.location ? esc(e.location) : '';
      const body = tall
        ? `<div style="${Z}min-width:0;flex:1"><b class="ell" style="display:block">${esc(e.title)}</b><span class="mu ell" style="display:block;font-size:13px">${when} to ${endStr(e)}${where ? ', ' + where : ''}</span></div>`
        : `<b class="ell" style="${Z}min-width:0;flex:0 1 auto">${esc(e.title)}</b><span class="mu ell" style="${Z}min-width:0;flex:0 10 auto">${when}${where ? ', ' + where : ''}</span>`;
      return `<div class="glass" title="${esc(e.title)}" style="--r:14px;position:absolute;left:${left};width:${width};top:${y(s)};height:max(34px,${((en - s) / span * 100).toFixed(2)}%);padding:${tall ? '8px 12px' : '0 12px'};display:flex;align-items:${tall ? 'flex-start' : 'center'};gap:10px;min-width:0;${past ? 'opacity:.5;' : ''}${live ? 'background:rgba(255,255,255,.22);' : ''}">
        <i style="${Z}width:4px;align-self:stretch;border-radius:4px;flex:none;background:${col(e.color)}"></i>${body}</div>`;
    }).join('')
    + `<i style="position:absolute;left:-5px;right:0;top:${y(nowH)};height:2px;background:#fff;box-shadow:0 0 10px #fff"></i>`, (nowH - h0) / span];
}

page('calendar', {
  sub: () => '<span data-b="date"></span>',
  sig: () => { const n = calNext(); return [T.calendar?.status, hash(JSON.stringify(ok('calendar')?.events || [])), n?.id, n && n.start <= Date.now(), Math.floor(Date.now() / 60000)].join('|'); },
  render: () => {
    const c = ok('calendar'), list = todays(), n = calNext(), later = laterWeek(), ad = allDay(), none = c && !(c.events || []).length;
    const pills = e => pill(`<i style="width:8px;height:8px;border-radius:50%;flex:none;background:${col(e.color)}"></i><span class="ell">${esc(e.title)}</span>`, 'height:26px;font-size:12.5px;max-width:150px;flex:none;padding:0 11px');

    const nextCard = !c ? card(`<div class="lab">Calendar</div>${note('calendar', 'Your events from the calendars linked on the Mac.')}`)
      : n ? card(`<div class="lab">${n.start <= Date.now() ? 'Happening now' : 'Next up'}</div>
          <div style="font-size:34px;font-weight:750;line-height:1.12;margin-top:8px;${CLAMP(2)}">${esc(n.title)}</div>
          <div data-c="calBig" style="margin-top:auto;min-height:60px;display:flex;align-items:flex-end"></div>
          <div class="row" style="margin-top:14px;gap:8px;flex-wrap:wrap">${pill(`${icon('clock')}<span>${timeStr(new Date(n.start))} to ${endStr(n)}</span>`)}${n.location ? pill(`${icon('pin')}<span class="ell">${esc(n.location)}</span>`, 'max-width:100%;min-width:0') : ''}${n.calendar ? pill(`<i style="width:8px;height:8px;border-radius:50%;flex:none;background:${col(n.color)}"></i><span class="ell">${esc(n.calendar)}</span>`, 'max-width:100%;min-width:0') : ''}</div>`)
      : card(`<div class="lab">Next up</div><div style="font-size:34px;font-weight:750;margin-top:8px">${list.length ? 'Nothing else today' : 'Nothing on today'}</div>
          <div class="mu" style="font-size:16px;margin-top:8px;${CLAMP(2)}">${later[0] ? `Next is ${esc(later[0].title)}, ${whenLabel(later[0]).replace(/^(Tomorrow|Next)/, w => w.toLowerCase())}.` : none ? 'No events from your calendars.' : 'Nothing in the next 7 days either.'}</div>
          <div class="big rnd" style="font-size:110px;margin-top:auto">Free</div><div class="mu" style="font-size:16px;margin-top:10px">${list.length ? 'for the rest of the day' : 'all day'}</div>`);

    const head = `<div class="row" style="min-height:26px;gap:6px"><span class="lab" style="flex:none">Today</span><span class="sp"></span>${ad.length ? `<span class="mu" style="font-size:12.5px;flex:none">All day</span>${ad.slice(0, 2).map(pills).join('')}${ad.length > 2 ? `<span class="mu" style="font-size:12.5px;flex:none">+${ad.length - 2}</span>` : ''}` : ''}</div>`;
    /* Empty timeline: a message, placed in the half away from the "now" line. */
    const [tl, nowF] = timeline(list);
    const empty = !c ? null : none ? ['No events', 'To link a calendar, add its ICS link under [calendar] in ~/.deskpanel/config.toml on the Mac and restart the agent.'] : !list.length ? ['Nothing on the calendar today', ''] : null;
    const tlCard = card(`${head}<div style="position:relative;flex:1;margin:12px 0 6px 56px;border-left:1px solid var(--sep);min-height:0">${tl}
        ${empty ? `<div style="position:absolute;left:12px;right:0;top:${nowF < .5 ? 70 : 30}%;transform:translateY(-50%);display:flex;justify-content:center"><div class="glass" style="--r:18px;padding:14px 20px;max-width:100%;text-align:center"><b style="${Z}display:block;font-size:16px">${empty[0]}</b>${empty[1] ? `<span class="mu" style="${Z}display:block;font-size:13.5px;margin-top:4px;line-height:1.4">${empty[1]}</span>` : ''}</div></div>` : ''}</div>`, { st: 'grid-row:1/3' });

    const MAX = 4, shown = later.slice(0, MAX);
    const laterCard = card(`<div class="lab">Later this week</div>${!c ? '<div class="mu" style="padding:8px 0">–</div>' : shown.length ? shown.map(e => `<div class="li"><i style="width:4px;height:30px;border-radius:4px;background:${col(e.color)}"></i><div style="min-width:0"><b class="ell">${esc(e.title)}</b><span class="mu ell" style="display:block;font-size:12.5px">${esc(e.location || e.calendar || '')}</span></div><span class="mu" style="white-space:nowrap">${whenLabel(e)}</span></div>`).join('')
      : '<div class="mu" style="padding:8px 0">Nothing in the next 7 days.</div>'}${later.length > MAX ? `<div class="mu" style="font-size:12.5px;margin-top:4px">and ${later.length - MAX} more</div>` : ''}`);

    return `<div class="g" style="grid-template-columns:1fr 1.3fr;grid-template-rows:minmax(0,1fr) auto">${nextCard}${tlCard}${laterCard}</div>`;
  }
});

/* ---------- Weather ---------- */
/* City search: shown when no city is chosen yet, or after "Change city". The page has no inline handlers
   (CSP), so the input is wired with delegated listeners; the typed text and results live here and survive
   re-renders, and focus is put back after a re-render. */
let wxQ = '', wxRes = null, wxBusy = false, wxErr = '', wxEdit = false, wxTimer = 0, wxSeq = 0;
const searching = () => !WX.place || wxEdit;
const wxResHTML = () => {
  const msg = t => `<div class="mu" style="padding:8px 4px">${t}</div>`;
  if (wxBusy) return msg('Searching…');
  if (wxErr) return msg(esc(wxErr));
  if (!wxRes) return msg('Type at least two letters of your city.');
  if (!wxRes.length) return msg(`No places called “${esc(wxQ.trim())}”. Try another spelling.`);
  return wxRes.map((p, i) => `<button class="glass gbtn lensed" data-act="wxPick" data-v="${i}" style="--r:18px;height:auto;min-height:54px;padding:8px 16px;justify-content:flex-start;width:100%;flex:none">
    <span style="display:flex;align-items:center;gap:12px;min-width:0;width:100%">${icon('pin')}<span style="min-width:0;text-align:left"><b class="ell" style="display:block">${esc(p.name)}</b><span class="mu ell" style="display:block;font-size:12.5px;font-weight:500">${esc(p.region)}</span></span></span></button>`).join('');
};
const wxPaint = () => { const box = document.getElementById('wxres'); if (box) box.innerHTML = wxResHTML(); };
async function wxRun(q) {
  const my = ++wxSeq;
  if (q.length < 2) { wxRes = null; wxBusy = false; wxErr = ''; wxPaint(); return; }
  wxBusy = true; wxErr = ''; wxPaint();
  try {
    const r = await wxSearch(q); if (my !== wxSeq) return;
    wxRes = (r || []).filter(p => p && p.name && isFinite(p.lat) && isFinite(p.lon)).map(p => ({ name: String(p.name), region: String(p.region || ''), lat: +p.lat, lon: +p.lon }));
  } catch { if (my !== wxSeq) return; wxRes = null; wxErr = 'Couldn’t search right now. Check the Mac’s internet connection.'; }
  wxBusy = false; wxPaint();
}
const isQ = el => el && el.matches && el.matches('input[data-wxq]');
document.addEventListener('input', e => {
  if (!isQ(e.target)) return;
  wxQ = e.target.value; clearTimeout(wxTimer);
  const q = wxQ.trim(); wxTimer = setTimeout(() => wxRun(q), q.length < 2 ? 0 : 320);
});
document.addEventListener('keydown', e => {
  if (!isQ(e.target)) return;
  if (e.key === 'Enter') { e.preventDefault(); if (wxRes && wxRes.length && !wxBusy) A.wxPick('0'); else { clearTimeout(wxTimer); wxRun(wxQ.trim()); } }
  else if (e.key === 'Escape' && WX.place) { e.preventDefault(); A.wxCancel(); }
});
/* After a render: focus the box when the search first shows, or put the caret back if it had focus. */
function wxWire(f) {
  const el = document.querySelector('#screen input[data-wxq]'); if (!el || !f) return;
  try { el.focus({ preventScroll: true }); const [a, b] = f === 'auto' ? [el.value.length, el.value.length] : f; el.setSelectionRange(a, b); } catch { /* */ }
}
Object.assign(A, {
  wxEdit: () => { wxEdit = true; wxQ = ''; wxRes = null; wxErr = ''; render(); },
  wxCancel: () => { wxEdit = false; render(); },
  wxPick: v => { const p = wxRes?.[+v]; if (!p) return; wxEdit = false; wxQ = ''; wxRes = null; wxSet(p); }
});

const changeBtn = () => gbtn(`${icon('pin')}<span>Change city</span>`, 'wxEdit', '', '', 'style="height:32px;padding:0 12px;font-size:13px;flex:none"');
const placeLab = () => `<span class="lab ell" style="min-width:0;flex:1">${esc(WX.place.name)}${WX.place.region ? `<span style="opacity:.75">, ${esc(WX.place.region)}</span>` : ''}</span>`;

page('weather', {
  sub: () => WX.place ? esc(WX.place.name) : '',
  sig: () => [searching() ? 's' : WX.data ? 'd' : 'l', WX.place?.name, WX.place?.lat, WX.place?.lon, WX.data?.updated, WX.err, wxEdit].join('|'),
  render: () => {
    if (searching()) {
      const old = document.querySelector('#view input[data-wxq]');
      const f = !old ? 'auto' : document.activeElement === old ? [old.selectionStart, old.selectionEnd] : null;
      queueMicrotask(() => wxWire(f));
      return `<div class="g" style="place-items:center"><div class="glass card" style="width:min(580px,100%);max-height:100%;padding:28px 32px">
        <div class="lab">Weather</div><h2 style="font-size:34px;font-weight:750;letter-spacing:-.02em;margin-top:6px">${WX.place ? 'Change city' : 'Where are you?'}</h2>
        <div class="mu" style="font-size:15px;margin-top:6px;line-height:1.4">Search for your city. The forecast comes from Open‑Meteo, in °C and km/h, and your city is remembered in this browser.</div>
        <div class="row" style="margin-top:18px;gap:10px"><label style="position:relative;flex:1;display:block;min-width:0"><span style="position:absolute;left:16px;top:50%;transform:translateY(-50%);font-size:18px;color:var(--mu);z-index:1;pointer-events:none">${icon('search')}</span>
          <input class="gin" data-wxq type="text" enterkeyhint="search" autocomplete="off" spellcheck="false" maxlength="80" aria-label="City" placeholder="City name" value="${esc(wxQ)}" style="width:100%;height:50px;padding-left:46px;font-size:16px"></label>
          ${WX.place ? gbtn('Cancel', 'wxCancel', '', '', 'style="height:50px;padding:0 20px"') : ''}</div>
        <div id="wxres" aria-live="polite" style="display:flex;flex-direction:column;gap:8px;margin-top:14px;min-height:0;overflow:auto">${wxResHTML()}</div></div></div>`;
    }
    const w = WX.data;
    if (!w) return `<div class="g" style="grid-template-columns:1fr 1.4fr;grid-template-rows:auto 1fr">
      ${card(`<div class="row" style="gap:8px">${placeLab()}${changeBtn()}</div><div class="note"><b>${WX.err ? 'No forecast right now' : 'Loading the forecast…'}</b><span>${esc(WX.err || 'From Open‑Meteo.')}</span></div>`, { st: 'grid-row:1/3' })}
      ${card('<div class="lab">Next 12 hours</div><div style="height:96px"></div>')}${card('<div class="lab">This week</div>')}</div>`;

    const days = w.days || [], d0 = days[0] || {}, lo = Math.min(...days.map(d => d.lo)), hi = Math.max(...days.map(d => d.hi)), rng = hi - lo || 1;
    const sun = s => { const d = s ? new Date(s) : null; return d && !isNaN(d) ? timeStr(d) : ''; }, sr = sun(w.sunrise), ss = sun(w.sunset);
    const dir = wxDir(w.windDir);
    const tiles = [['Feels like', `${w.feels}°`, 'thermo'], ['Humidity', `${w.humidity}%`, 'drop'], [dir ? `Wind, ${dir}` : 'Wind', `${w.wind}<small style="font-size:13px;color:var(--mu);margin-left:3px;font-weight:600">km/h</small>`, 'wind']];
    return `<div class="g" style="grid-template-columns:1fr 1.4fr;grid-template-rows:auto 1fr">
      ${card(`<div class="row" style="gap:8px">${placeLab()}${changeBtn()}</div><div class="big rnd" style="font-size:180px;margin-top:10px">${w.temp}°</div><div style="font-size:28px;font-weight:650;margin-top:10px">${esc(w.cond)}</div>
        <div class="mu" style="font-size:16px;margin-top:4px">${d0.hi != null ? `High ${d0.hi}°, low ${d0.lo}°` : ''}</div>${sr && ss ? `<div class="mu" style="font-size:14px;margin-top:4px">Sunrise ${sr}, sunset ${ss}</div>` : ''}
        <div style="margin-top:auto;display:grid;grid-template-columns:repeat(3,1fr);gap:10px">${tiles.map(([k, v, ic]) => `<div class="glass" style="--r:18px;padding:12px 14px;min-width:0"><div class="row mu" style="${Z}gap:6px;font-size:12.5px;white-space:nowrap">${icon(ic)}<span class="ell">${k}</span></div><b class="rnd" style="${Z}display:block;font-size:22px;white-space:nowrap">${v}</b></div>`).join('')}</div>`, { st: 'grid-row:1/3' })}
      ${card(`<div class="row"><span class="lab">Next 12 hours</span><span class="sp"></span>${w.updated ? `<span class="mu" style="font-size:12.5px">Updated ${timeStr(new Date(w.updated))}</span>` : ''}</div>
        <div class="row" style="justify-content:space-between;margin-top:12px">${(w.hours || []).map((x, k) => `<div style="text-align:center;min-width:0"><div class="mu" style="font-size:12.5px;white-space:nowrap">${k ? hourStr(x.t) : 'Now'}</div><div style="font-size:24px;width:24px;margin:8px auto">${icon(x.icon)}</div><b class="rnd" style="font-size:18px">${x.temp}°</b></div>`).join('')}</div>`)}
      ${card(`<div class="lab">This week</div><div style="flex:1;display:grid;grid-template-rows:repeat(${Math.max(1, days.length)},1fr);min-height:0;margin-top:8px">${days.map((d, k) => `<div style="display:grid;grid-template-columns:70px 28px 48px 40px 1fr 40px;gap:14px;align-items:center;border-top:1px solid var(--sep);font-size:15px">
          <b>${k ? DAY3[d.t.getDay()] : 'Today'}</b><span style="font-size:22px">${icon(d.icon)}</span><span style="font-size:13px;color:#9CF3FF">${d.rain ? d.rain + '%' : ''}</span><span class="mu" style="text-align:right">${d.lo}°</span>
          <span style="height:7px;border-radius:9px;background:rgba(255,255,255,.18);position:relative"><i style="position:absolute;top:0;bottom:0;border-radius:9px;background:linear-gradient(90deg,#9CF3FF,#FFD36E);left:${((d.lo - lo) / rng * 100).toFixed(1)}%;right:${(100 - (d.hi - lo) / rng * 100).toFixed(1)}%"></i></span><b>${d.hi}°</b></div>`).join('')}</div>`)}
    </div>`;
  }
});

/* ---------- Music ---------- */
/* "Recently played": tracks seen while this page is open (any page), newest first, kept in the browser.
   A 96px cover thumbnail is saved when the agent sends the real artwork for that track. */
const MU_KEY = 'mu.recent', MU_MAX = 7;
const tkey = m => [m.title, m.artist, m.album].map(x => x || '').join('␟');
const DATA_IMG = /^data:image\/jpeg;base64,[A-Za-z0-9+/=]+$/;
let recent = (() => { const r = store.get(MU_KEY, []); return Array.isArray(r) ? r.filter(x => x && typeof x.k === 'string' && typeof x.title === 'string').slice(0, MU_MAX) : []; })();
let curKey = '', thumbFor = '';
function seen() {
  const m = media(); if (!m) return;
  const k = tkey(m);
  if (k !== curKey) {
    curKey = k; thumbFor = '';
    const old = recent.find(x => x.k === k);
    recent = [{ k, title: String(m.title), artist: String(m.artist || ''), album: String(m.album || ''), len: +m.duration_ms || 0, img: old?.img || null },
      ...recent.filter(x => x.k !== k)].slice(0, MU_MAX);
    store.set(MU_KEY, recent);
  }
  const a = T['media.art'];
  if (a && a.b64 && m.art_id && a.art_id === m.art_id && thumbFor !== m.art_id) { thumbFor = m.art_id; thumb(a, k); }
}
function thumb(a, k) {
  const mime = /^image\/(jpeg|png|webp|gif)$/.test(a.mime || '') ? a.mime : 'image/jpeg', img = new Image();
  img.onload = () => {
    try {
      const N = 96, c = document.createElement('canvas'), s = Math.min(img.naturalWidth, img.naturalHeight); if (!s) return;
      c.width = c.height = N;
      c.getContext('2d').drawImage(img, (img.naturalWidth - s) / 2, (img.naturalHeight - s) / 2, s, s, 0, 0, N, N);
      const url = c.toDataURL('image/jpeg', .8), it = recent.find(x => x.k === k);
      if (it && DATA_IMG.test(url)) { it.img = url; store.set(MU_KEY, recent); }
    } catch { /* no thumbnail, the generated cover is used */ }
  };
  img.src = `data:${mime};base64,${a.b64}`;
}
setInterval(seen, 1000);
const covers = new Map();   // generated covers, cached so the list's HTML stays the same between refreshes
const cover = x => {
  if (typeof x.img === 'string' && DATA_IMG.test(x.img)) return `<img class="art" alt="" src="${x.img}">`;
  if (!covers.has(x.k)) { const h = hash(x.album || x.title); covers.set(x.k, art(h % 360, (h >>> 9) % 7 + 1)); }
  return covers.get(x.k);
};
charts.muRecent = () => {
  const m = media(), k = m ? tkey(m) : '', list = recent.filter(x => x.k !== k).slice(0, 6);
  if (!list.length) return '<div class="mu" style="padding:6px 0 2px;font-size:13.5px;line-height:1.4">Songs you play while this page is open show up here.</div>';
  return list.map(x => `<div class="li" style="grid-template-columns:52px 1fr"><span style="width:52px;height:52px;border-radius:12px;overflow:hidden;display:block">${cover(x)}</span><div style="min-width:0"><b class="ell">${esc(x.title)}</b><span class="mu ell" style="display:block;font-size:12.5px">${esc([x.artist, x.len ? ms(x.len / 1000) : ''].filter(Boolean).join(', '))}</span></div></div>`).join('');
};
/* The concept's 46px title, smaller for long titles so it stays within three lines of the column. */
charts.muTitle = el => {
  const t = media()?.title || '', w = el.clientWidth;
  const fs = [46, 40, 34, 30, 26].find(f => textW(t, 800, SANS) * f / 100 <= w * 1.75) || 24;
  return `<div style="font-size:${fs}px;font-weight:800;letter-spacing:-.03em;line-height:1.04;${CLAMP(3)}">${esc(t)}</div>`;
};

page('music', {
  sub: () => { const m = media(); return m && m.source ? esc(m.source) + (m.playing ? '' : ', paused') : ''; },
  sig: () => { seen(); const m = media(), a = T['media.art'], c = m?.can || {};
    return [T.media?.status, m ? tkey(m) : '', m?.playing, m?.source, m?.art_id, !!(m && a && a.b64 && a.art_id === m.art_id), !!ok('shortcuts'), c.prev, c.next, c.seek, c.play_pause].join('|'); },
  render: () => {
    seen();
    const m = media(), mo = ok('media'), c = m?.can || {};
    const dis = f => f === false ? ' disabled' : '';
    const vol = ok('shortcuts') ? `<div class="row" style="margin-top:24px;gap:14px"><button data-act="sc" data-v="volume.down" aria-label="Volume down" style="font-size:20px;opacity:.8">${icon('volDown')}</button><div style="flex:1;min-width:0">${slider('vol', 'volset', '', 'Volume')}</div><button data-act="sc" data-v="volume.up" aria-label="Volume up" style="font-size:20px;opacity:.8">${icon('volUp')}</button></div>` : '';
    const cover0 = m ? artFor(m) : `<div style="height:100%;opacity:.55">${art(258, 2)}</div>`;
    const mid = m ? `<div class="lab">${m.playing ? 'Now playing' : 'Paused'}</div><div data-c="muTitle" style="margin-top:6px"></div>
        <div class="ell" style="font-size:24px;color:var(--mu);margin-top:6px">${esc(m.artist || '')}</div>
        <div class="row" style="margin-top:8px;min-width:0"><span class="mu ell" style="font-size:16px;min-width:0">${esc(m.album || '')}</span>${m.source ? pill(`${icon('music')}<span>${esc(m.source)}</span>`, 'height:30px;font-size:13px;flex:none') : ''}</div>
        <div style="margin-top:30px">${slider('music', c.seek === false ? '' : 'seek')}</div><div class="row mu" style="font-size:13px;margin-top:4px"><span data-b="trPos"></span><span class="sp"></span><span data-b="trLeft"></span></div>
        <div class="row" style="justify-content:center;gap:24px;margin-top:18px">${gbtn(icon('prev'), 'prev', '', 'circ', `aria-label="Previous track" style="width:72px;height:72px"${dis(c.prev)}`)}${gbtn(icon(m.playing ? 'pause' : 'play'), 'play', '', 'circ xl', `aria-label="${m.playing ? 'Pause' : 'Play'}" style="width:96px;height:96px"${dis(c.play_pause)}`)}${gbtn(icon('next'), 'next', '', 'circ', `aria-label="Next track" style="width:72px;height:72px"${dis(c.next)}`)}</div>${vol}`
      : mo ? `<div class="lab">Now playing</div><div style="font-size:40px;font-weight:800;letter-spacing:-.03em;line-height:1.04;margin-top:6px">Nothing playing</div><div style="font-size:20px;color:var(--mu);margin-top:10px;line-height:1.3">Play something in Spotify or Apple Music on the Mac and it shows up here.</div>${vol}`
      : `<div class="lab">Now playing</div><div style="margin-top:10px">${note('media', 'What’s playing on the laptop.')}</div>${vol}`;
    return `<div class="g" style="grid-template-columns:auto 1fr 300px;gap:36px;align-items:center;padding:0 10px">
      <div style="height:min(100%,460px);aspect-ratio:1;border-radius:32px;overflow:hidden;box-shadow:0 34px 70px rgba(0,0,0,.45)">${cover0}</div>
      <div style="display:flex;flex-direction:column;min-width:0">${mid}</div>
      ${card(`<div class="lab">Recently played</div><div data-c="muRecent" style="margin-top:2px"></div>`, { st: 'align-self:center;max-height:100%' })}
    </div>`;
  }
});
})();
