/* Hotspot, Timer, Slack, GitHub, Controls: concept 16 desktop (`pages.printer` -> Hotspot,
   `pages.timer`, `pages.games` slot -> Slack, `pages.github`, `pages.shortcuts`), live data. */
(() => {
'use strict';
const { T, S, B, PB, A, charts, page, card, ring, bar, gbtn, seg, pill, icon, esc, ok, note, clamp, dur, ago, timeStr,
  sameDay, hash, DAY3, MON3, TM, TMODES, tMode, tLeft, tSave, req, toast, render, refresh, changed } = DP;

/* ---------- Shared bits ---------- */
const MINT = '#8CFFB0', CYAN = '#9CF3FF', GOLD = '#FFD36E', RED = '#FF8A8A';
const DARK = 'background:rgba(22,24,38,.5)';                 // tinted glass under red / gold figures
const nowA = () => Date.now() + (S.offset || 0);               // the agent's clock
const loc = ts => new Date(ts - (S.offset || 0));              // agent time -> this browser's clock
const agoA = ts => ago(ts - (S.offset || 0));
const trim = (v, dp) => { const s = (+v).toFixed(dp); return (s.includes('.') ? s.replace(/\.?0+$/, '') : s).replace(/^-/, '−'); };
const num = (v, dp = 0) => v == null || !isFinite(v) ? '–' : trim(v, dp);
const plural = (n, w) => `${(+n || 0).toLocaleString()} ${w}${n === 1 ? '' : 's'}`;
const sep = 'border-top:1px solid var(--sep)';

/* "now", "4 min ago", "2 h ago", "Yesterday", "Mon", "Nov 3" (Slack, events). Kept fresh below. */
function relT(ts) {
  if (!ts) return '';
  const m = (nowA() - ts) / 60000, d = loc(ts), n = new Date();
  if (m < 1) return 'now';
  if (m < 60) return `${Math.floor(m)} min ago`;
  if (sameDay(d, n)) return `${Math.floor(m / 60)} h ago`;
  const y = new Date(n); y.setDate(n.getDate() - 1);
  if (sameDay(d, y)) return 'Yesterday';
  if (m < 7 * 1440) return DAY3[d.getDay()];
  return `${MON3[d.getMonth()]} ${d.getDate()}`;
}
const relSpan = (ts, st = '') => `<span class="mu" style="white-space:nowrap;${st}" data-ts="${+ts || 0}" title="${ts ? esc(`${DAY3[loc(ts).getDay()]} ${MON3[loc(ts).getMonth()]} ${loc(ts).getDate()}, ${timeStr(loc(ts))}`) : ''}">${relT(ts)}</span>`;
setInterval(() => document.querySelectorAll('#view [data-ts]').forEach(el => { const t = relT(+el.dataset.ts); if (el.textContent !== t) el.textContent = t; }), 15000);

/* Scroll position of inner lists survives a re-render (a new message, mark read...). */
const KEEP = {};
document.addEventListener('scroll', e => { const k = e.target?.dataset?.keep; if (k) KEEP[k] = e.target.scrollTop; }, true);
charts.pbKeep = el => { if (!el._k) { el._k = 1; const l = el.parentElement; if (l && KEEP[l.dataset.keep]) l.scrollTop = KEEP[l.dataset.keep]; } return ''; };
const keep = '<div data-c="pbKeep" style="height:0"></div>';

const css = document.createElement('style');
css.textContent = `
#screen .pb-list{overflow-y:auto;overflow-x:hidden;min-height:0;scrollbar-width:thin;scrollbar-color:rgba(255,255,255,.3) transparent;overscroll-behavior:contain}
#screen .pb-clamp{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:var(--n,2);overflow:hidden;overflow-wrap:anywhere;white-space:pre-line}
#screen .pb-av{flex:none;display:grid;place-items:center;border-radius:50%;font-weight:750;letter-spacing:0;line-height:1;box-shadow:inset 0 0 0 1px rgba(255,255,255,.35)}
#screen .pb-msg{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:14px;align-items:center;padding:10px 12px;border-radius:18px;transition:background .2s}
#screen .pb-msg+.pb-msg{margin-top:4px}
#screen .pb-msg:hover{background:rgba(255,255,255,.07)}
#screen .pb-msg.un{background:rgba(255,255,255,.14);box-shadow:inset 0 1px 0 rgba(255,255,255,.28)}
#screen .pb-ib{width:36px;height:36px;border-radius:50%;display:grid;place-items:center;font-size:17px;background:rgba(255,255,255,.14);box-shadow:inset 0 1px 0 rgba(255,255,255,.35);transition:background .2s,transform .25s cubic-bezier(.3,1.6,.5,1)}
#screen .pb-ib:hover{background:rgba(255,255,255,.3)}
#screen .pb-ib:active{transform:scale(1.12)}
#screen .pb-ev+.pb-ev,#screen .pb-kv+.pb-kv{border-top:1px solid var(--sep)}
#screen .pb-vol{cursor:ns-resize;touch-action:none;user-select:none;-webkit-user-select:none}
#screen .pb-vol.pb-drag .lvl{transition:none}
#screen .pb-vol button{flex:none;cursor:pointer}
#screen .tog{min-width:0;max-width:100%}
#screen:is([data-page="hotspot"],[data-page="timer"]) .ring .fill{filter:none}
#screen:is([data-page="hotspot"],[data-page="timer"]) .ring svg{filter:drop-shadow(0 0 6px rgba(255,255,255,.4))}`;
/* (The glow moves from the ring's arc to its svg on these pages: a drop-shadow on the arc
   itself paints a faint square around big rings in Chrome.) */
document.head.appendChild(css);

/* ================================================================ Hotspot */
/* The roof phone (Hotspot Monitor), laid out like the concept's Printer page: the signal ring
   tall on the left, speed / data / battery / events on the right. Wording follows the phone. */
const hs = () => ok('hotspot');
const GRADE = { excellent: MINT, good: CYAN, fair: GOLD, poor: RED };
const GRADE_L = { excellent: 'Excellent', good: 'Good', fair: 'Fair', poor: 'Poor' };
const parts = (v, u, step = 1000) => { if (v == null || !isFinite(v)) return ['–', u[2] || u[0]]; let x = Math.max(0, +v), i = 0; while (x >= step && i < u.length - 1) { x /= step; i++; } return [i === 0 || x >= 100 ? String(Math.round(x)) : trim(x, 1), u[i]]; };
const bpsP = b => parts(b, ['bps', 'kbps', 'Mbps', 'Gbps']);         // rx_bps / tx_bps are bits/s
const byteP = b => b == null ? ['–', 'GB'] : parts(b, ['B', 'KB', 'MB', 'GB', 'TB']);
const byteS = b => b == null ? '–' : byteP(b).join(' ');
const hsState = d => !d.online ? 'offline' : d.internet === false ? 'down' : d.heat === 'hot' || d.radio_resting ? 'hot' : d.low_battery ? 'low' : 'ok';
const hsStateL = d => ({ offline: 'Offline', down: 'No internet', hot: d.radio_resting ? 'Radio resting' : 'Too hot', low: 'Battery low', ok: 'Online' })[hsState(d)];
function hsAlert(d) {
  if (!d.online) return `The phone isn’t connected to the Hotspot Monitor Server${d.last_seen ? ` (last seen ${agoA(d.last_seen)})` : ''}.`;
  if (d.internet === false) {
    const m = d.down_since ? (nowA() - d.down_since) / 60000 : null;
    return `Internet down on the phone${m == null ? '' : m < 1 ? ' for under a minute' : ` for ${dur(m)}`}. The watchdog recovers it by itself.`;
  }
  if (d.radio_resting) return 'The radio is resting to cool down.';
  if (d.heat === 'hot') return `Battery at ${num(d.battery_c, 1)} °C: charging stopped to cool down.`;
  return null;
}
function hsSession(d) {
  const e = d.session_expires; if (!e) return null;
  const left = e - nowA(); if (left > 5 * 864e5) return null;
  if (left < 0) return 'Sign-in to Hotspot Monitor expired: run deskpanel-agent hotspot-login on the Mac';
  const n = Math.max(1, Math.round(left / 864e5));
  return `Sign-in to Hotspot Monitor ends in ${n} day${n === 1 ? '' : 's'}`;
}
const qFrac = d => d.quota ? (d.cycle_used || 0) / d.quota : null;
const qLevel = q => q == null ? 'n' : q >= 1 ? 2 : q >= .8 ? 1 : 0;
const cap = s => s ? String(s).charAt(0).toUpperCase() + String(s).slice(1) : '';
const plugL = p => !p ? '' : /^(none|unplugged)$/i.test(p) ? 'Unplugged' : p.length <= 3 ? p.toUpperCase() : cap(p);
const cycleL = s => { const m = /^(\d{4})-(\d\d)-(\d\d)/.exec(s || ''); return m ? `${MON3[+m[2] - 1]} ${+m[3]}` : '–'; };

/* Bindings: the numbers refresh in place (the topic comes every 30 s). */
const HB = {
  ago: d => d.updated ? agoA(d.updated) : 'never',
  strip: d => hsAlert(d) || hsSession(d) || '',
  score: d => d.score == null ? '–' : Math.round(d.score),
  rsrp: d => num(d.rsrp), sinr: d => num(d.sinr, 1), rsrq: d => num(d.rsrq),
  rx: d => bpsP(d.rx_bps)[0], rxU: d => bpsP(d.rx_bps)[1], tx: d => bpsP(d.tx_bps)[0], txU: d => bpsP(d.tx_bps)[1],
  ping: d => d.ping_ms == null ? '–' : Math.round(d.ping_ms), loss: d => num(d.loss_pct, 1), jit: d => num(d.jitter_ms, 1),
  used: d => byteP(d.cycle_used)[0], usedU: d => byteP(d.cycle_used)[1],
  qpct: d => d.quota ? Math.round(qFrac(d) * 100) + '% used' : '',
  today: d => byteS(d.today_used), left: d => d.quota ? byteS(Math.max(0, d.quota - (d.cycle_used || 0))) : '–',
  bat: d => d.battery_pct == null ? '–' : Math.round(d.battery_pct),
  ma: d => d.current_ma == null ? '' : `${d.current_ma > 0 ? '+' : d.current_ma < 0 ? '−' : ''}${Math.abs(Math.round(d.current_ma))} mA`,
  batC: d => num(d.battery_c, 1), cpuC: d => num(d.cpu_c, 1), modC: d => num(d.modem_c, 1),
  up: d => d.uptime_s == null ? '–' : dur(d.uptime_s / 60)
};
const STALE = new Set(['rx', 'tx', 'ping', 'loss', 'jit']);  // meaningless while the phone is offline
for (const [k, f] of Object.entries(HB)) B['hb_' + k] = () => { const d = hs(); return !d ? '' : !d.online && STALE.has(k) ? '–' : f(d); };
const hb = k => `<span data-b="hb_${k}"></span>`;
PB.hbScore = () => (hs()?.score || 0) / 100;
PB.hbQuota = () => { const d = hs(); return d ? qFrac(d) || 0 : 0; };
PB.hbBat = () => (hs()?.battery_pct || 0) / 100;

const kv = (k, v, st = '') => `<div class="row pb-kv" style="padding:8px 0;font-size:14.5px;${st}"><span class="mu" style="flex:none">${k}</span><span class="sp"></span><b class="ell" style="font-weight:650;min-width:0;text-align:right">${v}</b></div>`;
const stat = (l, v, u) => `<div style="min-width:0"><div class="lab" style="font-size:12.5px">${l}</div><div class="big rnd" style="font-size:28px;margin-top:5px">${v}<small>${u}</small></div></div>`;
const dotI = (c, sz = 8) => `<i style="display:inline-block;flex:none;width:${sz}px;height:${sz}px;border-radius:50%;background:${c};box-shadow:0 0 8px ${c}"></i>`;

page('hotspot', {
  sub: () => { const d = hs(); return d ? `${esc(d.name || 'Roof phone')}${d.updated ? `, updated ${hb('ago')}` : ''}` : 'Hotspot Monitor'; },
  sig: () => {
    const d = hs();
    if (!d) return ['none', S.conn === 'live', T.hotspot?.status, T.hotspot?.message].join('|');
    return [d.name, d.online, d.internet, d.grade, d.heat, d.radio_resting, d.low_battery, d.charge_status, d.plug, d.charge_note, Math.sign(d.current_ma || 0),
      d.tether_on, d.clients, d.quota, qLevel(qFrac(d)), d.operator, d.net_type, d.band, d.thermal, d.boot_count, d.boot_reason, d.cycle_start,
      (d.events || []).map(e => e.ts + e.severity + e.message).join(), !!hsAlert(d), !!hsSession(d)].join('|');
  },
  render: () => {
    const d = hs();
    if (!d) return `<div class="g">${card(note('hotspot', 'Your roof phone’s signal, data and battery from Hotspot Monitor. Run deskpanel-agent hotspot-login on the Mac to connect it.'))}</div>`;
    const st = hsState(d), bad = st === 'offline' || st === 'down' || st === 'hot', al = hsAlert(d), sn = hsSession(d);
    const stC = bad ? RED : st === 'low' ? GOLD : '#5CF29B';

    const strip = al || sn ? card(`${dotI('#fff')}<b class="ell" style="flex:1;font-size:15px" data-b="hb_strip"></b>${al && sn ? `<span class="ell" style="font-size:13px;max-width:40%">${esc(sn)}</span>` : ''}`,
      { st: `grid-column:1/-1;flex-direction:row;align-items:center;gap:12px;padding:11px 22px;--r:99px;background:${al ? 'rgba(229,72,77,.66)' : 'rgba(255,181,71,.5)'}` }) : '';

    // Signal (the concept's big ring card, both rows)
    const gc = !d.online ? 'rgba(255,255,255,.55)' : GRADE[d.grade] || '#fff';
    const statePill = pill(`${dotI(stC)}<span>${hsStateL(d)}</span>`, `height:30px;font-size:13.5px;${bad ? 'background:rgba(229,72,77,.66)' : ''}`);
    const sharing = d.tether_on === true ? `On, ${d.clients == null ? 'sharing' : plural(d.clients, 'device')}` : d.tether_on === false ? 'Off' : '–';
    const sig = card(`<div class="row"><span class="lab">Signal score</span><span class="sp"></span>${statePill}</div>
      <div style="flex:1;display:grid;place-items:center;min-height:0">${ring('hbScore', `<div class="rnd" style="font-size:92px;line-height:1">${hb('score')}</div><div style="font-size:19px;font-weight:700;margin-top:8px;color:${gc}">${!d.online ? 'Last known' : GRADE_L[d.grade] || 'of 100'}</div>`, 320, { sw: 7, c: gc })}</div>
      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px;text-align:center;margin-bottom:12px">${stat('RSRP', hb('rsrp'), 'dBm')}${stat('SINR', hb('sinr'), 'dB')}${stat('RSRQ', hb('rsrq'), 'dB')}</div>
      ${kv('Network', esc([d.net_type, d.band].filter(Boolean).join(' · ') || '–'), sep)}${kv('Operator', esc(d.operator || '–'))}${kv('Sharing', sharing)}
      ${kv('Uptime', `${hb('up')}${d.boot_count != null ? `<span class="mu" style="font-weight:500">, boot #${esc(d.boot_count)}${d.boot_reason ? ` (${esc(d.boot_reason)})` : ''}</span>` : ''}`)}`,
      { st: `grid-row:span 2;${!d.online || d.grade === 'fair' || d.grade === 'poor' ? DARK : ''}` });

    // Speed now
    const live = d.online && d.internet !== false;
    const dir = (ic, c, l) => `<div class="row" style="gap:7px;font-size:13.5px;font-weight:600"><span style="font-size:17px;color:${c}">${icon(ic)}</span><span class="mu">${l}</span></div>`;
    const speed = card(`<div class="row"><span class="lab">Speed now</span><span class="sp"></span><span class="mu" style="font-size:12.5px">${live ? esc(d.net_type || '') : d.online ? 'No internet' : 'Phone offline'}</span></div>
      <div style="margin-top:14px">${dir('down', CYAN, 'Download')}<div class="big rnd" style="font-size:76px;margin-top:6px">${hb('rx')}<small>${hb('rxU')}</small></div></div>
      <div style="margin-top:16px">${dir('up', GOLD, 'Upload')}<div class="big rnd" style="font-size:46px;margin-top:6px">${hb('tx')}<small>${hb('txU')}</small></div></div>
      <div style="margin-top:auto;display:grid;grid-template-columns:repeat(3,1fr);gap:8px;${sep};padding-top:12px">${stat('Ping', hb('ping'), 'ms')}${stat('Loss', hb('loss'), '%')}${stat('Jitter', hb('jit'), 'ms')}</div>`,
      { st: live ? '' : DARK });

    // Data this cycle
    const q = qFrac(d), qc = q == null ? '#fff' : q >= 1 ? RED : q >= .8 ? GOLD : '#fff';
    const data = card(`<div class="row"><span class="lab">Data this cycle</span><span class="sp"></span>${q != null ? `<b style="color:${qc};font-size:13.5px">${hb('qpct')}</b>` : ''}</div>
      <div class="big rnd" style="font-size:76px;margin-top:20px">${hb('used')}<small>${hb('usedU')}</small></div>
      ${q != null ? `${bar('hbQuota', qc, 'height:10px;margin-top:18px')}<div class="mu" style="margin-top:8px;font-size:13.5px">of a ${byteS(d.quota)} quota</div>` : '<div class="mu" style="margin-top:14px">No quota set</div>'}
      <div style="margin-top:auto">${kv('Today', hb('today'))}${kv('Cycle started', cycleL(d.cycle_start))}${d.quota ? kv('Left this cycle', hb('left')) : ''}</div>`,
      { st: q != null && q >= .8 ? DARK : '' });

    // Battery and heat
    const low = d.low_battery, bc = low ? RED : '#fff';
    const [hl, hc] = { warm: ['Warm', GOLD], hot: ['Hot', RED] }[d.heat] || ['Normal', MINT];
    const maC = !d.current_ma ? 'var(--mu)' : d.current_ma < 0 ? GOLD : MINT;
    const tRow = (l, k, c = '#fff') => `<div class="row pb-kv" style="padding:8px 0;font-size:15px"><span style="font-size:18px;color:${c}">${icon('thermo')}</span><span>${l}</span><span class="sp"></span><b class="rnd" style="font-size:24px;color:${c}">${hb(k)}</b><span class="mu" style="font-size:13px;width:22px">°C</span></div>`;
    const batt = card(`<div class="row"><span class="lab">Battery and heat</span><span class="sp"></span>${pill(`${dotI(hc)}<span>${d.radio_resting ? 'Radio resting' : hl}</span>`, 'height:28px;font-size:13px')}</div>
      <div class="row" style="margin-top:12px;align-items:flex-end;gap:14px"><span class="big rnd" style="font-size:76px;color:${bc}">${hb('bat')}<small>%</small></span><span class="sp"></span>
        <div style="text-align:right;min-width:0;line-height:1.35"><b style="font-size:15px">${esc(cap(d.charge_status) || 'Battery')}</b><div class="mu ell" style="font-size:12.5px">${esc([plugL(d.plug), d.charge_note].filter(Boolean).join(', '))}</div><div style="font-size:12.5px;font-weight:650;color:${maC}">${hb('ma')}</div></div></div>
      ${bar('hbBat', bc, 'margin-top:12px')}
      <div style="margin-top:auto">${tRow('Battery', 'batC', d.heat === 'hot' ? RED : d.heat === 'warm' ? GOLD : '#fff')}${tRow('Processor', 'cpuC')}${tRow('Modem', 'modC')}</div>
      <div class="mu" style="font-size:12.5px;margin-top:2px">Thermal status ${esc(d.thermal || '–')}</div>`,
      { st: low || d.heat !== 'ok' || d.radio_resting ? DARK : '' });

    // Recent events
    const ev = d.events || [], sevC = { critical: RED, warning: GOLD };
    const events = card(`<div class="row"><span class="lab">Recent events</span><span class="sp"></span><span class="mu" style="font-size:12.5px">${ev.length || ''}</span></div>
      <div class="pb-list" data-keep="hsev" style="flex:1;margin-top:6px">${ev.length ? ev.map(e => `<div class="pb-ev" style="display:grid;grid-template-columns:8px minmax(0,1fr) auto;gap:10px;align-items:baseline;padding:7px 0">
          <i style="width:8px;height:8px;border-radius:50%;background:${sevC[e.severity] || 'rgba(255,255,255,.5)'};transform:translateY(-1px)"></i>
          <span class="pb-clamp" style="--n:2;font-size:13.5px;line-height:1.3;color:${sevC[e.severity] || '#fff'};font-weight:${e.severity === 'info' ? 500 : 650}" title="${esc(e.message)}">${esc(e.message)}</span>${relSpan(e.ts, 'font-size:12px')}</div>`).join('')
        : '<div class="note"><b>No events yet</b><span>Drops, reboots and heat warnings show up here.</span></div>'}${keep}</div>`,
      { st: ev.some(e => e.severity !== 'info') ? DARK : '' });

    return `<div class="g" style="grid-template-columns:1.1fr 1fr 1fr;grid-template-rows:${strip ? 'auto ' : ''}minmax(0,1fr) minmax(0,1fr)">${strip}${sig}${speed}${data}${batt}${events}</div>`;
  }
});

/* ================================================================ Timer */
B.tEnds = () => TM.endsAt ? `Ends at ${timeStr(new Date(TM.endsAt))}` : TM.left < tMode().min * 60 ? 'Paused' : '';
Object.assign(A, {
  tStart: () => {
    if (TM.endsAt) { TM.left = Math.max(1, tLeft()); TM.endsAt = 0; }
    else { if (!(TM.left > 0)) TM.left = tMode().min * 60; TM.endsAt = Date.now() + TM.left * 1000; }
    tSave(); render();
  },
  tReset: () => { TM.endsAt = 0; TM.left = tMode().min * 60; tSave(); render(); },
  tMode: v => { if (!TMODES.some(m => m.id === v)) return; TM.mode = v; TM.endsAt = 0; TM.left = tMode().min * 60; tSave(); render(); }
});

page('timer', {
  sub: () => 'Focus and breaks',
  sig: () => [TM.mode, !!TM.endsAt, TM.sessions].join('|'),
  render: () => {
    const m = tMode(), run = !!TM.endsAt;
    return `<div class="g" style="grid-template-columns:auto 1fr;gap:60px;align-items:center;padding-left:60px">
      ${ring('timer', `<div class="rnd" style="font-size:120px;line-height:1" data-b="timer"></div><div class="mu" style="font-size:18px;margin-top:10px">${esc(m.label)}</div><div class="mu" style="font-size:14px;margin-top:4px;opacity:.85" data-b="tEnds"></div>`, 520, { sw: 4 })}
      <div style="display:flex;flex-direction:column;gap:24px;align-items:flex-start;min-width:0">${seg(TMODES.map(x => [x.id, `${x.label}, ${x.min} min`]), TM.mode, 'tMode')}
        <div class="row" style="gap:12px">${gbtn(`${icon(run ? 'pause' : 'play')}<span data-b="tLabel"></span>`, 'tStart', '', 'solid', 'style="height:64px;padding:0 40px;font-size:19px;min-width:180px"')}${gbtn('Reset', 'tReset', '', '', 'style="height:64px;padding:0 28px;font-size:17px"')}</div>
        <div class="row" style="gap:8px">${[0, 1, 2, 3].map(i => `<i style="width:44px;height:10px;border-radius:9px;background:${i < TM.sessions ? '#fff' : 'rgba(255,255,255,.25)'}"></i>`).join('')}<span class="mu" style="margin-left:8px;font-size:16px">${TM.sessions} of 4 focus sessions today</span></div></div>
    </div>`;
  }
});

/* ================================================================ Slack */
/* The concept's Games slot: the unread count and the newest unread message large on the left
   (like "Playing now"), every other message in a list on the right. */
const sl = () => ok('slack');
const KIND = { dm: 'slack', group: 'users', mention: 'at' };
const where = m => `${m.kind === 'dm' ? 'Direct message' : esc(m.channel || 'Channel')}${m.thread ? ', in a thread' : ''}`;
const avCol = m => /^#[0-9a-f]{6}$/i.test(m.sender_color || '') ? m.sender_color : `hsl(${hash(m.sender) % 360} 62% 52%)`;
const light = c => { if (c[0] !== '#') return false; const n = parseInt(c.slice(1), 16); return (.2126 * (n >> 16 & 255) + .7152 * (n >> 8 & 255) + .0722 * (n & 255)) / 255 > .62; };
const initials = s => { const p = String(s || '').split(/[\s._-]+/).filter(Boolean); if (!p.length) return '?'; return (p.length === 1 ? Array.from(p[0]).slice(0, 2).join('') : Array.from(p[0])[0] + Array.from(p[1])[0]).toUpperCase(); };
const avatar = (m, sz, dim) => { const c = avCol(m); return `<span class="pb-av" aria-hidden="true" style="width:${sz}px;height:${sz}px;font-size:${Math.round(sz * .38)}px;background:${c};color:${light(c) ? '#111' : '#fff'};${dim ? 'opacity:.5' : ''}">${esc(initials(m.sender))}</span>`; };
const ib = (ic, act, v, label) => `<button class="pb-ib" data-act="${act}" data-v="${esc(v)}" title="${label}" aria-label="${label}">${icon(ic)}</button>`;
const unreadOf = s => (s.messages || []).filter(m => m.unread);

/* Mark read straight away here, then tell the agent (its update follows). */
function slMark(test) {
  const s = sl(); if (!s) return () => {};
  const hit = (s.messages || []).filter(m => m.unread && test(m));
  hit.forEach(m => { m.unread = false; });
  s.unread = Math.max(0, (s.unread || 0) - hit.length); if (!unreadOf(s).length && test === ALL) s.unread = 0;
  changed();
  return () => { const c = sl(); if (c !== s) return; hit.forEach(m => { m.unread = true; }); s.unread += hit.length; changed(); };
}
const ALL = () => true;
Object.assign(A, {
  slRead: v => { const undo = slMark(m => m.id === v); req('slack.read', { id: v }).catch(undo); },
  slReadAll: () => { const undo = slMark(ALL); req('slack.read', { all: true }).then(() => toast('Marked everything read')).catch(undo); },
  slOpen: v => {
    const undo = slMark(m => m.channel_id === v);
    req('slack.open', { channel_id: v }).then(r => toast(r?.message && r.message !== 'Opened in Slack' ? r.message : 'Opened in Slack on your Mac')).catch(undo);
  }
});

const caughtUp = (s, wide) => card(`<div style="flex:1;display:grid;place-items:center;text-align:center"><div>
    <span class="glass" style="--r:50%;width:${wide ? 108 : 92}px;height:${wide ? 108 : 92}px;display:grid;place-items:center;margin:0 auto;font-size:${wide ? 44 : 38}px"><span style="position:relative;z-index:3">${icon('check')}</span></span>
    <div style="font-size:${wide ? 34 : 30}px;font-weight:750;letter-spacing:-.02em;margin-top:20px">All caught up</div>
    <div class="mu" style="font-size:15px;margin-top:6px">${wide ? 'No messages' : 'No unread messages'}${s.team ? ' in ' + esc(s.team) : ''}</div></div></div>`);

page('slack', {
  sub: () => { const s = sl(); return esc(s?.team || 'Slack'); },
  sig: () => { const s = sl(); return [S.conn === 'live', T.slack?.status, T.slack?.message, s?.team, s?.unread, (s?.messages || []).map(m => m.id + (m.unread ? '*' : '')).join()].join('|'); },
  render: () => {
    const s = sl();
    if (!s) return `<div class="g">${card(note('slack', 'Direct messages and mentions from Slack. Set up Slack in ~/.deskpanel/config.toml on the Mac.'))}</div>`;
    const msgs = s.messages || [];
    if (!msgs.length) return `<div class="g">${caughtUp(s, true)}</div>`;
    const un = unreadOf(s), hero = un[0] || null, rest = msgs.filter(m => m !== hero), count = Math.max(s.unread || 0, un.length);
    const hl = hero ? String(hero.text || '').length : 0, heroF = hl < 70 ? 32 : hl < 160 ? 25 : 20, heroN = heroF === 32 ? 6 : heroF === 25 ? 8 : 10;

    const left = hero ? card(`<div class="row" style="align-items:flex-end"><div class="big rnd" style="font-size:96px">${count}<small>unread</small></div><span class="sp"></span>${gbtn(`${icon('checks')}<span>Mark all read</span>`, 'slReadAll', '', '', 'style="height:42px"')}</div>
        <div style="height:1px;background:var(--sep);margin:20px 0 16px"></div>
        <div class="lab">Newest</div>
        <div class="row" style="gap:14px;margin-top:12px">${avatar(hero, 56)}<div style="min-width:0;flex:1"><div class="ell" style="font-size:22px;font-weight:750;letter-spacing:-.01em">${esc(hero.sender)}</div>
          <div class="row mu" style="gap:6px;font-size:14px;margin-top:3px;min-width:0"><span style="font-size:15px">${icon(KIND[hero.kind] || 'slack')}</span><span class="ell">${where(hero)}</span><span>·</span>${relSpan(hero.ts)}</div></div></div>
        <div class="pb-clamp" style="--n:${heroN};font-size:${heroF}px;line-height:1.38;margin-top:18px;font-weight:${heroF > 24 ? 600 : 500};letter-spacing:-.01em">${esc(hero.text)}</div>
        <div class="row" style="gap:10px;margin-top:auto;padding-top:18px">${gbtn(`${icon('slack')}<span>Open in Slack</span>`, 'slOpen', hero.channel_id, 'solid', 'style="height:48px;padding:0 22px;font-size:15px"')}${gbtn(`${icon('check')}<span>Mark read</span>`, 'slRead', hero.id, '', 'style="height:48px;padding:0 20px;font-size:15px"')}</div>`)
      : caughtUp(s, false);

    const row = m => `<div class="pb-msg ${m.unread ? 'un' : ''}">${avatar(m, 40, !m.unread)}
        <div style="min-width:0"><div class="row" style="gap:8px;min-width:0"><b class="ell" style="font-size:15px;flex:none;max-width:55%;${m.unread ? 'font-weight:750' : 'font-weight:600;color:var(--mu)'}">${esc(m.sender)}</b>
          <span class="row mu" style="gap:5px;font-size:12.5px;min-width:0;flex:1"><span style="font-size:13px">${icon(KIND[m.kind] || 'slack')}</span><span class="ell">${where(m)}</span></span>${relSpan(m.ts, `font-size:12.5px;${m.unread ? 'color:#fff;font-weight:650' : ''}`)}</div>
          <div class="pb-clamp" style="--n:2;font-size:14px;line-height:1.4;margin-top:3px;${m.unread ? '' : 'color:var(--fa)'}">${esc(m.text)}</div></div>
        <div class="row" style="gap:6px">${m.unread ? ib('check', 'slRead', m.id, 'Mark read') : '<span style="width:36px"></span>'}${ib('open', 'slOpen', m.channel_id, 'Open in Slack')}</div></div>`;
    const list = card(`<div class="row" style="padding-right:4px"><span class="lab">${hero ? 'Earlier' : 'Recent'}</span><span class="sp"></span><span class="mu" style="font-size:12.5px">${rest.length} message${rest.length === 1 ? '' : 's'}</span></div>
      <div class="pb-list" data-keep="slack" style="flex:1;margin:8px -10px 0;padding:0 6px 4px">${rest.length ? rest.map(row).join('') : '<div class="note" style="align-items:center"><b>Nothing else</b><span>Older messages show up here.</span></div>'}${keep}</div>`,
      { st: 'padding-bottom:10px' });
    return `<div class="g" style="grid-template-columns:minmax(0,1fr) minmax(0,1.35fr)">${left}${list}</div>`;
  }
});

/* ================================================================ GitHub */
B.ghAgo = () => { const g = ok('github'); return g?.fetched_at ? 'Updated ' + agoA(g.fetched_at) : ''; };
const dayL = s => { const m = /^(\d{4})-(\d\d)-(\d\d)/.exec(s || ''); return m ? `${MON3[+m[2] - 1]}\u00a0${+m[3]}` : ''; };

page('github', {
  sub: () => { const g = ok('github'); return 'Last 12 months' + (g?.user ? ', @' + esc(g.user) : ''); },
  sig: () => { const g = ok('github'); return [S.conn === 'live', T.github?.status, T.github?.message, g?.fetched_at, g?.user, new Date().getDay()].join('|'); },
  render: () => {
    const g = ok('github');
    if (!g) return `<div class="g">${card(note('github', 'Your contributions over the last year. Add a GitHub token under [github] in ~/.deskpanel/config.toml on the Mac.'))}</div>`;
    const y = g.year || {}, k = g.streak || {}, wk = g.week || {}, repos = g.top_repos || [];
    const totals = [`${(+y.total || 0).toLocaleString()} total`, `${(+y.commits || 0).toLocaleString()} commits`, `${(+y.private || 0).toLocaleString()} private`, plural(y.issues, 'issue'), plural(y.prs, 'PR'), ...(y.reviews ? [plural(y.reviews, 'review')] : [])].join(', ');
    const heat = card(`<div class="row"><span class="lab">Contributions</span><span class="sp"></span><span class="mu ell" style="min-width:0">${totals}</span><span class="mu" style="font-size:12.5px;white-space:nowrap;margin-left:6px;opacity:.8" data-b="ghAgo"></span></div>
      ${(y.weeks || []).length ? '<div data-c="heat" style="margin-top:12px"></div>' : '<div class="mu" style="margin-top:12px">No contributions yet</div>'}`, { st: 'grid-column:1/-1' });

    const cur = +k.current || 0, best = k.best_day;
    const streak = card(`<div class="lab">Streak</div><div class="big rnd" style="font-size:${String(cur).length > 2 ? 92 : 120}px;margin-top:6px">${cur}<small>${cur === 1 ? 'day' : 'days'}</small></div>
      <div class="mu" style="margin-top:auto;font-size:15px;line-height:1.45">Longest ${plural(k.longest, 'day')}.${best && best.count ? ` Best day ${best.count} on ${dayL(best.date)}.` : ''}</div>`);

    const th = wk.this || [], la = wk.last || [], td = new Date().getDay();
    const mx = Math.max(1, ...th.filter(v => v != null), ...la.filter(v => v != null));
    const delta = +wk.delta || 0;
    const bars = [0, 1, 2, 3, 4, 5, 6].map(i => {
      const v = th[i], l = la[i] ?? 0, fut = v == null, now = i === td;
      return `<div style="display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;gap:6px;min-height:0">
        <div style="flex:1;width:100%;display:flex;gap:4px;align-items:flex-end;justify-content:center;min-height:0">
          <i title="Last ${DAY3[i]}: ${l}" style="width:12px;border-radius:99px;height:${(l / mx * 90).toFixed(1)}%;min-height:6px;background:rgba(255,255,255,.25)"></i>
          ${fut ? '<i style="width:16px"></i>' : `<i title="${now ? 'Today' : DAY3[i]}: ${v}" style="width:16px;border-radius:99px;height:${(v / mx * 90).toFixed(1)}%;min-height:6px;background:${now ? '#fff' : 'rgba(255,255,255,.65)'};${now ? 'box-shadow:0 0 14px rgba(255,255,255,.55)' : ''}"></i>`}
        </div><span style="font-size:12.5px;${now ? 'font-weight:750;color:#fff' : 'color:var(--mu)'}">${'SMTWTFS'[i]}</span></div>`;
    }).join('');
    const week = card(`<div class="row"><span class="lab">This week</span><span class="sp"></span><b class="rnd" style="font-size:22px">${(+wk.this_total || 0).toLocaleString()}</b><span style="color:${delta >= 0 ? MINT : 'var(--mu)'};font-weight:650;margin-left:8px">${delta >= 0 ? '+' : '−'}${Math.abs(delta)}</span></div>
      <div class="row mu" style="gap:14px;font-size:12px;margin-top:4px"><span class="row" style="gap:6px"><i style="width:10px;height:10px;border-radius:3px;background:#fff"></i>This week</span><span class="row" style="gap:6px"><i style="width:10px;height:10px;border-radius:3px;background:rgba(255,255,255,.3)"></i>Last week</span></div>
      <div style="flex:1;display:grid;grid-template-columns:repeat(7,1fr);gap:12px;align-items:end;margin-top:10px;min-height:0">${bars}</div>`);

    const rmx = Math.max(1, ...repos.map(r => +r.count || 0));
    const top = card(`<div class="lab">Top repos</div>${repos.length ? `<div class="pb-list" data-keep="repos" style="flex:1;margin-top:6px">${repos.slice(0, 10).map((r, i) => `<div style="padding:12px 0;${i ? sep : ''}"><div class="row" style="font-size:16px"><span class="ell" style="flex:1">${esc(r.name)}</span><b class="rnd" style="font-size:17px">${(+r.count || 0).toLocaleString()}</b></div>${bar('', '#fff', `--p:${((+r.count || 0) / rmx).toFixed(3)};height:6px;margin-top:8px`)}</div>`).join('')}</div>`
      : '<div class="note"><b>No activity yet</b><span>Repos you contribute to show up here.</span></div>'}`);

    return `<div class="g" style="grid-template-columns:.8fr 1.1fr 1fr;grid-template-rows:auto minmax(0,1fr)">${heat}${streak}${week}${top}</div>`;
  }
});

/* ================================================================ Controls */
/* The concept's Control Center: round toggles in a grid (lit while active) and the tall glass
   volume capsule. The grid grows columns, then rows, with the number of tiles. */
const TICON = { mic: ['mic', 'micOff'], speaker: ['speaker', 'speakerOff'], vol_down: ['volDown'], vol_up: ['volUp'], screenshot: ['shot'], terminal: ['terminal'], folder: ['folder'], lock: ['lock'], play: ['play'] };
const ticon = t => { const p = TICON[t.icon] || [t.icon]; return t.state?.active && p[1] ? p[1] : p[0]; };
const TOGGLE = { 'mic.toggle': ['Mic muted', 'Microphone muted', 'Microphone on'], 'sound.toggle': ['Sound muted', 'Sound muted', 'Sound on'] };
const tLabel = t => (t.state?.active && TOGGLE[t.id]?.[0]) || { 'volume.down': 'Volume down', 'volume.up': 'Volume up' }[t.id] || t.label;
const HINT = { screenshot: 'Full screen', terminal: 'New window', downloads: 'Open folder', lock: 'Right away' };
const ccTiles = () => (ok('shortcuts')?.tiles || []).filter(t => t.id !== 'phone.watch');

/* Volume: the capsule follows a drag at once; the agent gets volume.set at most ~7 times a
   second, and the dragged level wins over older topic updates for a moment after release. */
let drag = null, hold = null;
const volNow = () => hold && (drag || Date.now() < hold.until) ? hold.pct : ok('shortcuts')?.volume_pct;
B.ccVol = () => { const v = volNow(); return v == null ? '–' : Math.round(v) + '%'; };
PB.ccVol = () => (volNow() || 0) / 100;
function volSend(pct, force) {
  const t = Date.now();
  if (!force && drag && t - drag.last < 140) return;
  if (drag) { if (pct === drag.sent) return; drag.sent = pct; drag.last = t; }
  req('volume.set', { pct }).catch(() => {});
}
function volAt(e, final) {
  const el = drag.el.isConnected ? drag.el : document.querySelector('#view .pb-vol'); if (!el) return;
  const r = el.getBoundingClientRect(), pct = Math.round(clamp((r.bottom - e.clientY) / (r.height || 1), 0, 1) * 100);
  hold = { pct, until: Date.now() + 1500 }; el.setAttribute('aria-valuenow', pct); refresh();
  volSend(pct, final);
}
document.addEventListener('pointerdown', e => {
  const el = e.target.closest?.('#view .pb-vol'); if (!el || e.target.closest('button') || e.button > 0) return;
  if (S.conn !== 'live') { toast('The laptop isn’t connected'); return; }
  e.preventDefault(); drag = { el, id: e.pointerId, last: 0, sent: null };
  try { el.setPointerCapture(e.pointerId); } catch { /* */ }
  el.classList.add('pb-drag'); volAt(e);
});
document.addEventListener('pointermove', e => { if (drag && e.pointerId === drag.id) volAt(e); });
const volEnd = e => { if (!drag || e.pointerId !== drag.id) return; volAt(e, true); drag.el.classList.remove('pb-drag'); drag = null; };
document.addEventListener('pointerup', volEnd);
document.addEventListener('pointercancel', e => { if (drag && e.pointerId === drag.id) { drag.el.classList.remove('pb-drag'); drag = null; } });
document.addEventListener('keydown', e => {
  const el = e.target.closest?.('#view .pb-vol'); if (!el || e.target !== el) return;
  const step = { ArrowUp: 5, ArrowRight: 5, ArrowDown: -5, ArrowLeft: -5, PageUp: 10, PageDown: -10 }[e.key]; if (step == null && e.key !== 'Home' && e.key !== 'End') return;
  e.preventDefault();
  const pct = e.key === 'Home' ? 0 : e.key === 'End' ? 100 : clamp(Math.round((volNow() || 0) + step), 0, 100);
  hold = { pct, until: Date.now() + 1500 }; el.setAttribute('aria-valuenow', pct); refresh(); volSend(pct, true);
});

Object.assign(A, {
  ccVol: v => req('shortcut.run', { id: v }).catch(() => {}),
  ccRun: v => {
    const t = ccTiles().find(x => x.id === v); if (!t) return;
    const tg = TOGGLE[v], flip = () => { const c = ccTiles().find(x => x.id === v); if (c) { c.state = { ...(c.state || {}), active: !c.state?.active }; changed(); } };
    const was = !!t.state?.active;
    if (tg) flip();
    req('shortcut.run', { id: v }).then(r => {
      if (r && r.open_url) window.open(r.open_url, '_blank', 'noopener');
      const msg = r?.message || (tg ? tg[was ? 2 : 1] : v.startsWith('volume.') ? '' : t.label);
      if (msg) toast(msg);
    }).catch(() => { if (tg) flip(); });
  }
});

page('shortcuts', {
  sub: () => esc(S.host || 'Your Mac'),
  sig: () => [S.conn === 'live', T.shortcuts?.status, T.shortcuts?.message, ccTiles().map(t => `${t.id}:${t.label}:${t.icon}:${t.state?.active ? 1 : 0}`).join()].join('|'),
  render: () => {
    const s = ok('shortcuts');
    if (!s) return `<div class="g">${card(note('shortcuts', 'Mute, volume, screenshots and more on the Mac.'))}</div>`;
    const tiles = ccTiles(), n = tiles.length;
    const cols = clamp(Math.ceil(n / 2), 4, 6), rows = Math.max(2, Math.ceil(n / cols)), empty = cols * rows - n;
    const sz = rows <= 2 ? 110 : rows === 3 ? 86 : 64;
    tiles.forEach((t, i) => { B['ccd' + i] = () => { const c = ccTiles()[i]; return c ? c.state?.detail || HINT[c.id] || '' : ''; }; });
    const tog = (t, i) => {
      const on = !!t.state?.active, l = esc(tLabel(t));
      return `<button class="tog ${on ? 'on' : ''}" data-act="ccRun" data-v="${esc(t.id)}" ${TOGGLE[t.id] ? `aria-pressed="${on}"` : ''} title="${l}"><span class="glass c lensed" style="width:${sz}px;height:${sz}px;font-size:${Math.round(sz * .3)}px">${icon(ticon(t))}</span>
        ${cols > 4 ? `<span class="pb-clamp" style="--n:2;white-space:normal;max-width:100%;min-height:2.5em;line-height:1.25;text-align:center;font-size:${sz >= 86 ? 14.5 : 13.5}px">${l}</span>` : `<span class="ell" style="max-width:100%;font-size:15px">${l}</span>`}<small class="ell" style="max-width:100%;min-height:1.3em" data-b="ccd${i}"></small></button>`;
    };
    const tip = empty >= 2 ? `<div style="grid-column:span ${empty};display:flex;align-items:center;justify-content:center;min-width:0">${card('<div class="lab">Tip</div><div style="margin-top:4px">These buttons act on the Mac running DeskPanel, even when this page is open on another screen.</div>', { st: 'max-width:360px' })}</div>` : '';
    const btnH = rows <= 2 ? 92 : 76;
    const vol = `<div class="glass vol pb-vol" data-p="ccVol" role="slider" tabindex="0" aria-label="Mac volume. Drag or use the arrow keys" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${volNow() ?? 0}"
        style="grid-column:${cols + 1};grid-row:1/${rows + 1};--r:44px"><div class="lvl" style="border-radius:0 0 44px 44px"></div>
      <button data-act="ccVol" data-v="volume.up" aria-label="Volume up" style="height:${btnH}px;font-size:30px">${icon('volUp')}</button><div style="flex:1"></div>
      <button data-act="ccVol" data-v="volume.down" aria-label="Volume down" style="height:${btnH}px;font-size:30px">${icon('volDown')}</button><span class="vl" style="font-size:22px" data-b="ccVol"></span></div>`;
    return `<div class="g cc" style="grid-template-columns:repeat(${cols},minmax(0,1fr)) 260px;grid-template-rows:repeat(${rows},minmax(0,1fr));padding:20px 40px">${tiles.map(tog).join('')}${tip}${vol}</div>`;
  }
});
})();
