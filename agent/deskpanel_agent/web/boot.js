/* Start the desk page. `#p=<page>` (handy for links and screenshots) opens that page. */
(() => {
  const m = /[#&]p=([a-z]+)/.exec(DP.HASH);
  if (m && DP.pages[m[1]]) DP.S.page = m[1];
  if (/[#&]t=net/.test(DP.HASH)) DP.S.sysTab = 'net';
  DP.boot();
})();
