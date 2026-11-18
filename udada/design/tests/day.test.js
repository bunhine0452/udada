// 하루 한 장(day.html) 동작 + 레이아웃 검사.
// 실행: PW=<playwright-core 경로> node tests/day.test.js   (SHOTS=<dir> 면 스크린샷)
// 판정: 끝 줄 "day: N fail" 이 0 이어야 통과.
const fs = require('fs'), os = require('os'), path = require('path');
const { chromium } = require(process.env.PW || 'playwright-core');
const SIZES = [[360, 640, 'android-s'], [375, 667, 'se'], [390, 844, '14'], [440, 956, 'promax']];
const KB = 0.44;
// 게시 때 붙는 뼈대를 흉내 낸다 (day.html 은 본문 조각이다)
const src = fs.readFileSync(path.resolve(__dirname, '..', 'day.html'), 'utf8');
const tmp = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'day-')), 'day.html');
fs.writeFileSync(tmp, `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light}body{margin:0}[hidden]{display:none!important}</style></head><body>${src}</body></html>`);
let fails = 0; const log = [];
const fail = (w, m) => { fails++; log.push(`FAIL ${w}: ${m}`); };
const ok = (w, c, m) => { if (!c) fail(w, m); };

async function audit(p, where, must = []) {
  const r = await p.evaluate(must => {
    const W = innerWidth, H = innerHeight, out = [];
    const vis = e => { const s = getComputedStyle(e), b = e.getBoundingClientRect(); return s.display !== 'none' && s.visibility !== 'hidden' && b.width > 0 && b.height > 0 && !e.closest('[hidden]'); };
    if (document.scrollingElement.scrollWidth > W + 1) out.push('가로 넘침');
    if (document.scrollingElement.scrollHeight > H + 1) out.push('세로 넘침');
    const top = document.querySelector('#layer .full, #layer .over') || document.body;
    for (const e of top.querySelectorAll('button, input')) {
      if (!vis(e)) continue; const b = e.getBoundingClientRect();
      let sc = e.parentElement, inScroll = false;
      while (sc && sc !== document.body) { const o = getComputedStyle(sc).overflowY; if ((o === 'auto' || o === 'scroll') && sc.scrollHeight > sc.clientHeight) { inScroll = true; break; } sc = sc.parentElement; }
      if (b.right > W + 1 || b.left < -1) out.push(`가로 밖 ${e.id || e.textContent.trim().slice(0, 8)}`);
      if (!inScroll && (b.bottom > H + 1 || b.top < -1)) out.push(`세로 밖 ${e.id || e.textContent.trim().slice(0, 8)} ${Math.round(b.bottom)}>${H}`);
      if (b.height < 43.5 || b.width < 43.5) out.push(`작은 터치 ${e.id || e.textContent.trim().slice(0, 8)} ${Math.round(b.width)}x${Math.round(b.height)}`);
      if (e.matches('input') && parseFloat(getComputedStyle(e).fontSize) < 16) out.push(`입력 16px 미만 ${e.id}`);
    }
    for (const sel of must) { const e = document.querySelector(sel); if (!e || !vis(e)) { out.push(`안 보임 ${sel}`); continue; } const b = e.getBoundingClientRect(); if (b.bottom > H + 1 || b.top < 0) out.push(`화면 밖 ${sel}`); }
    return out;
  }, must);
  r.forEach(m => fail(where, m));
}

(async () => {
  const b = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const errs = [];
  for (const scheme of ['light', 'dark']) for (const [w, h, name] of SIZES) {
    if (scheme === 'dark' && name !== '14') continue;
    const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, colorScheme: scheme });
    await ctx.addInitScript(() => { window.__now = '2026-11-14T14:20:00'; window.__speed = 600; });
    const p = await ctx.newPage(); const N = `${name}${scheme === 'dark' ? '-dark' : ''}`;
    p.on('pageerror', e => errs.push(`${N}: ${e.message}`));
    const shot = async n => process.env.SHOTS && p.screenshot({ path: path.join(process.env.SHOTS, `${N}-${n}.png`) });
    const txt = s => p.locator(s).innerText();
    await p.goto('file://' + tmp); await p.waitForTimeout(500);

    // 1 첫 화면: 예시가 차 있고, 지금 줄이 다음 일정까지 남은 시간을 말한다
    await audit(p, `${N} 첫 화면`, ['#in', '#cool']); await shot('1-home');
    ok(`${N} 지금`, (await txt('#now')).includes('치과까지 40분'), await txt('#now'));
    ok(`${N} 지금 제안`, (await txt('#now')).includes('메일 답장'), '들어갈 일 제안 없음');
    ok(`${N} 지난 일 옮김`, (await txt('[data-part=pm]')).includes('메일 답장'), '아침에 못 한 일이 낮으로 안 옴');

    // 2 한 줄로 일정 넣기 (키보드 올라온 상태)
    await p.locator('#in').focus(); await p.setViewportSize({ width: w, height: Math.round(h * (1 - KB)) });
    await p.locator('#in').fill('내일 오후 3시 반 미용실'); await p.waitForTimeout(100);
    ok(`${N} 미리보기`, (await txt('#preview')).includes('내일 15:30 일정'), await txt('#preview'));
    await audit(p, `${N} 적는 중`, ['#in', '#add']); await shot('2-compose');
    await p.locator('#add').click();
    // 3 할 일 넣기: 시각이 없으면 지금 시간대로, 칩으로 길이만
    await p.locator('#in').fill('세탁소 15분'); await p.locator('#add').click();
    await p.locator('#in').fill('운동'); await p.locator('[data-g=part][data-v=ev]').click(); await p.locator('#add').click();
    await p.locator('#in').blur(); await p.setViewportSize({ width: w, height: h }); await p.waitForTimeout(250);
    ok(`${N} 할 일 낮`, (await txt('[data-part=pm]')).includes('세탁소'), '세탁소가 낮에 없음');
    ok(`${N} 칩 저녁`, (await txt('[data-part=ev]')).includes('운동'), '운동이 저녁에 없음');
    const st = await p.evaluate(() => window.__day.S().items.find(x => x.t === '미용실'));
    ok(`${N} 일정 저장`, st && st.time === 930 && st.date === '2026-11-15', JSON.stringify(st));

    // 4 끝냄 → 줄 긋기
    await p.locator('.todo:has-text("세탁소") .chk').click();
    ok(`${N} 끝냄`, await p.locator('.todo.done:has-text("세탁소")').count() === 1, '끝냄 표시 없음');

    // 5 고치기 시트: 내일로 옮기고 되돌리기 없이 닫기
    await p.locator('.todo:has-text("택배") .body').click(); await p.waitForTimeout(250);
    await audit(p, `${N} 고치기`, ['#e-t', '#e-ok']); await shot('3-edit');
    await p.locator('#layer [data-g=date]:has-text("내일")').click(); await p.locator('#e-ok').click();
    ok(`${N} 옮김`, !(await txt('#main')).includes('택배'), '택배가 오늘에 남음');

    // 6 식히기: 고르면 바로 시작 → 끝 → 돌아오면 먼저 할 일
    await p.locator('#cool').click(); await p.waitForTimeout(250);
    await audit(p, `${N} 식히기 고르기`); await shot('4-cool');
    await p.locator('[data-act=rest][data-v=breath]').click(); await p.waitForTimeout(60); await shot('5-run');
    await audit(p, `${N} 쉬는 중`);
    await p.waitForSelector('#r-done', { timeout: 3000 }).catch(() => fail(`${N} 식히기`, '끝 화면 안 나옴'));
    await shot('6-back'); await p.locator('#layer [data-act=shut]').click();

    // 7 하루 닫기: 남은 것마다 한 번씩
    const left = await p.locator('[data-act=close]').innerText();
    await p.locator('[data-act=close]').scrollIntoViewIfNeeded(); await p.locator('[data-act=close]').click(); await p.waitForTimeout(150);
    await audit(p, `${N} 하루 닫기`); await shot('7-close');
    for (const v of ['tom', 'later', 'drop', 'tom', 'tom', 'tom']) { const q = p.locator(`[data-act=q][data-v=${v}]`); if (await q.count()) await q.click(); }
    ok(`${N} 닫음`, await p.locator('#q-end').count() === 1, `닫기 안 끝남 (${left})`);
    await audit(p, `${N} 닫음`); await shot('8-closed');
    await p.locator('#layer [data-act=shut]').click();
    ok(`${N} 닫은 뒤`, await p.locator('[data-act=close]').count() === 0, '남은 것이 있음');

    // 8 나중에 · 달력
    await p.locator('[data-act=later]').click(); await p.waitForTimeout(250);
    ok(`${N} 10일`, (await txt('#layer')).includes('12일째'), '오래된 일 묻지 않음');
    await audit(p, `${N} 나중에`); await shot('9-later'); await p.locator('#layer .btn.line[data-act=shut]').click();
    await p.locator('[data-act=cal]').click(); await p.waitForTimeout(250);
    await audit(p, `${N} 달력`); await shot('10-cal');
    await p.locator('#layer [data-k="2026-11-15"]').click();
    ok(`${N} 내일 보기`, (await txt('#main')).includes('미용실'), '내일에 미용실 없음'); await shot('11-tomorrow');
    await ctx.close();
  }
  // 한 줄 읽기 규칙
  const ctx = await b.newContext(); await ctx.addInitScript(() => { window.__now = '2026-11-14T14:20:00'; });
  const p = await ctx.newPage(); await p.goto('file://' + tmp);
  const cases = [['3시 치과', { time: 900, title: '치과' }], ['오전 9시 회의 1시간 반', { time: 540, dur: 90, title: '회의' }], ['9시 영화', { time: 1260, title: '영화' }],
    ['내일 9시 조깅', { time: 540, day: 1, title: '조깅' }], ['14:30 통화', { time: 870, title: '통화' }], ['저녁에 빨래 20분', { part: 'ev', dur: 20, title: '빨래' }],
    ['보고서 쓰기', { title: '보고서 쓰기' }], ['나중에 여권 갱신', { later: true, title: '여권 갱신' }], ['3분기 실적 정리', { title: '3분기 실적 정리' }], ['2시간 동안 공부', { dur: 120, title: '공부' }]];
  for (const [s, want] of cases) { const got = await p.evaluate(s => window.__day.parse(s), s);
    for (const k of ['time', 'dur', 'day', 'part', 'later', 'title']) if ((got[k] ?? null) !== (want[k] ?? null)) fail(`읽기 "${s}"`, `${k}: ${got[k]} ≠ ${want[k]}`); }
  await b.close();
  errs.forEach(e => fail('pageerror', e));
  log.forEach(l => console.log(l));
  console.log(`day: ${fails} fail`);
  process.exit(fails ? 1 : 0);
})();
