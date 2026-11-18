// 우다다 기계 공용 부품: 저장, 소리(WebAudio 합성, 파일 없음), 진동, 숫자판, 0~10 노브.
window.UD = (() => {
  const store = {
    get(k, d) { try { const v = localStorage.getItem(k); return v == null ? d : JSON.parse(v); } catch { return d; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} },
    del(k) { try { localStorage.removeItem(k); } catch {} },
  };

  let ac;
  const audio = () => { try { ac = ac || new (window.AudioContext || window.webkitAudioContext)(); if (ac.state === 'suspended') ac.resume(); } catch {} return ac; };
  function tone(type, f, start, dur, gain) {
    const a = audio(); if (!a) return;
    const o = a.createOscillator(), v = a.createGain(), t = a.currentTime + start;
    o.type = type; o.frequency.value = f;
    v.gain.setValueAtTime(0, t); v.gain.linearRampToValueAtTime(gain, t + Math.min(.02, dur / 4)); v.gain.exponentialRampToValueAtTime(.0001, t + dur);
    o.connect(v).connect(a.destination); o.start(t); o.stop(t + dur + .02);
  }
  const tick = (f = 1700, d = .018, g = .12) => tone('square', f, 0, d, g);
  function motor(sec) {
    const a = audio(); if (!a) return;
    const o = a.createOscillator(), v = a.createGain(), t = a.currentTime;
    o.type = 'sawtooth'; o.frequency.value = 64; v.gain.setValueAtTime(0, t); v.gain.linearRampToValueAtTime(.05, t + .05); v.gain.setValueAtTime(.05, t + sec - .1); v.gain.linearRampToValueAtTime(0, t + sec);
    o.connect(v).connect(a.destination); o.start(t); o.stop(t + sec);
  }
  // 알람: 부드럽게 커지는 세 번의 차임
  const chime = () => [0, .5, 1.0].forEach((s, i) => { tone('sine', 880, s, .45, .08 + i * .05); tone('sine', 1320, s, .3, .03 + i * .02); });
  // iOS 앱(WKWebView) 안이면 네이티브로: 햅틱·화면 유지·잠금 알람. 웹에선 아무것도 안 함.
  const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ud;
  const native = m => { try { bridge && bridge.postMessage(m); } catch {} };
  const buzz = p => {
    if (bridge) return native({ t: 'haptic', s: Array.isArray(p) ? (p.length >= 5 ? 'success' : 'medium') : (p <= 15 ? 'light' : 'medium') });
    try { navigator.vibrate && navigator.vibrate(p); } catch {}
  };
  document.addEventListener('pointerdown', e => { if (e.target.closest('.key,.chips button,.clickable')) tick(); }, true);

  function odo(el, n, digits = 3) {
    const s = String(Math.min(n, 10 ** digits - 1)).padStart(digits, '0');
    const old = [...el.children].map(c => c.textContent).join('');
    el.innerHTML = [...s].map((c, i) => `<span${old && old[i] !== c ? ' class="r"' : ''}>${c}</span>`).join('');
  }
  const mmss = ms => { const s = Math.max(0, Math.ceil(ms / 1000)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };
  const hhmm = () => { const d = new Date(); return `${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`; };
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // 0~10 노브. el = .bigknob (빈 div). onChange(v) 는 값이 바뀔 때마다.
  function knob(el, onChange) {
    el.tabIndex = 0; el.setAttribute('role', 'slider'); el.setAttribute('aria-valuemin', 0); el.setAttribute('aria-valuemax', 10);
    el.innerHTML = '<div class="tk">' + Array.from({ length: 11 }, (_, v) => {
      const a = 135 + 27 * v;
      return `<span data-v="${v}" style="transform:rotate(${a}deg) translate(5.75rem) rotate(${-a}deg) translate(-50%,-50%)">${v}</span>`;
    }).join('') + '</div><div class="k"></div>';
    const k = el.querySelector('.k'), ticks = [...el.querySelectorAll('[data-v]')];
    let val = -1;
    function set(v, quiet) {
      v = Math.max(0, Math.min(10, v));
      if (v !== val && !quiet) { tick(900 + v * 60, .012, .08); buzz(8); }
      val = v;
      ticks.forEach((t, i) => t.classList.toggle('on', i === v));
      k.style.transform = `rotate(${225 + 27 * v}deg)`;
      el.setAttribute('aria-valuenow', v);
      onChange(v);
    }
    function angleTo(e) {
      const r = el.getBoundingClientRect();
      let a = Math.atan2(e.clientY - (r.top + r.height / 2), e.clientX - (r.left + r.width / 2)) * 180 / Math.PI;
      if (a < 90) a += 360;
      return Math.round((Math.max(135, Math.min(405, a)) - 135) / 27);
    }
    el.addEventListener('pointerdown', e => {
      const t = e.target.closest('[data-v]');
      if (t) { set(+t.dataset.v); return; }
      el.setPointerCapture(e.pointerId); set(angleTo(e));
      const mv = ev => set(angleTo(ev));
      const up = () => { el.removeEventListener('pointermove', mv); el.removeEventListener('pointerup', up); el.removeEventListener('pointercancel', up); };
      el.addEventListener('pointermove', mv); el.addEventListener('pointerup', up); el.addEventListener('pointercancel', up);
    });
    el.addEventListener('keydown', e => {
      if (e.key === 'ArrowUp' || e.key === 'ArrowRight') { set(val + 1); e.preventDefault(); }
      if (e.key === 'ArrowDown' || e.key === 'ArrowLeft') { set(val - 1); e.preventDefault(); }
    });
    return { set, get: () => val };
  }

  // 0~10 눈금 막대
  function thermo(el, v) {
    if (!el.children.length) el.innerHTML = '<i></i>'.repeat(11);
    [...el.children].forEach((c, i) => c.className = i <= v ? '' : 'o');
  }

  function clock(el) { const f = () => el.textContent = hhmm(); f(); setInterval(f, 1000); }

  if (bridge) document.documentElement.classList.add('ud-app');

  // ── 화면 맞춤: 기계 전체를 한 배율 k 로. 디자인 캔버스 = 가로 390 × 세로 800 (rem 단위의 16px 기준).
  // 폰에선 k = min(가로/390, 세로/800). 세로는 '키보드 없을 때' 높이(baseH)로 재서, 키보드가 떠도 기계가 줄지 않게 한다.
  // 데스크톱 미리보기는 폰 틀(390×844)이 창에 들어가게만 줄인다.
  const root = document.documentElement, vv = window.visualViewport;
  const isPhone = () => !!bridge || matchMedia('(max-width:820px)').matches;
  const typing = () => { const a = document.activeElement; return !!a && /^(INPUT|TEXTAREA)$/.test(a.tagName); };
  const viewH = () => (vv ? vv.height : innerHeight);
  let baseH = innerHeight, baseW = innerWidth;
  function fit() {
    if (!typing()) { baseH = innerHeight; baseW = innerWidth; }
    const k = isPhone()
      ? Math.max(0.76, Math.min(1.25, baseW / 390, baseH / 800))
      : Math.min(1, (innerHeight - 48) / 844, (innerWidth - 32) / 390);
    root.style.fontSize = (16 * k).toFixed(3) + 'px';
    root.style.setProperty('--appH', Math.round(isPhone() ? viewH() : innerHeight) + 'px');
    // 키보드: 입력 중이고 보이는 높이가 120px 넘게 줄었으면
    root.classList.toggle('kb', isPhone() && typing() && viewH() < baseH - 120);
    if (isPhone() && window.scrollY) window.scrollTo(0, 0); // iOS 가 입력을 보이려고 문서를 밀어 올린 걸 되돌린다
  }
  fit();
  addEventListener('resize', fit);
  // 키보드로 화면이 가로보다 낮아져도 '회전'으로 잡힐 수 있어서, 입력 중이 아닐 때만 기준을 다시 잰다
  addEventListener('orientationchange', () => setTimeout(() => { if (!typing()) { baseH = innerHeight; baseW = innerWidth; } fit(); }, 300));
  if (vv) { vv.addEventListener('resize', fit); vv.addEventListener('scroll', () => window.scrollY && window.scrollTo(0, 0)); }
  document.addEventListener('focusin', () => [0, 120, 350].forEach(t => setTimeout(fit, t)));
  document.addEventListener('focusout', () => [0, 120, 350].forEach(t => setTimeout(fit, t)));
  // 빈 곳을 누르면 키보드를 내린다 (iOS 웹뷰는 빈 곳을 눌러도 포커스가 안 풀린다).
  // 버튼은 제외: 누르는 순간 키보드가 내려가며 배치가 바뀌면 손가락 아래 버튼이 달라진다.
  document.addEventListener('pointerdown', e => {
    if (typing() && !e.target.closest('input,textarea,button,.bigknob,[data-w]')) document.activeElement.blur();
  }, true);
  return { store, tick, motor, chime, buzz, odo, mmss, hhmm, esc, knob, thermo, clock, native, isApp: !!bridge };
})();
