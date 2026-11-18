// 실행: (cd /tmp/shtest && npm i playwright-core) 후  PW=/tmp/shtest/node_modules/playwright-core node tests/shredder.test.js

const { chromium } = require(process.env.PW || 'playwright-core');
(async () => {
  const b = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const p = await b.newPage({ viewport: { width: 1000, height: 860 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => m.type()==='error' && errs.push(m.text()));
  await p.goto('file://' + require('path').resolve(__dirname, '../shredder.html'));
  await p.evaluate(() => localStorage.clear()); await p.reload(); await p.waitForTimeout(300);
  const odo = () => p.$eval('#odo', e => e.textContent);
  // 1) 꾹 누르기: 0.4초 누르고 떼기 → 멈춤 상태여야
  await p.fill('#cardText', '그때 그 말 왜 했지').catch(()=>p.evaluate(()=>document.getElementById('cardText').textContent='그때 그 말 왜 했지'));
  await p.click('#phone', { position:{x:10,y:300} }); // blur
  const go = await p.$('#kGo'); const bb = await go.boundingBox();
  await p.mouse.move(bb.x+bb.width/2, bb.y+bb.height/2); await p.mouse.down(); await p.waitForTimeout(400); await p.mouse.up();
  await p.waitForTimeout(300);
  console.log('after short hold:', await p.$eval('#lcdB', e=>e.textContent), '|', await p.$eval('#lcdMsg', e=>e.textContent));
  // 2) 다시 누르고 있으면 절반 넘으면 자동으로 끝까지
  await p.mouse.down(); await p.waitForTimeout(900); await p.mouse.up(); await p.waitForTimeout(1800);
  console.log('after long hold:', await p.$eval('#lcdB', e=>e.textContent), '| odo', await odo(), '| bin', await p.$eval('#binTxt', e=>e.textContent), '| bits', await p.$$eval('#bin .bit', a=>a.length));
  console.log('card hidden:', await p.$eval('#card', e=>getComputedStyle(e).display));
  // 3) 드래그로 넣기 (새 카드, 빈 카드 → 예시 문구)
  await p.click('#kNew'); await p.click('#phone', { position:{x:10,y:300} });
  const c = await (await p.$('#card .h')).boundingBox();
  await p.mouse.move(c.x+40, c.y+5); await p.mouse.down();
  for (let i=1;i<=20;i++){ await p.mouse.move(c.x+40, c.y+5+i*6); await p.waitForTimeout(16); }
  await p.mouse.up(); await p.waitForTimeout(2200);
  console.log('after drag:', await p.$eval('#lcdB', e=>e.textContent), '| odo', await odo());
  // 4) 저장된 것: 카운트만
  console.log('localStorage:', JSON.stringify(await p.evaluate(()=>({...localStorage}))));
  // 5) 통 가득 → 갈기 비활성, 비우기
  await p.evaluate(()=>{ localStorage.setItem('udada.shred.bin','10'); }); await p.reload(); await p.waitForTimeout(300);
  console.log('full bin: go disabled =', await p.$eval('#kGo', e=>e.disabled), '|', await p.$eval('#lcdMsg', e=>e.textContent));
  await p.click('#kEmpty'); await p.waitForTimeout(900);
  console.log('after empty:', await p.$eval('#binTxt', e=>e.textContent), '| go disabled =', await p.$eval('#kGo', e=>e.disabled));
  console.log('errors:', errs.length ? errs : 'none');
  await b.close();
})();
