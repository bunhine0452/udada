// 화면 크기 × 화면 × 키보드 레이아웃 감사.
// 실행: PW=/tmp/shtest/node_modules/playwright-core node tests/layout.test.js   (SHOTS=<dir> 면 스크린샷)
// 앱 모드(WKWebView 흉내: window.webkit 브리지 스텁 → html.ud-app)로 돌린다. 네이티브는 키보드가 올라오면
// 웹뷰 높이를 키보드 위까지 줄이므로, 키보드는 "뷰포트 높이 감소"로 흉내 낸다.
// 판정: 화면마다 ① 가로·세로 넘침 없음 ② 보이는 버튼은 44px 이상 ③ 보이는 요소가 화면 밖으로 안 나감
//       키보드 상태에선 ④ 포커스된 입력과 그 화면의 주 버튼이 보임.  끝 줄 "layout: N fail" 이 0 이어야 통과.
const path = require('path');
const { chromium } = require(process.env.PW || 'playwright-core');
const SIZES = [[360, 640, 'android-s'], [375, 667, 'se'], [375, 812, 'mini'], [390, 844, '14'], [402, 874, '17pro'], [440, 956, 'promax'], [412, 915, 'android-l']];
// ONLY=se,promax 로 일부 크기만 (스크린샷 볼 때)
const ONLY = (process.env.ONLY || '').split(',').filter(Boolean);
const KB = 0.44; // 키보드+제안 막대가 화면 높이에서 차지하는 비율(SE 291+44pt ≈ 50%, Pro Max ≈ 38%)
const url = (f, qs = '') => 'file://' + path.resolve(__dirname, '..', f) + qs;
let fails = 0; const log = [];
const fail = (where, msg) => { fails++; log.push(`FAIL ${where}: ${msg}`); };

async function audit(p, where, { focus, primary } = {}) {
  const r = await p.evaluate(({ focus, primary }) => {
    const W = innerWidth, H = innerHeight, out = [];
    const vis = e => { const s = getComputedStyle(e); if (s.display === 'none' || s.visibility === 'hidden' || +s.opacity === 0) return false; const b = e.getBoundingClientRect(); return b.width > 0 && b.height > 0 && !!e.offsetParent; };
    const se = document.scrollingElement;
    if (se.scrollHeight > H + 1) out.push(`세로 넘침 ${se.scrollHeight}>${H}`);
    if (se.scrollWidth > W + 1) out.push(`가로 넘침 ${se.scrollWidth}>${W}`);
    const sec = document.querySelector('section.on');
    const scope = sec ? [sec, ...document.querySelectorAll('.brand')] : [document.body];
    for (const root of scope) for (const e of root.querySelectorAll('button, input, textarea, .bigknob, .chips button')) {
      if (!vis(e)) continue;
      const b = e.getBoundingClientRect();
      // 스크롤 영역 안에 있는 건 화면 밖이어도 스크롤로 닿으니 넘침으로 치지 않는다
      let sc = e.parentElement, inScroll = false;
      while (sc && sc !== document.body) { const o = getComputedStyle(sc).overflowY; if ((o === 'auto' || o === 'scroll') && sc.scrollHeight > sc.clientHeight) { inScroll = true; break; } sc = sc.parentElement; }
      if (!inScroll && (b.bottom > H + 1 || b.right > W + 1 || b.top < -1 || b.left < -1)) out.push(`화면 밖 ${e.id || e.className || e.tagName} [${Math.round(b.left)},${Math.round(b.top)},${Math.round(b.right)},${Math.round(b.bottom)}]`);
      const isTarget = e.matches('button') && !e.closest('.chips');
      if (isTarget && (b.height < 43.5 || b.width < 43.5)) out.push(`작은 터치 ${e.id || e.textContent.trim().slice(0, 8)} ${Math.round(b.width)}x${Math.round(b.height)}`);
      if (e.matches('.chips button') && b.height < 31.5) out.push(`작은 칩 ${e.textContent.trim()} ${Math.round(b.height)}`);
    }
    for (const sel of [focus, primary].filter(Boolean)) {
      const e = document.querySelector(sel); if (!e) { out.push(`없음 ${sel}`); continue; }
      const b = e.getBoundingClientRect();
      if (b.bottom > H + 1 || b.top < 0) out.push(`키보드 위에 안 보임 ${sel} bottom ${Math.round(b.bottom)} > ${H}`);
    }
    for (const e of document.querySelectorAll('input, textarea')) { if (vis(e) && parseFloat(getComputedStyle(e).fontSize) < 16) out.push(`입력 글자 16px 미만(${getComputedStyle(e).fontSize}) → iOS 자동 확대 ${e.id}`); }
    return out;
  }, { focus, primary });
  r.forEach(m => fail(where, m));
}

(async () => {
  const b = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const errs = [];
  for (const [w, h, name] of SIZES.filter(s => !ONLY.length || ONLY.includes(s[2]))) {
    const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    await ctx.addInitScript(() => { window.webkit = { messageHandlers: { ud: { postMessage() {} } } }; });
    const p = await ctx.newPage();
    p.on('pageerror', e => errs.push(`${name}: ${e.message}`));
    const shot = async n => process.env.SHOTS && p.screenshot({ path: path.join(process.env.SHOTS, `${name}-${n}.png`) });
    const kb = async on => p.setViewportSize({ width: w, height: on ? Math.round(h * (1 - KB)) : h });
    const W = async () => p.waitForTimeout(350);

    // ── refresh
    await p.goto(url('refresh.html', '?speed=400&hour=10')); await p.evaluate(() => localStorage.clear()); await p.reload(); await W();
    await audit(p, `${name}/r-intro`); await shot('r0-intro');
    await p.tap('#kIntro'); await W();
    await audit(p, `${name}/r-state`); await shot('r1-state');
    await p.tap('[data-s="foggy"]'); await W(); await audit(p, `${name}/r-dial`); await shot('r2-dial');
    await p.tap('[data-m="10"]'); await p.waitForTimeout(1300); await audit(p, `${name}/r-rx`); await shot('r3-rx');
    await p.focus('#bmIn'); await kb(true); await W(); await audit(p, `${name}/r-rx+kb`, { focus: '#bmIn', primary: '#kStart' }); await shot('r3-rx-kb');
    await p.fill('#bmIn', '레포트 3장 첫 문장'); await p.evaluate(() => document.activeElement.blur()); await kb(false); await W();
    await p.tap('#kStart'); await W(); await audit(p, `${name}/r-run`); await shot('r4-run');
    await p.waitForTimeout(1700); await audit(p, `${name}/r-after`); await shot('r5-after');
    await p.tap('#kSave'); await W(); await audit(p, `${name}/r-res`); await shot('r6-res');

    // ── cooler
    await p.goto(url('cooler.html')); await W();
    await audit(p, `${name}/c-temp`); await shot('c1-temp');
    await p.tap('#kTempGo'); await W();
    await p.focus('#dumpTxt'); await kb(true); await p.fill('#dumpTxt', '레포트 금요일까지\n엄마한테 전화\n방 정리\n월세 오르면 어떡하지'); await W();
    await audit(p, `${name}/c-dump+kb`, { focus: '#dumpTxt', primary: '#kSort' }); await shot('c2-dump-kb');
    await p.evaluate(() => document.activeElement.blur()); await kb(false); await W();
    await audit(p, `${name}/c-dump`); await shot('c2-dump');
    await p.tap('#kSort'); await W(); await audit(p, `${name}/c-sort`); await shot('c3-sort');
    await p.tap('[data-b="date"]'); await W(); await audit(p, `${name}/c-sort-date`); await shot('c3-sort-date');
    for (let i = 0; i < 4; i++) { await p.tap('#kSug'); await p.waitForTimeout(60); }
    await p.waitForTimeout(500); await audit(p, `${name}/c-breath`); await shot('c4-breath');
    await p.tap('#kSkip'); await p.waitForTimeout(1500); await audit(p, `${name}/c-one`); await shot('c5-one');
    await p.tap('#kDone'); await W(); await audit(p, `${name}/c-after`);
    await p.tap('#kTempGo'); await W(); await audit(p, `${name}/c-res`); await shot('c6-res');
    await p.tap('#kResDrawer'); await W(); await audit(p, `${name}/c-drawer`); await shot('c7-drawer');
    await ctx.close();
  }
  log.forEach(l => console.log(l));
  console.log('errors:', errs.length ? errs : 'none');
  console.log(`layout: ${fails} fail`);
  await b.close();
  process.exit(fails || errs.length ? 1 : 0);
})();
