/* Overview (every widget on one screen) and System (Laptop / Internet), concept 16 desktop. */
(() => {
'use strict';
const { T, S, B, PB, A, charts, page, card, ring, bar, slider, gbtn, seg, pill, icon, esc, ok, note, media, artFor, linePath, size, clamp,
  dur, ago, timeStr, hourStr, bytes, rate, mbps, todayEvents, nextEvent, WX, TM, tMode, req, toast, render, refresh } = DP;

/* ---------- Shared bits ---------- */
const sys = () => ok('system');
const hist = k => (sys()?.history?.[k] || []);
charts.cpugpu = el => {
  const [w, h] = size(el), c = hist('cpu'), g = hist('gpu').filter(v => v != null);
  if (!c.length) return '';
  const dc = linePath(c, w, h, 0, 100, 4), dg = g.length > 1 ? linePath(hist('gpu'), w, h, 0, 100, 4) : '';
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" role="img" aria-label="Processor and graphics load over the last minute"><path d="${dc} V${h} H0z" fill="rgba(255,255,255,.14)"/>${dg ? `<path d="${dg}" fill="none" stroke="#9CF3FF" stroke-width="2.5" stroke-linecap="round" opacity=".9"/>` : ''}<path d="${dc}" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/></svg>`;
};
/* Laptop traffic, last minute: download filled, upload line (shared scale). */
charts.traffic = el => {
  const [w, h] = size(el), d = hist('down'), u = hist('up');
  if (d.length < 2) return '';
  const hi = Math.max(64e3, ...d, ...u) * 1.15, dd = linePath(d, w, h, 0, hi, 3), du = linePath(u, w, h, 0, hi, 3);
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" role="img" aria-label="Laptop download and upload over the last minute"><path d="${dd} V${h} H0z" fill="rgba(156,243,255,.2)"/><path d="${dd}" fill="none" stroke="#9CF3FF" stroke-width="2.5" stroke-linecap="round"/><path d="${du}" fill="none" stroke="#FFD36E" stroke-width="2" stroke-linecap="round"/></svg>`;
};
charts.lat = el => {
  const [w, h] = size(el), v = ok('network')?.latency?.history?.ms || [];
  if (v.length < 2) return '';
  const vals = v.filter(x => x != null), hi = Math.max(50, ...vals) * 1.1, d = linePath(v.map(x => x ?? hi), w, h, 0, hi, 3);
  const lost = v.map((x, i) => x == null ? `<rect x="${(i / (v.length - 1) * w - 1.5).toFixed(1)}" y="0" width="3" height="${h}" fill="#FF6B6B" opacity=".55"/>` : '').join('');
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" role="img" aria-label="Latency over the last two minutes">${lost}<path d="${d} V${h} H0z" fill="rgba(255,255,255,.14)"/><path d="${d}" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/></svg>`;
};
/* GitHub contribution calendar (53 weeks, Sunday-first like GitHub). */
charts.heat = el => {
  const g = ok('github'); const weeks = g?.year?.weeks || []; if (!weeks.length) return '';
  const w = el.clientWidth, n = weeks.length, cw = w / n, cs = cw - 3, top = 16, H = top + 7 * cw;
  const op = [.1, .3, .5, .75, 1];
  let s = '', lastM = -1;
  weeks.forEach((col, x) => {
    const first = col.find(Boolean); if (first) { const m = new Date(first.date + 'T12:00').getMonth(); if (m !== lastM && x > 0 && x < n - 2) s += `<text x="${(x * cw).toFixed(1)}" y="11" font-size="12" fill="rgba(255,255,255,.7)">${DP.MON3[m]}</text>`; lastM = m; }
    col.forEach((d, y) => { if (!d) return; s += `<rect x="${(x * cw).toFixed(1)}" y="${(top + y * cw).toFixed(1)}" width="${cs.toFixed(1)}" height="${cs.toFixed(1)}" rx="${(cs / 2.6).toFixed(1)}" fill="#fff" fill-opacity="${op[d.level ?? 0]}"><title>${d.count} on ${d.date}</title></rect>`; });
  });
  return `<svg viewBox="0 0 ${w} ${H}" style="width:100%;height:auto;display:block" role="img" aria-label="Contribution calendar for the last year">${s}</svg>`;
};
Object.assign(B, {
  stDl: () => { const st = ok('network')?.speedtest; if (!st) return '–'; if (st.state === 'running') return mbps(st.progress?.down_bps); return st.last ? mbps(st.last.down_bps) : '–'; },
  stUl: () => { const st = ok('network')?.speedtest; if (!st) return '–'; if (st.state === 'running') return mbps(st.progress?.up_bps); return st.last ? mbps(st.last.up_bps) : '–'; },
  stPing: () => ok('network')?.speedtest?.last?.ping_ms ?? '–',
  stWhen: () => { const st = ok('network')?.speedtest; if (!st) return ''; if (st.state === 'running') return `Testing ${st.progress?.phase || ''}…`; return st.last ? 'Tested ' + ago(st.last.at) : 'No test yet'; },
  netUp: () => { const n = ok('network'); return n && n.online && n.online_since ? 'Online for ' + dur((Date.now() - n.online_since) / 60000) : ''; },
  hsNow: () => { const h = ok('hotspot'); return h ? `${rate(h.rx_bps / 8).v} ${rate(h.rx_bps / 8).u} down` : ''; }
});
PB.st = () => (ok('network')?.speedtest?.progress?.pct || 0) / 100;
PB.hsScore = () => (ok('hotspot')?.score || 0) / 100;

const GRADE = { excellent: '#8CFFB0', good: '#9CF3FF', fair: '#FFD36E', poor: '#FF8A8A' };
const tile = id => (ok('shortcuts')?.tiles || []).find(t => t.id === id);
const TICON = { mic: ['mic', 'micOff'], speaker: ['speaker', 'speakerOff'], vol_down: ['volDown'], vol_up: ['volUp'], screenshot: ['shot'], terminal: ['terminal'], folder: ['folder'], lock: ['lock'], play: ['play'] };
const ticon = t => { const p = TICON[t.icon] || [t.icon]; return t.state?.active && p[1] ? p[1] : p[0]; };

/* ---------- Overview ---------- */
page('home', {
  sub: () => '<span data-b="date"></span>',
  sig: () => {
    const m = media(), n = nextEvent(), s = sys(), h = ok('hotspot'), sl = ok('slack'), sc = ok('shortcuts');
    return [S.conn === 'live', !!s, s?.gpu?.available, m?.art_id, m?.title, m?.playing, T['media.art']?.art_id, !!T['media.art']?.b64, n?.id, todayEvents().map(e => e.id).join(), T.calendar?.status,
      T.claude?.status, !!ok('claude')?.limits?.five_hour, ok('claude')?.limits?.five_hour?.used_pct, ok('claude')?.limits?.seven_day?.used_pct, ok('claude')?.today?.tokens,
      WX.data?.updated, WX.place?.name, h?.updated, T.hotspot?.status, T.github?.status, ok('github')?.fetched_at, sl?.unread, T.shortcuts?.status,
      (sc?.tiles || []).map(t => t.id + (t.state?.active ? 1 : 0)).join(), Math.floor(Date.now() / 60000)].join('|');
  },
  render: () => {
    const n = nextEvent(), m = media(), s = sys(), sl = ok('slack'), now = new Date();
    const later = todayEvents().filter(e => e !== n && e.end > Date.now() - 45 * 60e3).slice(0, 4);
    const clockCard = card(`<div class="row" style="align-items:flex-start"><div><div class="big rnd" style="font-size:112px"><span data-b="clock"></span><small data-b="ampm"></small></div><div class="mu" style="font-size:16px;margin-top:6px" data-b="date"></div></div><span class="sp"></span>
        ${n ? `<div style="text-align:right;min-width:0;max-width:52%"><div class="lab">Next up</div><div class="ell" style="font-size:22px;font-weight:700;margin-top:2px">${esc(n.title)}</div><div class="rnd" style="font-size:40px;margin-top:4px" data-b="nextIn"></div><div class="mu ell">${timeStr(new Date(n.start))}${n.location ? ', ' + esc(n.location) : ''}</div></div>`
          : `<div style="text-align:right"><div class="lab">Calendar</div><div style="font-size:20px;font-weight:700;margin-top:4px">${ok('calendar') ? 'Nothing else today' : 'No calendar linked'}</div></div>`}</div>
        <div class="row" style="margin-top:auto;gap:8px;flex-wrap:wrap">${later.map(e => pill(`<i style="width:8px;height:8px;border-radius:50%;background:${esc(e.color || '#5AA9FF')}"></i><span>${timeStr(new Date(e.start))} ${esc(e.title)}</span>`, `height:30px;font-size:13px;${e.end < Date.now() ? 'opacity:.55' : ''}`)).join('')}
          ${sl && sl.unread ? `<span class="glass pill" role="button" tabindex="0" data-act="go" data-v="slack" style="height:30px;font-size:13px">${icon('slack')}<span>${sl.unread} unread on Slack</span></span>` : ''}</div>`, { st: 'grid-column:1/3', go: 'calendar' });

    const w = WX.data;
    const wxCard = card(w ? `<div class="lab">${esc(WX.place.name)}</div><div class="row" style="margin-top:4px"><span class="big rnd" style="font-size:64px">${w.temp}°</span><div style="margin-left:6px"><div style="font-size:30px">${icon(w.icon)}</div><div style="font-weight:650">${esc(w.cond)}</div></div></div>
        <div class="row" style="justify-content:space-between;margin-top:auto">${w.hours.filter((_, i) => i % 2 === 0).slice(0, 6).map((x, k) => `<div style="text-align:center;font-size:12px"><div class="mu">${k ? hourStr(x.t).replace(':00', '') : 'Now'}</div><div style="font-size:17px;width:17px;margin:4px auto">${icon(x.icon)}</div><b>${x.temp}°</b></div>`).join('')}</div>`
      : `<div class="lab">Weather</div><div class="note"><b>${WX.place ? 'Loading the forecast…' : 'Pick your city'}</b><span>${WX.place ? esc(WX.err || '') : 'Open Weather to choose where you are.'}</span></div>`, { go: 'weather' });

    const c = ok('claude'), f = c?.limits?.five_hour, wk = c?.limits?.seven_day;
    const clCard = card(c ? `<div class="lab">Claude</div><div class="row" style="flex:1;gap:16px">${ring('five', `<div class="rnd" style="font-size:28px">${f && !f.expired ? Math.round(f.used_pct) + '%' : '–'}</div><div class="mu" style="font-size:11px">5-hour</div>`, 116)}<div style="flex:1;min-width:0"><div class="mu" style="font-size:12.5px">Resets in</div><b data-b="fiveReset"></b><div class="mu" style="font-size:12.5px;margin-top:10px">Weekly ${wk && !wk.expired ? Math.round(wk.used_pct) + '%' : '–'}</div>${bar('week', '#FFD36E', 'margin-top:4px')}<div class="mu" style="font-size:12.5px;margin-top:10px">${c.today ? DP.compact(c.today.tokens) + ' tokens today' : ''}</div></div></div>`
      : `<div class="lab">Claude</div>${note('claude', 'Plan limits and token use from Claude Code.')}`, { go: 'claude' });

    const muCard = card(m ? `<div class="row" style="gap:22px;flex:1;min-height:0"><div style="height:100%;max-height:200px;aspect-ratio:1;border-radius:20px;overflow:hidden;flex:none;box-shadow:0 14px 30px rgba(0,0,0,.3)">${artFor(m)}</div>
        <div style="flex:1;min-width:0"><div class="lab">Now playing${m.source ? ', ' + esc(m.source) : ''}</div><div class="ell" style="font-size:24px;font-weight:750;margin-top:2px" data-b="trTitle"></div><div class="mu ell" data-b="trArtist"></div>${slider('music', 'seek', 'margin-top:14px')}<div class="row mu" style="font-size:12px"><span data-b="trPos"></span><span class="sp"></span><span data-b="trLeft"></span></div>
        <div class="row" style="gap:10px;margin-top:8px">${gbtn(icon('prev'), 'prev', '', 'circ', 'aria-label="Previous track"')}${gbtn(icon(m.playing ? 'pause' : 'play'), 'play', '', 'circ', `aria-label="${m.playing ? 'Pause' : 'Play'}" style="width:62px;height:62px"`)}${gbtn(icon('next'), 'next', '', 'circ', 'aria-label="Next track"')}</div></div></div>`
      : `<div class="lab">Music</div>${ok('media') ? '<div class="note"><b>Nothing playing</b><span>Play something in Spotify or Apple Music on the Mac.</span></div>' : note('media', 'What’s playing on the laptop.')}`, { st: 'grid-column:1/3', go: 'music' });

    const g = s?.gpu, rings = s ? [['cpu', 'cpu', 'CPU', '#fff'], ...(g?.available ? [['gpu', 'gpu', 'GPU', '#9CF3FF']] : []), ['ram', 'ramPct', 'RAM', '#fff'], ...(g?.available && g.vram_total ? [['vram', 'vramPct', g.vram_label || 'VRAM', '#9CF3FF']] : [])] : [];
    const pcCard = card(s ? `<div class="row"><span class="lab">Laptop</span><span class="sp"></span><span class="mu" style="font-size:12.5px"><span data-b="down"></span> <span data-b="downU"></span> down, <span data-b="up"></span> <span data-b="upU"></span> up</span></div>
        <div class="row" style="justify-content:space-around;margin-top:8px">${rings.map(([k, b2, l, col]) => `<div style="text-align:center">${ring(k, `<div class="rnd" style="font-size:18px"><span data-b="${b2}"></span>%</div>`, 74, { sw: 10, c: col })}<div class="mu" style="font-size:12px;margin-top:4px">${esc(l)}${k === 'cpu' && s.cpu?.temp_c != null ? ' <span data-b="cpuTemp"></span>' : ''}</div></div>`).join('')}</div>
        <div class="chart" data-c="cpugpu" style="margin-top:10px"></div>` : `<div class="lab">Laptop</div>${note('system', 'Processor, memory and network.')}`, { st: 'grid-column:3/5', go: 'system' });

    const h = ok('hotspot');
    const hsCard = card(h ? `<div class="row"><span class="lab ell">${esc(h.name || 'Hotspot')}</span><span class="sp"></span><span class="dot" style="${h.online && h.internet !== false ? '' : 'background:#FF6B6B;box-shadow:0 0 8px #FF6B6B'}"></span></div>
        <div class="row" style="flex:1;gap:16px">${ring('hsScore', `<div class="rnd" style="font-size:26px">${h.score ?? '–'}</div><div class="mu" style="font-size:11px">signal</div>`, 104, { c: GRADE[h.grade] || '#fff' })}
        <div style="min-width:0"><b style="text-transform:capitalize">${!h.online ? 'Offline' : h.internet === false ? 'No internet' : esc(h.grade || 'Online')}</b><div class="mu ell" style="font-size:12.5px">${esc([h.operator, h.net_type].filter(Boolean).join(', '))}</div>
        <div class="mu" style="font-size:12.5px;margin-top:8px">${h.today_used != null ? bytes(h.today_used) + ' today' : ''}</div><div class="mu" style="font-size:12.5px">${h.battery_pct != null ? 'Battery ' + h.battery_pct + '%' : ''}</div></div></div>`
      : `<div class="lab">Hotspot</div>${note('hotspot', 'Your roof phone’s signal and data.')}`, { go: 'hotspot' });

    const gh = ok('github');
    const ghCard = card(gh ? `<div class="row"><span class="lab">GitHub</span><span class="sp"></span><b>${gh.streak?.current ?? 0}-day streak</b><span class="mu" style="font-size:12.5px;margin-left:10px">${gh.week?.this_total ?? 0} this week</span></div><div data-c="heat" style="margin-top:auto"></div>`
      : `<div class="lab">GitHub</div>${note('github', 'Your contributions over the last year.')}`, { st: 'grid-column:2/4', go: 'github' });

    const ids = ['mic.toggle', 'sound.toggle', 'screenshot', 'volume.down', 'volume.up', 'lock'].map(tile).filter(Boolean);
    const ccCard = card(ids.length ? `<div class="lab">Controls</div><div style="flex:1;display:grid;grid-template-columns:repeat(3,1fr);gap:4px;align-items:center;margin-top:4px">${ids.map(t => `<button class="tog ${t.state?.active ? 'on' : ''}" data-act="sc" data-v="${esc(t.id)}" aria-pressed="${!!t.state?.active}" aria-label="${esc(t.label)}" title="${esc(t.label)}"><span class="glass c lensed" style="width:50px;height:50px;font-size:20px">${icon(ticon(t))}</span></button>`).join('')}</div>`
      : `<div class="lab">Controls</div>${note('shortcuts', 'Mute, volume and more on the laptop.')}`, { go: 'shortcuts' });

    return `<div class="g" style="grid-template-columns:repeat(4,1fr);grid-template-rows:1fr 1fr 1fr">${clockCard}${wxCard}${clCard}${muCard}${pcCard}${hsCard}${ghCard}${ccCard}</div>`;
  }
});

/* ---------- System ---------- */
A.speed = () => {
  const st = ok('network')?.speedtest; if (st?.state === 'running') return;
  if (st) { st.state = 'running'; st.progress = { phase: 'starting', pct: 0 }; }
  render();
  req('speedtest.run', {}, { timeout: 95000 }).then(r => {
    const l = r?.last || r; if (l && l.down_bps) toast(`Speed test finished: ${mbps(l.down_bps)} down, ${mbps(l.up_bps)} up`);
  }).catch(() => {});
};

page('system', {
  sub: () => `${esc(S.host || 'Laptop')}, live`,
  sig: () => { const s = sys(), n = ok('network'); return [S.sysTab, !!s, s?.gpu?.available, s?.cpu?.temp_c != null, s?.cpu?.model, T.system?.status, T.network?.status, n?.online, n?.speedtest?.state, n?.speedtest?.last?.at, Math.floor(Date.now() / 60000)].join('|'); },
  render: () => {
    const sg = seg([['pc', 'Laptop'], ['net', 'Internet']], S.sysTab, 'tab');
    if (S.sysTab === 'pc') {
      const s = sys();
      if (!s) return `<div class="g" style="grid-template-rows:auto 1fr"><div>${sg}</div>${card(note('system', 'Processor, memory and network.'))}</div>`;
      const g = s.gpu || {}, cpuSub = [esc(s.cpu?.model || ''), s.cpu?.cores ? `${s.cpu.cores} cores${s.cpu.threads && s.cpu.threads !== s.cpu.cores ? `, ${s.cpu.threads} threads` : ''}` : ''].filter(Boolean).join('<br>');
      const r = (k, b2, l, sub, c, extra = '') => card(`<div class="row" style="gap:18px;flex:1">${ring(k, `<div class="rnd" style="font-size:30px"><span data-b="${b2}"></span>%</div>`, 120, { c })}<div style="min-width:0"><div style="font-size:18px;font-weight:700">${l}</div><div class="mu">${sub}</div>${extra}</div></div>`);
      const temp = s.cpu?.temp_c != null ? `<div class="row" style="gap:6px;margin-top:8px;font-weight:650">${icon('thermo')}<span>Temp <span data-b="cpuTemp"></span></span></div>` : '';
      const gpuCard = g.available ? r('gpu', 'gpu', 'Graphics', `${esc(g.model || 'GPU')}${g.temp_c != null ? '<br><span data-b="gpuTemp"></span>' : ''}`, '#9CF3FF') : card(`<div style="font-size:18px;font-weight:700">Graphics</div><div class="note"><b>N/A</b><span>No graphics load reading on this laptop.</span></div>`);
      const vramCard = g.available && g.vram_total ? r('vram', 'vramPct', g.vram_label === 'GPU MEM' ? 'GPU memory' : 'Video memory', `<span data-b="vram"></span> of ${(g.vram_total / 1e9).toFixed(1)} GB`, '#9CF3FF')
        : card(`<div style="font-size:18px;font-weight:700">Disk</div><div class="big rnd" style="font-size:40px;margin-top:auto">${Math.round(s.disk?.pct || 0)}<small>% used</small></div>${bar('disk', '#fff', 'margin-top:10px')}`);
      return `<div class="g" style="grid-template-columns:repeat(4,1fr);grid-template-rows:auto auto 1fr"><div style="grid-column:1/-1">${sg}</div>
        ${r('cpu', 'cpu', 'Processor', cpuSub, '#fff', temp)}${gpuCard}${r('ram', 'ramPct', 'Memory', `<span data-b="ram"></span> of ${((s.ram?.total || 0) / 1e9).toFixed(0)} GB`, '#fff')}${vramCard}
        ${card(`<div class="row"><span class="lab">Last minute</span><span class="sp"></span><span class="row mu" style="gap:16px;font-size:13px"><span class="row" style="gap:6px"><i style="width:14px;height:3px;border-radius:2px;background:#fff"></i>Processor</span>${g.available ? '<span class="row" style="gap:6px"><i style="width:14px;height:3px;border-radius:2px;background:#9CF3FF"></i>Graphics</span>' : ''}</span></div><div class="chart" data-c="cpugpu" style="margin-top:10px"></div>`, { st: 'grid-column:1/4' })}
        ${card(`<div class="lab">Network and disk</div><div class="big rnd" style="font-size:40px;margin-top:10px"><span data-b="down"></span><small><span data-b="downU"></span> down</small></div><div class="big rnd" style="font-size:40px;margin-top:8px"><span data-b="up"></span><small><span data-b="upU"></span> up</small></div><div class="lab" style="margin-top:auto">Disk</div>${bar('disk', '#fff', 'margin-top:6px')}<div class="mu" style="font-size:12.5px;margin-top:4px">${Math.round(s.disk?.pct || 0)}% used</div>`)}</div>`;
    }
    const n = ok('network'), s = sys();
    if (!n) return `<div class="g" style="grid-template-rows:auto 1fr"><div>${sg}</div>${card(note('network', 'Latency, data use and speed tests.'))}</div>`;
    const st = n.speedtest || {}, running = st.state === 'running', l = n.latency || {};
    return `<div class="g" style="grid-template-columns:2fr 1fr 1fr;grid-template-rows:auto 1fr auto"><div style="grid-column:1/-1">${sg}</div>
      ${card(`<div class="row" style="align-items:baseline"><span class="lab">Latency, last 2 minutes</span><span class="sp"></span><span class="big rnd" style="font-size:54px"><span data-b="latency"></span><small>ms</small></span></div><div class="chart" data-c="lat" style="margin-top:10px"></div><div class="mu">Jitter <span data-b="jitter"></span> ms, ${l.loss_pct != null ? (+l.loss_pct).toFixed(l.loss_pct % 1 ? 1 : 0) : 0}% packet loss${l.target ? `, to ${esc(l.target)}` : ''}</div>`, { st: 'grid-row:2/4' })}
      ${card(`<div class="lab">Connection</div><div class="row" style="margin-top:10px"><span class="dot" style="${n.online ? '' : 'background:#FF6B6B;box-shadow:0 0 8px #FF6B6B'}"></span><b style="font-size:26px">${n.online ? 'Online' : 'Offline'}</b></div><div class="mu" style="margin-top:10px;line-height:1.6"><span data-b="netUp"></span><br>Last drop ${n.last_drop ? ago(n.last_drop) : 'none seen'}</div>
        <div class="mu" style="margin-top:auto;line-height:1.6">Data used: <b style="color:#fff">${bytes(n.usage?.today)}</b> today, ${bytes(n.usage?.month, 0)} this month</div>`)}
      ${card(`<div class="lab">Laptop traffic now</div><div class="row" style="gap:18px;margin-top:10px;align-items:baseline"><span class="big rnd" style="font-size:38px;color:#9CF3FF"><span data-b="down"></span><small><span data-b="downU"></span> down</small></span></div><div class="big rnd" style="font-size:30px;margin-top:6px;color:#FFD36E"><span data-b="up"></span><small><span data-b="upU"></span> up</small></div><div class="chart" data-c="traffic" style="margin-top:10px;min-height:50px"></div>`)}
      ${card(`<div class="row" style="gap:30px"><div style="min-width:0;flex:1"><div class="lab">Speed test</div><div class="row" style="align-items:baseline;gap:24px;margin-top:6px"><span class="big rnd" style="font-size:52px"><span data-b="stDl"></span><small>Mbps down</small></span><span class="big rnd" style="font-size:52px"><span data-b="stUl"></span><small>Mbps up</small></span></div><div class="mu" style="margin-top:6px"><span data-b="stWhen"></span>${st.last?.ping_ms != null ? ', ping <span data-b="stPing"></span> ms' : ''}.</div>${running ? bar('st', '#fff', 'margin-top:8px') : ''}</div>${gbtn(running ? 'Testing…' : 'Run test', 'speed', '', 'solid', `${running || S.conn !== 'live' ? 'disabled' : ''} style="height:52px;padding:0 28px;font-size:16px"`)}</div>`, { st: 'grid-column:2/4' })}</div>`;
  }
});
})();
