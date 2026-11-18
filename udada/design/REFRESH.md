# 뇌 리프레시: 논문 공부와 앱 설계

> 결론 먼저: **"뇌가 안 돌아간다"는 상태가 하나가 아니다.** 근거가 서로 다른 네 상태가 섞여 있다. **졸림**(잠이 모자람), **과부하**(머릿속 열린 고리가 많음), **피로**(오래 집중함), **막힘**(한 문제에서 맴돎).
> 상태마다 듣는 처방이 다르고, 공통점은 하나다. **화면 밖에서 해야 한다.**
> 그래서 우다다의 입구를 이렇게 바꾼다. "지금 머리 어때?"를 두 번 탭으로 고르면 처방 한 장이 나오고, 화면이 꺼진 채 타이머가 돈다. 돌아오면 맑기를 다시 잰다. 그러면서 나한테 무엇이 잘 듣는지 쌓인다.
> VALUE.md의 '식히기'는 이 중 **과부하** 갈래가 된다. 이 문서는 VALUE.md의 후속이고, 거기서 읽은 논문 27편은 다시 적지 않는다.

---

## 1. 뇌에서 무슨 일이 일어나나

| 발견 | 근거 | 설계에 주는 뜻 |
|---|---|---|
| 하루 종일 어려운 인지 통제 과제를 한 그룹은 쉬운 과제 그룹보다 저녁에 **외측 전전두엽의 글루타메이트**가 높았다. 결정도 '덜 힘들고 빨리 받는' 쪽으로 기울었고, 결정할 때 동공 반응이 줄었다. | Wiehler et al. 2022, *Current Biology* (자기공명분광, MRS) | 피로는 기분 탓이 아니라 측정되는 변화다. 다만 쉬면 얼마나 빨리 빠지는지는 아직 모른다. |
| 피로는 '연료가 떨어졌다'보다 **비용이 기대 보상보다 커졌다**는 평가에 가깝다. 전대상피질·섬엽·안와전두엽·측좌핵이 비용과 보상을 저울질한다. | Boksem & Tops 2008 (리뷰) · Kurzban et al. 2013 (기회비용 모델) | 몸을 바꾸든(걷기·낮잠), 일을 바꾸든(딴짓), **회로를 바꿔 주는 것**이 처방이다. |
| 2시간 동안 n-back을 해서 지친 사람도 보상을 올리자 수행·P3·동공이 원래대로 돌아왔다. | Hopstaken et al. 2015 | 피로의 상당 부분은 **이탈(disengagement)**이라서 되돌릴 수 있다. |
| 의지력이 배터리처럼 닳는다는 '자아 고갈'은 23개 실험실의 사전등록 재현(N=2,141)에서 **d=0.04**였다. 신뢰구간이 0을 포함한다. | Hagger et al. 2016 | **앱 문구에 "배터리 방전·에너지 0%"를 쓰지 않는다.** |
| 의지력이 한정돼 있다고 **믿는** 사람만 고갈을 보였다. | Job, Dweck & Walton 2010 | 그 믿음 자체가 피로를 키운다. 그래서 "고장 난 게 아니라 '바꿔 달라'는 신호"라고 말한다. |
| 한 목표를 오래 붙들고 있으면 목표가 습관화돼 경계 수행이 떨어진다. **짧고 드문 전환**이 이를 막았다. | Ariga & Lleras 2011 | 2분짜리 처방에도 의미가 있다. |
| 멍하니 쉴 때 켜지는 기본 모드 네트워크(DMN)는 놀고 있는 게 아니라 기억을 정리하고 자기를 성찰한다. | Immordino-Yang et al. 2012 | 쉬는 시간을 콘텐츠로 채우지 않는다. |
| 새로 배운 뒤 10분 동안 가만히 쉬면 7일 뒤에도 더 많이 기억했다. | Dewar et al. 2012 · Wamsley 2019 (리뷰) | 방금 공부했다면 '눈 감고 10분'. |
| 잠이 모자라면 단순 주의 실수가 크게 늘었다(g=−0.78). 추론 정확도는 거의 그대로였다. | Lim & Dinges 2010 (70편 메타) | 잠 빚은 다른 휴식으로 못 메운다. 정직하게 말한다. |

## 2. 무엇이 실제로 리프레시하나 (근거 강도순)

| 방법 | 무엇이 좋아졌나 | 근거 | 강도 |
|---|---|---|---|
| **10분 낮잠** | 졸림·피로·활력·인지 수행이 **바로** 좋아졌고, 일부는 155분까지 갔다. 5분은 거의 효과가 없었고, 30분은 깬 직후 오히려 더 멍했다(수면 관성). | Brooks & Lack 2006 (N=24, 전날 5시간 수면) | 중 |
| 짧은 낮잠 일반 | 인지 g=.18, 각성 g=.29. 오후 이른 시간(13시 전) 낮잠이 더 좋았다. | Dutheil et al. 2021 (11편 메타) | 중 |
| **커피 낮잠** | 낮잠 직전 카페인이 졸림·수행 모두 가장 좋았다. 낮잠+밝은 빛이 그다음이었다. | Hayashi et al. 2003 (N=10) | 약 (표본 작음) |
| 찬물 세수·밝은 빛 | 세수는 졸림을 바로 줄이지만 짧게 끝났다. | Hayashi et al. 2003 | 약 |
| 커피 시간 제한 | 400mg을 잠들기 6시간 전에 마셔도 밤잠이 줄었다. | Drake et al. 2013 | 중 → **오후 4시 이후엔 커피 낮잠을 내지 않는다** |
| **걷기·계단** | 실행기능 반응속도 g=.35(40편). 한 번 운동의 인지 효과는 전반적으로 작다(g=.10, 79편). 잠이 부족한 사람에게 10분 계단 걷기가 카페인 50mg보다 활력을 더 올렸다. | Ludyga et al. 2016 · Chang et al. 2012 · Randolph & O'Connor 2017 (N=18) | 중 |
| **자연** | 자연 속 걷기나 자연 사진 보기가 주의를 회복시켰다. 다만 리뷰 결과는 혼재한다(13개 지표 중 3개만 유의). 작업기억·인지 유연성은 소~중 효과를 보였고, 실제 자연이 가상보다 강할 수 있다. 실외에선 긍정 기분이 올랐지만 VR 자연에선 그대로였다. 자연 소리만 들어도 주의 점수가 올랐다. | Berman et al. 2008 · Ohly et al. 2016 · Stevenson et al. 2018 · Browning et al. 2020 · Van Hedger et al. 2019 | 중 (혼재) |
| **호흡** | 호흡법이 스트레스를 g=−.35 낮췄다(RCT 메타). 두 번 들이쉬고 길게 내쉬기가 명상보다 기분을 더 올렸다. 느린 호흡은 심박변이도(HRV)와 알파파를 올렸다. | Fincham et al. 2023 · Balban et al. 2023 · Zaccaro et al. 2018 | 중 |
| 짧은 휴식 | 활력 d=.36, 피로 감소 d=.35 | Albulescu et al. 2022 (메타) | 중 |
| 점심 공원 산책 15분 | 오후 집중이 오르고 피로가 줄었다(즐거움을 거쳐서). 이완 운동은 '분리'를 거쳐 집중을 올렸다. | Sianoja et al. 2018 (N=97, 10일) | 중 |
| **단순한 딴짓** (막혔을 때) | 머리 안 쓰는 단순한 일을 한 쪽이 쉬기·어려운 일·안 쉬기보다 창의 문제를 더 풀었다. 준비를 길게 할수록 부화 효과가 컸다. | Baird et al. 2012 · Sio & Ormerod 2009 (메타) | 중 |
| 밖에서 걷기 (아이디어) | 걷는 동안과 직후에 발산적 사고가 늘었고, 밖에서 걸을 때 가장 새로운 비유가 나왔다. | Oppezzo & Schwartz 2014 | 중 |
| 요가 니드라·NSDR | 숙련자는 명상 중 복측 선조체 도파민 방출이 65% 늘었다(소수). NSDR 한 번으로 주관적 개선은 일관됐지만 인지 효과는 일시적이었다. | Kjaer et al. 2002 · 2026 *Appl Psychol Health Well-Being* | 약 (초기) |
| 카페인·향·음악·외적 보상 | 정신 피로 대응책 중 근거가 가장 많다. | Proost et al. 2022 (체계적 고찰) | 중 (앱이 줄 수 없는 것이 많음) |
| ✗ 폰으로 쉬기 | 같은 휴식이라도 폰으로 쉬면 회복이 가장 적었다. 머리 쓰는 휴식은 오히려 부정 정서를 키웠다. | Kang & Kurtzberg 2019 · Kim, Park & Niu 2017 | **하지 말 것** |

### 회복의 네 가지 경험 → 앱이 지킬 것
Sonnentag & Fritz 2007의 회복 경험 척도와 Bennett et al. 2018 메타(54개 표본, N=26,592)를 따른다.
- **분리**(detachment)가 피로 감소와 가장 강하게 연결됐다. → 처방 중엔 화면을 끄고, 일은 '책갈피'에 맡긴다.
- **통제**(control)가 활력과 가장 강하게 연결됐다. → 처방은 기계가 정하지만 **[다른 거]** 한 번으로 바꿀 수 있다.
- **이완**(relaxation) → 호흡·낮잠.
- **숙달**(mastery) → 이번 범위 밖.

### 휴식 전 '책갈피' (Leroy 2009, Leroy & Glomb 2018)
일을 끊고 나가도 주의가 이전 일에 남는다(주의 잔여). 그런데 돌아와서 무엇부터 할지 짧게 계획해 두면 잔여가 줄었다(4개 연구).
→ 처방을 시작하기 전에 한 줄: **"돌아오면 먼저 할 것"**. 돌아오면 이 줄을 먼저 보여 준다.
'막혔어' 갈래에서는 이 한 줄이 **"막힌 문제를 한 줄로"**가 된다. 준비를 길게 할수록 부화 효과가 커지기 때문이다(Sio & Ormerod 2009).

## 3. 설계

### 한 줄
**우다다 리프레시 = 지금 머리 상태를 두 번 탭으로 고르면, 근거 있는 처방 한 장을 뽑아 주고 화면을 끄는 기계.** 돌아오면 맑기를 다시 재고, 나한테 무엇이 잘 듣는지 쌓인다.

### 흐름 (`refresh.html`)
1. **상태** (1탭): 졸려 / 꽉 찼어 / 멍해 / 막혔어
2. **맑기 + 시간** (노브 + 1탭): 맑기 0(안 돌아감)~10(쌩쌩), 시간 2분 / 10분 / 20분
3. **처방 영수증**: 이름, 단계, 왜(논문 한 줄), 책갈피 한 줄(선택), [다른 거] [시작]
4. **화면 꺼짐 타이머**: 단계별 안내, 끝나면 알람과 진동. 화면 꺼짐 방지(Wake Lock)를 건다.
5. **돌아옴**: 책갈피를 먼저 보여 주고, 맑기를 다시 잰다.
6. **결과**: 전→후 맑기, 그리고 '나한테 잘 든 처방' 순위(같은 사람 안에서 비교)

### 처방표 (상태 × 시간, 앞이 기본 / 뒤가 [다른 거])

| | 2분 | 10분 | 20분 |
|---|---|---|---|
| **졸려** | 찬물 세수 + 밝은 데 + 계단 / 숨 다섯 번 | **10분 낮잠** / 찬물 세수 | **커피 낮잠** (16시 이후엔 15분 낮잠 + 세수) / 10분 낮잠 |
| **꽉 찼어** | 숨 다섯 번 + 먼 데 / 일어나서 멀리 보기 | **머리 비우기 3분** (`cooler.html`) / 숨 | 머리 비우기 / 밖으로 10분 |
| **멍해** | 일어나서 멀리 보기 / 숨 | **밖으로 10분** / 눈 감고 10분 (방금 공부했다면) | **초록 걷기 15분 + 눈 감기 5분** / 10분 낮잠 |
| **막혔어** | 한 줄 적고 물 / 숨 | **머리 안 쓰는 딴짓 10분** / 밖으로 10분 | **밖에서 걷기 15분 + 떠오른 거 적기** / 딴짓 |

- 처방은 모두 몸으로 하는 일이다. 화면 속 자연이나 영상은 처방으로 내지 않는다(Browning 2020, Kang & Kurtzberg 2019).
- '졸려'의 결과 화면에서는 정직하게 말한다: "잠이 모자란 거라면 진짜 처방은 오늘 밤 잠"(Lim & Dinges 2010).

### 문구 원칙
- "배터리·방전·에너지 0%" 금지(Job 2010, Hagger 2016). 대신 "오래 집중하면 앞이마 쪽 회로의 비용이 올라가. 고장이 아니라 바꿔 달라는 신호야"(Wiehler 2022, Boksem 2008).
- 결과는 사실만 말한다. 점수·연속 기록·무작위 보상은 없다(VALUE.md, Deci 1999).
- 근거는 한 줄로, 저자와 연도를 붙인다. 효과가 약한 건 약하다고 쓴다.

### 측정과 판정 기준
- **1차**: 처방 전후 맑기 **중앙값 +2 이상**
- **2차**: 처방을 끝까지 한 비율(중간에 [그만] 안 누름) 70%+, 처방 화면에서 [시작]까지 간 비율 80%+
- **개인**: 같은 사람 안에서 처방별 평균 변화를 비교한다. 2회 이상 쌓이면 더 잘 든 처방을 처방 화면에 힌트로 띄운다.
- **하지 않을 것**: 앱 사용 시간을 성공으로 보기, 연속 기록
- **나중에**: 3분 반응속도 검사(PVT-B, Basner et al. 2011)로 주관 점수를 보강한다. 지금은 넣지 않는다. 마찰이 늘고 연습 효과가 있기 때문이다.

### 저장
- 세션 기록(상태, 처방, 전후 맑기, 시간, 중간 종료 여부)만 기기 안 localStorage에 남긴다.
- 책갈피 문장은 돌아와서 보여 준 뒤 지운다.

### 남기는 것 / 바뀌는 것
- VALUE.md의 식히기(비우기 → 분류 → 숨 → 하나만)는 '꽉 찼어' 갈래로 그대로 쓴다. 리프레시에서 들어오면 식히기의 온도 단계는 건너뛰고, 맑기로 잰다.
- 식히기를 단독으로 실행하면 온도(뜨거움)를 그대로 쓴다.

## 4. 한계
- 효과 크기는 대부분 작다(g .1~.35). 실험실·대학생·작은 표본이 많다.
- 커피 낮잠은 N=10, 요가 니드라 도파민 연구는 소수, NSDR은 초기 연구다.
- 전후 자기 보고는 기대 효과에 약하다. 같은 사람 안에서 처방끼리 비교하는 것으로 일부 보완한다.
- 치료가 아니다. 몇 주째 계속 안 돌아가면 수면·우울·번아웃 상담을 권한다.
- Wiehler 2022, Boksem 2008, Chang 2012, Ariga 2011, Van Hedger 2019, Hayashi 2003, Drake 2013은 OpenAlex에 초록이 없어서 Europe PMC 초록으로 확인했다. Leroy 2009는 초록을 못 구해서 알려진 결론만 인용했다.

## 참고문헌 (이번에 읽은 것. 나머지는 VALUE.md)
- Ariga, A., & Lleras, A. (2011). Brief and rare mental "breaks" keep you focused. *Cognition*. doi:10.1016/j.cognition.2010.12.007
- Baird, B. et al. (2012). Inspired by distraction: Mind wandering facilitates creative incubation. *Psychological Science*. doi:10.1177/0956797612446024
- Basner, M., Mollicone, D., & Dinges, D. F. (2011). Validity and sensitivity of a brief PVT (PVT-B). *Acta Astronautica*. doi:10.1016/j.actaastro.2011.07.015
- Bennett, A. A., Bakker, A. B., & Field, J. G. (2018). Recovery from work-related effort: A meta-analysis. *J. Organizational Behavior*. doi:10.1002/job.2217
- Berman, M. G., Jonides, J., & Kaplan, S. (2008). The cognitive benefits of interacting with nature. *Psychological Science*. doi:10.1111/j.1467-9280.2008.02225.x
- Boksem, M. A. S., & Tops, M. (2008). Mental fatigue: Costs and benefits. *Brain Research Reviews*. doi:10.1016/j.brainresrev.2008.07.001
- Brooks, A., & Lack, L. (2006). A brief afternoon nap following nocturnal sleep restriction. *Sleep*. doi:10.1093/sleep/29.6.831
- Browning, M. H. E. M. et al. (2020). Can simulated nature support mental health? 360° nature videos in VR vs the outdoors. *Frontiers in Psychology*. doi:10.3389/fpsyg.2019.02667
- Chang, Y. K. et al. (2012). The effects of acute exercise on cognitive performance: A meta-analysis. *Brain Research*. doi:10.1016/j.brainres.2012.02.068
- Dewar, M. et al. (2012). Brief wakeful resting boosts new memories over the long term. *Psychological Science*. doi:10.1177/0956797612441220
- Drake, C. et al. (2013). Caffeine effects on sleep taken 0, 3, or 6 hours before going to bed. *J. Clinical Sleep Medicine*. doi:10.5664/jcsm.3170
- Dutheil, F. et al. (2021). Effects of a short daytime nap on cognitive performance: Meta-analysis. *IJERPH*. doi:10.3390/ijerph181910212
- Fincham, G. W. et al. (2023). Effect of breathwork on stress and mental health: Meta-analysis of RCTs. *Scientific Reports*. doi:10.1038/s41598-022-27247-y
- Hagger, M. S. et al. (2016). A multilab preregistered replication of the ego-depletion effect. *Perspectives on Psychological Science*. doi:10.1177/1745691616652873
- Hayashi, M., Masuda, A., & Hori, T. (2003). The alerting effects of caffeine, bright light and face washing after a short daytime nap. *Clinical Neurophysiology*. doi:10.1016/S1388-2457(03)00255-4
- Hopstaken, J. F. et al. (2015). A multifaceted investigation of the link between mental fatigue and task disengagement. *Psychophysiology*. doi:10.1111/psyp.12339
- Immordino-Yang, M. H., Christodoulou, J. A., & Singh, V. (2012). Rest is not idleness. *Perspectives on Psychological Science*. doi:10.1177/1745691612447308
- Job, V., Dweck, C. S., & Walton, G. M. (2010). Ego depletion: Is it all in your head? *Psychological Science*. doi:10.1177/0956797610384745
- Kim, S., Park, Y., & Niu, Q. (2017). Micro-break activities at work to recover from daily work demands. *J. Organizational Behavior*. doi:10.1002/job.2109
- Kjaer, T. W. et al. (2002). Increased dopamine tone during meditation-induced change of consciousness. *Cognitive Brain Research*. doi:10.1016/S0926-6410(01)00106-9
- Kurzban, R. et al. (2013). An opportunity cost model of subjective effort and task performance. *Behavioral and Brain Sciences*. doi:10.1017/S0140525X12003196
- Leroy, S. (2009). Why is it so hard to do my work? Attention residue. *OBHDP*. doi:10.1016/j.obhdp.2009.04.002
- Leroy, S., & Glomb, T. M. (2018). Tasks interrupted: A "ready-to-resume" plan mitigates attention residue. *Organization Science*. doi:10.1287/orsc.2017.1184
- Lim, J., & Dinges, D. F. (2010). A meta-analysis of the impact of short-term sleep deprivation on cognitive variables. *Psychological Bulletin*. doi:10.1037/a0018883
- Ludyga, S. et al. (2016). Acute effects of moderate aerobic exercise on executive function: Meta-analysis. *Psychophysiology*. doi:10.1111/psyp.12736
- Ohly, H. et al. (2016). Attention Restoration Theory: A systematic review. *J. Toxicol. Environ. Health B*. doi:10.1080/10937404.2016.1196155
- Oppezzo, M., & Schwartz, D. L. (2014). Give your ideas some legs. *JEP: Learning, Memory, and Cognition*. doi:10.1037/a0036577
- Proost, M. et al. (2022). How to tackle mental fatigue: A systematic review of potential countermeasures. *Sports Medicine*. doi:10.1007/s40279-022-01678-z
- Randolph, D. D., & O'Connor, P. J. (2017). Stair walking is more energizing than low dose caffeine in sleep deprived young women. *Physiology & Behavior*. doi:10.1016/j.physbeh.2017.03.013
- Sianoja, M. et al. (2018). Lunchtime park walks and relaxation exercises. *J. Occupational Health Psychology*. doi:10.1037/ocp0000083
- Sio, U. N., & Ormerod, T. C. (2009). Does incubation enhance problem solving? A meta-analytic review. *Psychological Bulletin*. doi:10.1037/a0014212
- Sonnentag, S., & Fritz, C. (2007). The Recovery Experience Questionnaire. *J. Occupational Health Psychology*. doi:10.1037/1076-8998.12.3.204
- Stevenson, M. P., Schilhab, T., & Bentsen, P. (2018). Attention Restoration Theory II. *J. Toxicol. Environ. Health B*. doi:10.1080/10937404.2018.1505571
- Van Hedger, S. C. et al. (2019). Of cricket chirps and car horns: Nature sounds and cognitive performance. *Psychonomic Bulletin & Review*. doi:10.3758/s13423-018-1539-1
- Wamsley, E. J. (2019). Memory consolidation during waking rest. *Trends in Cognitive Sciences*. doi:10.1016/j.tics.2018.12.007
- Wiehler, A. et al. (2022). A neuro-metabolic account of why daylong cognitive work alters the control of economic decisions. *Current Biology*. doi:10.1016/j.cub.2022.07.010
- Zaccaro, A. et al. (2018). How breath-control can change your life: Slow breathing systematic review. *Frontiers in Human Neuroscience*. doi:10.3389/fnhum.2018.00353
- NSDR 단일 세션 연구 (2026). Time course of responses to a single non-sleep deep rest session. *Applied Psychology: Health and Well-Being*. doi:10.1111/aphw.70180
