// 실행: (cd /tmp/shtest && npm i playwright-core) 후  PW=/tmp/shtest/node_modules/playwright-core node tests/refresh.test.js
// SHOTS=<dir> 를 주면 화면별 스크린샷을 남긴다. 끝 줄이 "errors: none" 이고 FAIL 이 없어야 통과.
const path = require('path');
const { chromium } = require(process.env.PW || 'playwright-core');
const url = (f, qs = '') => 'file://' + path.resolve(__dirname, '..', f) + qs;
let fails = 0;
const check = (name, ok, got) => { console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${ok ? '' : ' — got ' + JSON.stringify(got)}`); if (!ok) fails++; };

(async () => {
  const b = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const p = await b.newPage({ viewport: { width: 1000, height: 860 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => m.type() === 'error' && errs.push(m.text()));
  const shot = async n => process.env.SHOTS && p.screenshot({ path: path.join(process.env.SHOTS, n + '.png') });
  const on = () => p.$eval('section.on', e => e.id);
  const txt = s => p.$eval(s, e => e.textContent.trim());
  const ls = () => p.evaluate(() => ({ ...localStorage }));

  await p.goto(url('refresh.html', '?speed=200&hour=10'));
  await p.evaluate(() => localStorage.clear()); await p.reload(); await p.waitForTimeout(300);
  check('처음 실행은 소개 화면', await on() === 'sIntro', await on());
  await shot('r0-intro');
  await p.click('#kIntro');
  check('소개 → 상태 화면', await on() === 'sState', await on());
  check('기록 없을 때 안내', (await txt('#hist')).includes('0회'), await txt('#hist'));
  await shot('r1-state');

  // 1) 멍해 → 맑기 3 → 10분 → 밖으로 10분, 다른 거 토글, 책갈피, 실행, 돌아옴, 기록
  await p.click('[data-s="foggy"]');
  check('상태 탭 → 맑기 화면', await on() === 'sDial', await on());
  await p.click('#knob1 [data-v="3"]');
  check('노브 눈금 탭 → 3', await txt('#clrN') === '3', await txt('#clrN'));
  await shot('r2-dial');
  await p.click('[data-m="10"]'); await p.waitForTimeout(1300);
  check('멍해·10분 기본 = 밖으로 10분', await txt('#rxName') === '밖으로 10분', await txt('#rxName'));
  await p.click('#kAlt');
  check('다른 거 = 눈 감고 10분', await txt('#rxName') === '눈 감고 10분', await txt('#rxName'));
  await p.click('#kAlt');
  check('다시 다른 거 = 밖으로 10분', await txt('#rxName') === '밖으로 10분', await txt('#rxName'));
  await p.fill('#bmIn', '레포트 3장 첫 문장');
  await p.waitForTimeout(1200); await shot('r3-rx');
  await p.click('#kStart'); await p.waitForTimeout(400);
  check('시작 → 실행 화면', await on() === 'sRun', await on());
  check('실행 중 밤 배경', await p.$eval('#phone', e => e.classList.contains('night')), false);
  await shot('r4-run');
  await p.waitForTimeout(3600); // 600초 / 200배속 = 3초
  check('타이머 끝 → 돌아옴', await on() === 'sAfter', await on());
  check('책갈피를 먼저 보여 줌', await txt('#bmShowT') === '레포트 3장 첫 문장', await txt('#bmShowT'));
  check('돌아옴 노브 기본값 = 아까 값', await txt('#clr2N') === '3', await txt('#clr2N'));
  await p.click('#knob2 [data-v="7"]');
  await shot('r5-after');
  await p.click('#kSave'); await p.waitForTimeout(300);
  check('기록 → 결과', await on() === 'sRes', await on());
  check('전후 변화 +4', await txt('#resD') === '+4', await txt('#resD'));
  check('결과 끝 = 책갈피로 돌아가기', (await txt('#nextT')) === '레포트 3장 첫 문장' && (await txt('#kHomeT')) === '돌아가서 하기', await txt('#kHomeT'));
  check('결과에 내 기록 추이', (await txt('#hist2')).includes('1회'), await txt('#hist2'));
  await shot('r6-res');
  let s = await ls();
  const ses = JSON.parse(s['udada.refresh.sessions'] || '[]');
  check('세션 1건 저장', ses.length === 1 && ses[0].rx === 'walk10' && ses[0].b === 3 && ses[0].a === 7, ses);
  check('책갈피 문장은 저장 안 함', !JSON.stringify(s).includes('레포트 3장'), s);

  // 2) 졸려·20분: 오전엔 커피 낮잠, 오후 5시엔 커피 뺌
  await p.click('#kHome');
  await p.click('[data-s="sleepy"]'); await p.click('[data-m="20"]');
  check('졸려·20분·10시 = 커피 낮잠', await txt('#rxName') === '커피 낮잠', await txt('#rxName'));
  await p.goto(url('refresh.html', '?speed=200&hour=17')); await p.waitForTimeout(200);
  await p.click('[data-s="sleepy"]'); await p.click('[data-m="20"]');
  check('졸려·20분·17시 = 15분 낮잠 + 세수', await txt('#rxName') === '15분 낮잠 + 세수', await txt('#rxName'));

  // 3) 중간에 그만 → 중단 기록
  await p.goto(url('refresh.html', '?speed=1')); await p.waitForTimeout(200);
  await p.click('[data-s="stuck"]'); await p.click('[data-m="2"]');
  check('막혔어·2분 = 한 줄 적고 물', await txt('#rxName') === '한 줄 적고 물', await txt('#rxName'));
  check('막혔어 책갈피 = 문제 한 줄', await txt('#bmLbl') === '막힌 문제를 한 줄로', await txt('#bmLbl'));
  await p.click('#kStart'); await p.waitForTimeout(300); await p.click('#kStop');
  check('그만 → 돌아옴', await on() === 'sAfter', await on());
  await p.click('#kSave'); await p.waitForTimeout(200);
  s = await ls();
  const ses2 = JSON.parse(s['udada.refresh.sessions']);
  check('중단 플래그 저장', ses2.length === 2 && ses2[1].stopped === true, ses2.map(x => x.stopped));

  // 4) 꽉 찼어·10분 → 식히기 왕복 → 돌아와서 맑기 기록
  await p.click('#kHome');
  await p.click('[data-s="full"]'); await p.click('#knob1 [data-v="2"]'); await p.click('[data-m="10"]');
  check('꽉 찼어·10분 = 머리 비우기 3분', await txt('#rxName') === '머리 비우기 3분', await txt('#rxName'));
  await p.click('#kStart'); await p.waitForURL(/cooler\.html\?from=refresh/); await p.waitForTimeout(300);
  check('식히기는 비우기부터', await on() === 'sDump', await on());
  await p.click('#kEx'); await p.click('#kSort');
  for (let i = 0; i < 8; i++) { await p.keyboard.press('Enter'); await p.waitForTimeout(40); }
  await p.waitForTimeout(500);
  check('분류 끝 → 숨', await on() === 'sBreath', await on());
  await p.click('#kSkip'); await p.waitForTimeout(300);
  await shot('c1-one');
  await p.click('#kDone'); await p.waitForURL(/refresh\.html/); await p.waitForTimeout(300);
  check('식히기에서 돌아오면 돌아옴 화면', await on() === 'sAfter', await on());
  check('돌아옴 노브 = 아까 2', await txt('#clr2N') === '2', await txt('#clr2N'));
  await p.click('#knob2 [data-v="5"]'); await p.click('#kSave'); await p.waitForTimeout(200);
  s = await ls();
  const ses3 = JSON.parse(s['udada.refresh.sessions']);
  check('식히기 세션 기록', ses3.length === 3 && ses3[2].rx === 'cooler' && ses3[2].a - ses3[2].b === 3, ses3[2]);
  check('대기 상태 지움', !('udada.refresh.pending' in s), Object.keys(s));
  check('식히기 서랍에 날짜·손 밖 저장', JSON.parse(s['udada.cool.drawer'] || '[]').length >= 4, s['udada.cool.drawer']);
  check('순위표에 처방 3개', (await p.$$('#rank .row')).length === 3, (await p.$$('#rank .row')).length);

  // 5) 개인 힌트: 같은 처방 2회 이상이면 처방 화면에 비교가 뜬다
  await p.click('#kHome');
  check('홈 기록에 3회', (await txt('#hist')).includes('3회'), await txt('#hist'));
  check('홈 기록 막대 3개', (await p.$$('#hist .g > div')).length === 3, (await p.$$('#hist .g > div')).length);
  await p.evaluate(() => { const a = JSON.parse(localStorage.getItem('udada.refresh.sessions')); a.push({ ...a[0] }); localStorage.setItem('udada.refresh.sessions', JSON.stringify(a)); });
  await p.reload(); await p.waitForTimeout(200);
  check('홈에 잘 든 처방', (await txt('#best')).includes('밖으로 10분'), await txt('#best'));
  await p.click('[data-s="foggy"]'); await p.click('[data-m="10"]'); await p.click('#kAlt');
  check('다른 거 화면에 더 잘 든 처방 힌트', (await txt('#rxHint')).includes('밖으로 10분'), await txt('#rxHint'));

  // 6) 폰 크기
  await p.setViewportSize({ width: 390, height: 844 }); await p.goto(url('refresh.html')); await p.waitForTimeout(300);
  const ov = await p.evaluate(() => document.documentElement.scrollWidth > innerWidth);
  check('폰 폭 가로 스크롤 없음', !ov, ov);
  await shot('r7-mobile');

  console.log(fails ? `FAILED: ${fails}` : 'all checks passed');
  console.log('errors:', errs.length ? errs : 'none');
  await b.close();
  process.exit(fails || errs.length ? 1 : 0);
})();
