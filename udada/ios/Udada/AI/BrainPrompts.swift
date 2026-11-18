import CoreGraphics
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// 기기 안 언어 모델(Apple 지능)에 닿는 곳은 이 파일뿐이다: 상태 확인 · 세션 · 지시문 · 생성 모양(@Generable).
// 규칙은 지시문에, 사용자 글과 사실은 프롬프트에. 세션은 한 번 쓰고 버린다 (대화 기록을 쌓지 않는다).
// 결과는 그대로 쓰지 않는다 — Brain 이 BrainRules 로 검사한 뒤에만 화면에 간다. 근거와 측정: udada/design/AI.md

extension Brain {
    /// 모델 쪽 상태 (설정의 'AI 쓰기'는 Brain.status 가 먼저 본다)
    nonisolated static func modelStatus() -> Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return model.supportsLocale(Locale(identifier: "ko_KR")) ? .ready : .unavailable("Apple 지능이 아직 한국어를 지원하지 않아")
            case .unavailable(.deviceNotEligible): return .unavailable("이 기기는 Apple 지능을 지원하지 않아")
            case .unavailable(.appleIntelligenceNotEnabled): return .unavailable("설정에서 Apple 지능을 켜면 쓸 수 있어")
            case .unavailable(.modelNotReady): return .unavailable("Apple 지능 모델을 내려받는 중이야. 조금 뒤에 돼")
            case .unavailable: return .unavailable("지금은 Apple 지능을 쓸 수 없어")
            }
        }
        #endif
        return .unavailable("iOS 26부터 기기 안 AI를 쓸 수 있어")
    }

    /// 비우기 지시문을 미리 올려 둔 세션 (첫 응답이 빨라진다). 한 번만 쓴다.
    nonisolated static func warmSession() -> AnyObject? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let s = LanguageModelSession(instructions: Prompt.organize)
            s.prewarm()
            return s
        }
        #endif
        return nil
    }

    @concurrent nonisolated static func aiOrganize(_ text: String, warm: AnyObject?) async throws -> [BrainRules.Draft] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.organize(text, warm: warm) }
        #endif
        throw Unavailable()
    }

    /// 비우기 정리를 흘려 받는다: 카드가 한 장 완성될 때마다 지금까지의 카드들을 넘긴다. 끝나면 전부를 돌려준다.
    @concurrent nonisolated static func aiOrganizeStream(_ text: String, warm: AnyObject?, onDrafts: @escaping @Sendable ([BrainRules.Draft]) async -> Void) async throws -> [BrainRules.Draft] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.organizeStream(text, warm: warm, onDrafts: onDrafts) }
        #endif
        throw Unavailable()
    }

    @concurrent nonisolated static func aiCard(_ line: String) async throws -> BrainRules.Draft {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.card(line) }
        #endif
        throw Unavailable()
    }

    @concurrent nonisolated static func aiFirstStep(_ title: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.text(Prompt.firstStep, "할 일: \(title)", max: 40) }
        #endif
        throw Unavailable()
    }

    /// 걱정 판단: 내 손에 든 게 있나 + 아주 작은 한 걸음 (문장은 규칙이 붙인다)
    @concurrent nonisolated static func aiWorry(_ text: String) async throws -> WorryAdvice {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.worry(text) }
        #endif
        throw Unavailable()
    }

    /// 이 기기의 모델이 그림을 볼 수 있나 (iOS 27 · macOS 27 부터)
    nonisolated static func canSeeImages() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) { return SystemLanguageModel.default.capabilities.contains(.vision) }
        #endif
        return false
    }

    /// 사진 보기: 포스터·안내문·진료 카드에서 일정과 할 일을 찾는다. 결과는 BrainRules.lines(from:ocr:) 가 글자 인식 결과와 맞춰 본 뒤에만 쓴다.
    @concurrent nonisolated static func aiSeePhoto(_ image: CGImage, ocr: String) async throws -> [BrainRules.SeenEvent] {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) { return try await Gen.photo(image, ocr: ocr) }
        #endif
        throw Unavailable()
    }

    /// 시키는 말 읽기: 줄마다 무슨 동작인지와 가리키는 일의 이름 (실제 바꾸기는 CommandRules 가 기록에 대고 한다)
    @concurrent nonisolated static func aiCommand(_ pieces: [String]) async throws -> [CommandReading?] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.command(pieces) }
        #endif
        throw Unavailable()
    }

    /// 물음 읽기: 무엇을 · 언제 · 어떤 것 (답은 FindRules 가 실제 기록에서 찾는다)
    @concurrent nonisolated static func aiFind(_ question: String) async throws -> FindQuery {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.find(question) }
        #endif
        throw Unavailable()
    }

    /// 밖에서 받기: 남이 보낸 글에서 챙길 일정·할 일의 이름과 글에 적힌 때 낱말 (검사는 CaptureRules.lines(from:))
    @concurrent nonisolated static func aiCapture(_ text: String) async throws -> [CaptureRules.Found] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.capture(text) }
        #endif
        throw Unavailable()
    }

    /// 뜻으로 찾기: 실제 기록 이름 목록에서 물음과 뜻이 맞는 것을 글자 그대로 베껴 온다 (검사는 FindRules.trusted)
    @concurrent nonisolated static func aiPick(_ question: String, titles: [String], need: Int) async throws -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // 다섯 번 가운데 need 번 넘게 고른 이름만, 그리고 그 이름 하나만 놓고 따로 물어도 맞다고 한 것만 (Eval/study_votes.py).
            // 틀린 것은 한두 표에 몰리고, 따로 묻는 검사는 맞는 것을 거의 안 버리면서 틀린 것을 거른다. 측정: design/AI.md 16절.
            let v = try await Gen.pickVotes(question, titles: titles, need: need)
            var out: [String] = []
            for t in titles where v[t, default: 0] >= need {
                // 다섯 번 다 고른 이름은 그대로 받는다 (네 묶음에서 틀린 것을 늘리지 않고 찾음이 72·79·75·73% → 74·79·75·88%).
                // 서너 번 고른 이름은 검사 둘(갈래에 드나 · 사이가 '다른 갈래'가 아닌가)을 모두 넘어야 한다.
                if v[t, default: 0] >= 5 { out.append(t); continue }
                if try await Gen.fits(question, title: t), try await !Gen.unrelated(question, title: t) { out.append(t) }
            }
            return out
        }
        #endif
        throw Unavailable()
    }

    @concurrent nonisolated static func aiPickVotes(_ question: String, titles: [String]) async throws -> [String: Int] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.pickVotes(question, titles: titles, need: nil) }
        #endif
        throw Unavailable()
    }

    @concurrent nonisolated static func aiUnrelated(_ question: String, title: String) async throws -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.unrelated(question, title: title) }
        #endif
        throw Unavailable()
    }

    @concurrent nonisolated static func aiFits(_ question: String, title: String) async throws -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.fits(question, title: title) }
        #endif
        throw Unavailable()
    }

    /// 쪼개기: 큰일 하나를 순서대로 놓은 걸음 3~5개로 (검사는 BreakRules.clean, 날에 놓기는 BreakRules.place)
    @concurrent nonisolated static func aiBreakdown(_ subject: String) async throws -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.breakdown(subject) }
        #endif
        throw Unavailable()
    }

    /// (입력에서 베낀 때 낱말, 표준 꼴) — 둘 다 ""면 못 찾음
    @concurrent nonisolated static func aiWhen(_ text: String, today: DayKey) async throws -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await Gen.when(text, today: today) }
        #endif
        throw Unavailable()
    }
}

private struct Unavailable: Error {}

// MARK: - 지시문

private enum Prompt {
    /// 네 칸. 예시는 흔한 갈래만 (하네스에서 고른 꼴 — AI.md)
    static let bins = """
    - now: 2분이면 끝나는 아주 작은 일 (전화 한 통, 짧은 답장, 문자 보내기, 약 먹기, 물 마시기, 결제·예약·구독 해지 하나)
    - date: 2분보다 오래 걸려서 언제 할지 정해야 하는 일 (보고서, 청소, 운동, 산책, 장보기, 병원 가기)
    - worry: 걱정·불안·후회처럼 지금 손쓸 수 없는 생각
    - drop: 할까 말까 망설이는 것, 꼭 안 해도 되는 것, 막연한 바람
    """

    /// 짧고 말하듯이. 고쳐야 할 꼴(~하고 등)을 지시문에 적으면 작은 모델은 오히려 그 꼴을 따라 쓴다 (하네스: 끝맺음 못 한 줄 1/30 → 19/31).
    static let organize = """
    너는 할 일 정리 도우미야. 사용자가 머릿속에 든 것을 마구 쏟아낸 글을 받으면, 하나하나 따로 떼어서 짧은 한 줄로 다시 쓰고 네 칸 중 하나로 나눠.
    \(bins)
    입력에 없는 일·날짜·사람을 지어내지 마.
    """

    static let card = """
    너는 할 일 카드 하나를 네 칸 중 하나로 나누는 도우미야.
    \(bins)
    """

    static let firstStep = """
    너는 시작을 어려워하는 사람을 돕는 도우미야. 할 일 하나를 받으면, 그 일을 시작하는 첫 동작 하나만 말한다.
    - 2분 안에 몸으로 바로 할 수 있는 구체적인 행동이다.
    - 20자 안팎, "~하기"나 "~두기"로 끝낸다.
    - 한 줄만 쓴다. 설명, 따옴표, 마침표, 번호 없이.
    - 할 일에 없는 사람·장소·숫자는 지어내지 않는다.
    예: 보고서 쓰기 → 문서 열고 제목만 쓰기
    예: 운동 → 운동화 꺼내 신기
    예: 엄마한테 전화 → 연락처에서 엄마 찾아 두기
    """

    /// 큰일을 걸음으로. 날짜는 묻지 않는다 — 날은 규칙이 놓는다.
    /// 견준 것(AI.md 15절): 규칙만 적은 짧은 지시문은 "문 설치하기 · 갱신 완료하기" 같은 빈 걸음이 많았고,
    /// 첫·가운데·마지막 걸음의 구실과 예시 둘을 준 쪽이 나았다. 다섯까지 두면 늘 다섯을 채워서 넷까지만.
    static let breakdown = """
    너는 큰일 앞에서 막막한 사람을 돕는 도우미야. 할 일 하나를 받으면, 실제로 그 일을 해 본 사람이 하는 순서대로 걸음을 나눠.
    - 첫 걸음은 지금 바로 할 수 있는 가장 쉬운 행동이야. 알아보기, 적어 보기, 꺼내 두기 같은 것.
    - 가운데 걸음은 그 일의 몸통이야. 무엇을 하는지 눈에 보이게 쓴다.
    - 마지막 걸음은 그 일이 정말 끝나는 행동이야. 보내기, 내기, 예약하기, 치우기 같은 것.
    - 걸음마다 15자 안팎, "~기"로 끝낸다. 할 일에 없는 사람·장소·날짜·숫자는 지어내지 않는다.
    예: 친구 집들이 선물 사기 → 친구가 좋아하는 것 떠올리기 / 쓸 돈 정하기 / 후보 두 개 고르기 / 주문하기
    예: 자동차 보험 갱신 → 지금 보험 증권 찾아 두기 / 다른 보험사 견적 받기 / 조건 견주기 / 가입하기
    """

    /// 걱정 나무(내 손 안 / 밖) 판단만. 위로 문장은 모델에게 맡기지 않는다 (하네스에서 "너는 소중한 사람이야" 같은 뜬구름).
    /// 예시는 '손 안' 둘 · '손 밖' 둘 — 하나씩이면 모든 걱정을 '손 안'으로 봤다 (하네스 10/10).
    static let worry = """
    너는 걱정을 같이 들여다보는 차분한 도우미야. 걱정 하나를 받으면, 그 걱정에 대해 오늘 2분 안에 내가 직접 할 수 있는 확인이나 준비가 있는지 본다.
    - 있으면 inMyHands는 true, step은 그 걱정에 바로 닿는 아주 작은 확인·준비 하나 (20자 안팎, "~하기"로 끝).
    - 남의 마음, 아직 안 나온 결과, 날씨처럼 내가 바꿀 수 없으면 inMyHands는 false, step은 빈 문자열.
    걱정에 없는 사람·장소를 지어내지 않는다. 약·치료·투자·법률에 대한 조언은 하지 않는다.
    예: 월세 오르면 어떡하지 → true, 계약서에서 만료일 확인하기
    예: 발표 망하면 어떡하지 → true, 첫 장을 소리 내어 읽어 보기
    예: 내일 비 오면 어쩌지 → false
    예: 동료들이 날 어떻게 생각할까 → false
    """

    /// 사진에서 일정을 찾는다. 글자 인식 결과를 같이 줘서 글자는 거기서 베끼게 한다.
    static let photo = """
    너는 사진에 적힌 일정과 할 일을 찾아 주는 도우미야. 포스터, 안내문, 진료 예약 카드, 시간표, 손으로 쓴 목록 사진을 본다.
    - title: 그 일정이나 할 일의 이름. 사진에 적힌 글자를 그대로 베낀다. 짧게.
    - month, day: 그 일에 적힌 날짜. 날짜가 안 적혀 있으면 둘 다 0.
    - hour, minute: 적힌 시각을 24시간으로(오후 7시 → 19). 시각이 없으면 hour 는 -1, minute 는 0.
    날짜와 제목이 사진에서 떨어져 있어도 같은 일정이면 하나로 묶는다. 일정이 여러 개면 하나씩 따로.
    가격, 주소, 전화번호, 주최, 광고 문구는 일정이 아니다. 사진에 없는 것을 지어내지 마.
    """

    /// 시키는 말을 줄마다 읽는다. 무엇을 바꿀지 정하지 않는다 — 동작의 종류와 가리킨 이름만.
    static let command = """
    너는 할 일 앱에 시키는 말을 읽는 도우미야. 번호가 붙은 줄마다 사용자가 무엇을 하려는지 읽어.
    - kind: 새 일을 넣으려는 말이면 add, 이미 있는 일을 끝냈다는 말이면 done, 다른 날이나 시각으로 옮기려는 말이면 move, 없애려는 말이면 delete.
    - target: 그 줄이 가리키는 일의 이름. 줄에 있는 낱말을 그대로 베낀다. 날짜·시각이나 '미뤄, 끝냈어, 지워' 같은 말은 넣지 않는다.
    줄 수만큼 순서대로 답한다. 줄에 없는 것을 지어내지 마.
    """

    /// 물음을 읽기만 한다. 답을 말하게 하지 않는다 — 답은 기록에서 규칙이 찾는다.
    static let find = """
    너는 할 일 앱의 검색 도우미야. 사용자의 물음을 읽고 무엇을 찾는지만 정리해. 답을 지어내지 마.
    - words: 찾으려는 일의 이름에 들어갈 낱말. 물음에 있는 낱말을 그대로 베낀다. 때를 가리키는 말(다음 주, 언제)이나 '약속·할 일' 같은 말은 넣지 않는다. 없으면 빈 목록.
    - span: 물음이 가리키는 때. 말하지 않았으면 any. 지난 일을 물으면(언제였지, 했더라) past.
    - state: 끝낸 것을 물으면 done, 남은 것·해야 할 것을 물으면 open, 아니면 any.
    - kind: 시각이 있는 약속을 물으면 event, 걱정을 물으면 worry, 나중에 미뤄 둔 것을 물으면 later, 아니면 any.
    """

    /// 고르기만 한다. 목록은 사용자의 실제 기록이고, 모델은 거기서 베끼기만 한다.
    static let pick = """
    너는 할 일 앱의 검색 도우미야. 목록은 사용자가 적어 둔 일이야. 물음이 찾는 갈래에 드는 일을 목록에서 골라 이름을 글자 그대로 베껴.
    - 물음의 낱말이 이름에 없어도 뜻이 그 갈래면 고른다. 이름만 달리 부른 같은 일, 그 갈래 안의 일이 여기에 든다.
    - 목록을 처음부터 끝까지 하나씩 본다. 그 갈래가 아닌 일은 고르지 않는다. 맞는 일이 없으면 빈 목록.
    - 목록에 없는 이름을 쓰지 않는다.
    """

    /// 남이 보낸 글에서 받는 사람이 챙길 것만. 때는 계산하지 않고 글에서 베낀다.
    static let capture = """
    너는 남이 보낸 메시지, 메일, 공지를 읽고 받는 사람이 챙겨야 할 약속과 할 일만 찾아 주는 도우미야.
    - title: 그 약속이나 할 일의 이름. 글에 있는 낱말로 짧게 쓴다. 날짜와 시각은 넣지 않는다.
    - when: 그 일에 대해 글에 적힌 날짜와 시각 말을 글자 그대로 베낀다. 날짜를 계산하거나 바꾸지 않는다. 없으면 빈 문자열.
    약속이 여러 개면 하나씩 따로. 인사, 잡담, 가격, 전화번호, 주문·결제·발송 알림처럼 챙길 일이 없는 글이면 빈 목록. 글에 없는 일을 지어내지 마.
    """

    static let fits = """
    너는 할 일 앱의 검색 결과를 검사해. 일 하나와 물음을 보고, 그 일이 물음이 찾는 갈래에 드는지 답해.
    - fits: 그 일이 물음의 갈래에 드는 일이면 true, 다른 갈래의 일이면 false.
    """

    static let unrelated = """
    너는 할 일 앱의 검색 결과를 검사해. 사용자가 찾는 것과 일 하나를 보고 둘의 사이를 골라.
    - same: 사용자가 찾는 바로 그 일이다 (이름만 달리 불렀다).
    - kind: 사용자가 찾는 갈래 안에 드는 일이다.
    - other: 다른 갈래의 일이다. 낱말이 비슷하거나 조금 이어져 있을 뿐이다.
    """

    static func when(today: DayKey) -> String {
        let names = ["", "일", "월", "화", "수", "목", "금", "토"]
        let days = (0..<45).map { today.adding(days: $0) }.map { "\($0.m)월 \($0.d)일 \(names[$0.weekday()])" }
        return """
        너는 한국어 한 줄에서 날짜나 때를 말한 부분을 찾아 표준 꼴로 바꾸는 도우미야.
        오늘은 \(today.y)년 \(days[0])요일이다. 앞으로의 달력: \(days.joined(separator: ", "))
        - phrase: 입력에서 날짜나 때를 말한 부분을 글자 그대로 베낀다.
        - canonical: 그 부분을 "M월 D일", "아침", "낮", "저녁", "H시", "H시 M분" 중 하나나 조합으로 바꾼다.
        - 날짜를 하나로 정할 수 없는 말(조만간, 시험 끝나고, 언젠가, 다음에)이면 phrase와 canonical 둘 다 빈 문자열.
        - 입력에 없는 날짜를 지어내지 않는다.
        """
    }
}

// MARK: - 생성 (iOS 26+)

#if canImport(FoundationModels)

@available(iOS 26.0, macOS 26.0, *)
@Generable private enum GBin: String {
    case now, date, worry, drop
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GCard {
    @Guide(description: "짧게 다시 쓴 한 줄. 사용자의 말 그대로, 뜻은 바꾸지 않는다. 날짜·시각 낱말은 남긴다.")
    var text: String
    var bin: GBin
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GDump {
    @Guide(description: "머릿속에서 꺼낸 것들. 입력에 있는 것만, 입력 순서대로.", .maximumCount(30))
    var items: [GCard]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GOne {
    var bin: GBin
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GWorry {
    @Guide(description: "지금 내가 직접 할 수 있는 부분이 있나")
    var inMyHands: Bool
    @Guide(description: "2분 안에 할 수 있는 아주 작은 확인·준비 하나. 없으면 빈 문자열")
    var step: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GBreak {
    @Guide(description: "순서대로 놓은 걸음. 하나씩 짧게.", .minimumCount(3), .maximumCount(4))
    var steps: [String]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GWhen {
    @Guide(description: "입력에서 날짜나 때를 말한 부분을 그대로 베낀 것. 없으면 빈 문자열")
    var phrase: String
    @Guide(description: "표준 꼴: M월 D일 · 아침 · 낮 · 저녁 · H시 · H시 M분. 없으면 빈 문자열")
    var canonical: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private enum GSpan: String {
    case any, today, tomorrow, yesterday, thisWeek, nextWeek, lastWeek, thisMonth, lastMonth, upcoming, past
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private enum GState: String { case any, open, done }

@available(iOS 26.0, macOS 26.0, *)
@Generable private enum GKind: String { case any, event, todo, worry, later }

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GFind {
    @Guide(description: "찾는 일의 이름에 들어갈 낱말. 물음에서 그대로 베낀 것만.", .maximumCount(3))
    var words: [String]
    var span: GSpan
    var state: GState
    var kind: GKind
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GPick {
    @Guide(description: "물음과 뜻이 맞는 일의 이름. 목록에서 글자 그대로 베낀다. 없으면 빈 목록.", .maximumCount(12))
    var names: [String]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GTask {
    @Guide(description: "약속이나 할 일의 이름. 글에 있는 낱말로 짧게. 날짜·시각은 넣지 않는다.")
    var title: String
    @Guide(description: "글에 적힌 날짜·시각 말을 그대로. 없으면 빈 문자열.")
    var when: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GTasks {
    @Guide(.maximumCount(8))
    var items: [GTask]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GYes {
    var fits: Bool
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private enum GRel: String { case same, kind, other }

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GOff {
    var relation: GRel
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private enum GAct: String { case add, done, move, delete }

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GStep {
    @Guide(description: "몇 번째 줄인가 (1부터)")
    var line: Int
    var kind: GAct
    @Guide(description: "그 줄이 가리키는 일의 이름. 줄에서 그대로 베낀 낱말.")
    var target: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GSteps {
    @Guide(description: "줄마다 하나씩, 순서대로", .maximumCount(12))
    var items: [GStep]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GEvent {
    @Guide(description: "일정이나 할 일의 이름. 사진에 적힌 글자 그대로.")
    var title: String
    @Guide(description: "달 1~12. 날짜가 없으면 0", .range(0...12))
    var month: Int
    @Guide(description: "날 1~31. 날짜가 없으면 0", .range(0...31))
    var day: Int
    @Guide(description: "시 0~23 (24시간). 시각이 없으면 -1", .range(-1...23))
    var hour: Int
    @Guide(description: "분 0~59", .range(0...59))
    var minute: Int
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GEvents {
    @Guide(description: "사진에 적힌 일정과 할 일. 사진에 있는 것만.", .maximumCount(12))
    var items: [GEvent]
}

@available(iOS 26.0, macOS 26.0, *)
private enum Gen {
    /// 나누기·고르기는 늘 같은 답이 나오게
    static let greedy = GenerationOptions(samplingMode: .greedy)

    static func bin(_ g: GBin) -> DumpBin { DumpBin(rawValue: g.rawValue) ?? .date }

    static func organize(_ text: String, warm: AnyObject?) async throws -> [BrainRules.Draft] {
        let session = (warm as? LanguageModelSession) ?? LanguageModelSession(instructions: Prompt.organize)
        let r = try await session.respond(to: text, generating: GDump.self, options: greedy)
        return r.content.items.map { BrainRules.Draft(text: $0.text, bin: bin($0.bin)) }
    }

    /// 흘려 받기: 마지막 한 장은 아직 쓰는 중일 수 있으니, 그 앞 장까지만 '완성'으로 넘긴다.
    static func organizeStream(_ text: String, warm: AnyObject?, onDrafts: @escaping @Sendable ([BrainRules.Draft]) async -> Void) async throws -> [BrainRules.Draft] {
        let session = (warm as? LanguageModelSession) ?? LanguageModelSession(instructions: Prompt.organize)
        var sent = 0
        var last: [BrainRules.Draft] = []
        for try await snap in session.streamResponse(to: text, generating: GDump.self, options: greedy) {
            let items = snap.content.items ?? []
            let done: [BrainRules.Draft] = items.compactMap { it in
                guard let t = it.text, let b = it.bin, !t.isEmpty else { return nil }
                return BrainRules.Draft(text: t, bin: bin(b))
            }
            last = done
            // 마지막 장은 글이 아직 늘어나는 중일 수 있다 → 그 앞까지만
            let settled = max(0, done.count - 1)
            if settled > sent {
                sent = settled
                await onDrafts(Array(done.prefix(settled)))
            }
        }
        return last
    }

    static func card(_ line: String) async throws -> BrainRules.Draft {
        let session = LanguageModelSession(instructions: Prompt.card)
        let r = try await session.respond(to: "카드: \(line)", generating: GOne.self, options: greedy)
        return BrainRules.Draft(text: line, bin: bin(r.content.bin))
    }

    static func text(_ instructions: String, _ prompt: String, max: Int) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let r = try await session.respond(to: prompt, options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: max))
        return r.content
    }

    static func worry(_ text: String) async throws -> WorryAdvice {
        let session = LanguageModelSession(instructions: Prompt.worry)
        let r = try await session.respond(to: "걱정: \(text)", generating: GWorry.self, options: greedy)
        let step = r.content.step.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorryAdvice(inMyHands: r.content.inMyHands, step: step.isEmpty ? nil : step, line: "", crisis: false)
    }

    @available(iOS 27.0, macOS 27.0, *)
    static func photo(_ image: CGImage, ocr: String) async throws -> [BrainRules.SeenEvent] {
        let session = LanguageModelSession(instructions: Prompt.photo)
        let r = try await session.respond(to: FoundationModels.Prompt {
            "이 사진에서 일정과 할 일을 찾아 줘."
            Attachment(image)
            "글자 인식으로 읽은 글자 (틀린 글자가 있을 수 있다):\n\(ocr)"
        }, generating: GEvents.self, options: greedy)
        return r.content.items.map { BrainRules.SeenEvent(title: $0.title, month: $0.month, day: $0.day, hour: $0.hour, minute: $0.minute) }
    }

    static func command(_ pieces: [String]) async throws -> [CommandReading?] {
        let session = LanguageModelSession(instructions: Prompt.command)
        let numbered = pieces.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let r = try await session.respond(to: numbered, generating: GSteps.self, options: greedy)
        var out = [CommandReading?](repeating: nil, count: pieces.count)
        for s in r.content.items where (1...pieces.count).contains(s.line) && out[s.line - 1] == nil {
            out[s.line - 1] = CommandReading(kind: CommandStep.Kind(rawValue: s.kind.rawValue) ?? .add, target: s.target)
        }
        return out
    }

    static func find(_ question: String) async throws -> FindQuery {
        let session = LanguageModelSession(instructions: Prompt.find)
        let r = try await session.respond(to: "물음: \(question)", generating: GFind.self, options: greedy)
        return FindQuery(words: r.content.words, span: FindQuery.Span(rawValue: r.content.span.rawValue) ?? .any,
                         state: FindQuery.State(rawValue: r.content.state.rawValue) ?? .any,
                         kind: FindQuery.Kind(rawValue: r.content.kind.rawValue) ?? .any)
    }

    /// 목록을 다섯 가지 순서로 놓고 따로 고르게 해서 이름마다 몇 번 골랐는지 센다.
    /// 긴 목록에서 엉뚱하게 섞이는 것은 순서에 따라 달라지고, 뜻이 맞는 것은 순서와 상관없이 골라진다.
    /// need: 받아들이는 데 필요한 표 수. 남은 차례를 다 얻어도 못 닿는 이름뿐이면 일찍 멈춘다 (need 가 nil 이면 끝까지 — 연구용).
    static func pickVotes(_ question: String, titles: [String], need: Int?) async throws -> [String: Int] {
        func once(_ list: [String]) async throws -> Set<String> {
            let session = LanguageModelSession(instructions: Prompt.pick)
            let r = try await session.respond(to: "목록:\n" + list.map { "- \($0)" }.joined(separator: "\n") + "\n\n물음: \(question)", generating: GPick.self, options: greedy)
            return Set(r.content.names)
        }
        let n = titles.count, mid = n / 2, third = n / 3
        let evens = titles.enumerated().filter { $0.offset % 2 == 0 }.map(\.element), odds = titles.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        let orders: [[String]] = [titles, titles.reversed(), Array(titles[mid...] + titles[..<mid]), odds + evens, Array((titles[third...] + titles[..<third]).reversed())]
        var votes: [String: Int] = [:]
        for (i, list) in orders.enumerated() {
            for t in try await once(list) where titles.contains(t) { votes[t, default: 0] += 1 }
            let left = orders.count - i - 1
            // 아직 갈릴 수 있는 이름(모자라지만 남은 차례로 닿을 수 있는 것)이 없으면 더 묻지 않는다
            // 지금까지 매번 고른 이름이 있으면 끝까지 묻는다 — 다섯 번 다 고르면 검사 없이 받는다
            if let need, left < need, !votes.values.contains(where: { $0 < need && $0 + left >= need }), !votes.values.contains(i + 1) { break }
        }
        return votes
    }

    static func capture(_ text: String) async throws -> [CaptureRules.Found] {
        let session = LanguageModelSession(instructions: Prompt.capture)
        let r = try await session.respond(to: "글:\n\(text)", generating: GTasks.self, options: greedy)
        return r.content.items.map { CaptureRules.Found(title: $0.title, when: $0.when) }
    }

    /// 거꾸로 묻는다: 이 일은 물음과 상관없는 일인가
    static func unrelated(_ question: String, title: String) async throws -> Bool {
        let session = LanguageModelSession(instructions: Prompt.unrelated)
        let r = try await session.respond(to: "찾는 것: \(question)\n일: \(title)", generating: GOff.self, options: greedy)
        return r.content.relation == .other
    }

    /// 일 하나만 놓고 묻는다: 이 일이 물음의 갈래에 드나
    static func fits(_ question: String, title: String) async throws -> Bool {
        let session = LanguageModelSession(instructions: Prompt.fits)
        let r = try await session.respond(to: "물음: \(question)\n일: \(title)", generating: GYes.self, options: greedy)
        return r.content.fits
    }

    static func breakdown(_ subject: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: Prompt.breakdown)
        let r = try await session.respond(to: "할 일: \(subject)", generating: GBreak.self, options: greedy)
        return r.content.steps
    }

    static func when(_ text: String, today: DayKey) async throws -> [String] {
        let session = LanguageModelSession(instructions: Prompt.when(today: today))
        let r = try await session.respond(to: "입력: \(text)", generating: GWhen.self, options: greedy)
        return [r.content.phrase, r.content.canonical]
    }
}

#endif

// MARK: - 한 주 풀기 (도구 호출)
// 모델이 스스로 도구를 불러 한 주를 본다: seeWeek(칸마다 빈 시간·넘침) → seeTodos(그날의 할 일, 번호) → 미룰 일과 지킬 일을 가른다.
// 도구가 돌려주는 글은 전부 ReplanRules 가 실제 기록으로 만든다. 모델의 안은 ReplanRules.check 가 다시 기록에 댄다.

/// 도구가 불릴 때마다 적는다 (화면의 '보는 과정'과 평가의 호출 수)
final class ReplanLog: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private let onTrace: @Sendable (ReplanTrace) -> Void
    init(onTrace: @escaping @Sendable (ReplanTrace) -> Void) { self.onTrace = onTrace }
    func note(_ kind: ReplanTrace.Kind, _ text: String) {
        lock.lock(); count += 1; lock.unlock()
        onTrace(ReplanTrace(kind: kind, text: text, fromAI: true))
    }
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    private var failure: String?
    /// 모델 호출이 던진 오류 (평가에서 왜 규칙으로 넘어갔는지 본다)
    func fail(_ e: String) { lock.lock(); failure = String(e.prefix(300)); lock.unlock() }
    var error: String? { lock.lock(); defer { lock.unlock() }; return failure }
}

extension Brain {
    /// 모델이 도구로 한 주를 보고 가른 것 (검사 전): 미뤄도 되는 일의 번호(쉬운 것부터) · 그 자리에서 해야 하는 일의 번호.
    /// 어디로 옮길지는 모델이 정하지 않는다 — 빈 시간 셈은 규칙이 한다 (모델에게 맡겼더니 제자리로 옮기는 안만 냈다).
    @concurrent nonisolated static func aiReplan(_ text: String, snapshot: ReplanSnapshot, log: ReplanLog) async throws -> (later: [Int], keep: [Int]) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return try await ReplanGen.plan(text, snapshot: snapshot, log: log) }
        #endif
        throw Unavailable()
    }
}

#if canImport(FoundationModels)

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GWeekArgs {
    @Guide(description: "오늘부터 며칠을 볼지", .range(1...7))
    var days: Int
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GDayArgs {
    @Guide(description: "볼 날. 오늘, 내일, 또는 요일(월요일 … 일요일)")
    var day: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GReplan {
    @Guide(description: "넘치는 칸에서 다른 때로 미뤄도 괜찮은 할 일의 번호. 미루기 쉬운 것부터. seeTodos 에서 본 번호만.", .maximumCount(8))
    var later: [Int]
    @Guide(description: "그 자리에서 꼭 해야 해서 옮기면 안 되는 할 일의 번호. seeTodos 에서 본 번호만.", .maximumCount(8))
    var keep: [Int]
}

/// 도구 1: 한 주의 짐
@available(iOS 26.0, macOS 26.0, *)
private struct WeekTool: Tool {
    let snapshot: ReplanSnapshot
    let log: ReplanLog
    let name = "seeWeek"
    let description = "오늘부터 7일 동안 아침·낮·저녁 칸마다 빈 시간이 얼마나 남았는지, 어느 칸이 넘치는지 본다."
    func call(arguments: GWeekArgs) async throws -> String {
        let over = snapshot.cells.filter { $0.overflow > 0 }
        log.note(.week, over.isEmpty ? "한 주의 빈 시간을 봤어. 넘치는 칸은 없어."
                                     : "한 주의 빈 시간을 봤어. " + over.prefix(3).map { "\(snapshot.short($0.day, $0.part)) \(Fmt.dur($0.overflow)) 넘침" }.joined(separator: " · "))
        return ReplanRules.weekText(snapshot, days: 7)
    }
}

/// 도구 2: 그날의 옮길 수 있는 할 일 (번호)
@available(iOS 26.0, macOS 26.0, *)
private struct TodosTool: Tool {
    let snapshot: ReplanSnapshot
    let log: ReplanLog
    let name = "seeTodos"
    let description = "어느 하루의 옮길 수 있는 할 일을 번호·칸·길이와 함께 본다. 옮기려면 먼저 이걸로 번호를 알아야 한다."
    func call(arguments: GDayArgs) async throws -> String {
        guard let day = snapshot.day(named: arguments.day) else { return "그런 날은 없어. 오늘, 내일, 또는 요일로 다시 말해." }
        let n = snapshot.todos.filter { $0.entry.day == day }.count
        log.note(.todos, "\(snapshot.short(day, .morning).split(separator: " ")[0])의 할 일 \(n)개를 봤어.")
        return ReplanRules.todosText(snapshot, day: day)
    }
}

@available(iOS 26.0, macOS 26.0, *)
private enum ReplanGen {
    static let instructions = """
    너는 사용자의 한 주를 풀어 주는 도우미야. 반드시 도구를 써서 사실을 본 다음에 답해.
    1. seeWeek 로 한 주를 본다.
    2. 넘치는 날(또는 사용자가 말한 날)을 seeTodos 로 봐서 할 일과 번호를 안다.
    3. 그날의 할 일을 둘로 가른다. later: 다른 때 해도 괜찮은 일. keep: 그날 그 자리에서 해야 하는 일.
    때가 걸린 일(마감 · 제출 · 예약 · 약속 준비 · 누가 기다리는 일)과 사용자가 꼭 하겠다거나 그대로 두라고 한 일, '오늘의 하나'는 keep. 언제 해도 되는 일은 later.
    넘친 시간만큼은 덜어야 해 — later 에 넣은 일의 길이를 더하면 넘친 시간보다 길어야 한다. 모자라면 keep 가운데 그나마 덜 급한 것을 later 로 옮겨.
    어디로 옮길지는 정하지 않아도 돼. 번호는 seeTodos 에서 본 것만 써.
    """

    /// 도구 없이: 같은 사실을 글로 넣어 주고 가르기만 시킨다
    static let direct = """
    너는 사용자의 한 주를 풀어 주는 도우미야. 아래에 한 주의 빈 시간과 넘치는 날의 할 일이 번호와 함께 있어.
    그 할 일을 둘로 갈라. later: 다른 때 해도 괜찮은 일. keep: 그날 그 자리에서 해야 하는 일.
    때가 걸린 일(마감 · 제출 · 예약 · 약속 준비 · 누가 기다리는 일)과 사용자가 꼭 하겠다거나 그대로 두라고 한 일, '오늘의 하나'는 keep. 언제 해도 되는 일은 later.
    넘친 시간만큼은 덜어야 해 — later 에 넣은 일의 길이를 더하면 넘친 시간보다 길어야 한다. 모자라면 keep 가운데 그나마 덜 급한 것을 later 로 옮겨.
    어디로 옮길지는 정하지 않아도 돼. 번호는 아래에 있는 것만 써.
    """

    static let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 300)

    static func plan(_ text: String, snapshot: ReplanSnapshot, log: ReplanLog) async throws -> (later: [Int], keep: [Int]) {
        let ask = "오늘은 \(snapshot.label(snapshot.today)). 사용자의 말: \(text)"
        // 1) 도구를 쥐여 주고 스스로 보게 한다
        let session = LanguageModelSession(tools: [WeekTool(snapshot: snapshot, log: log), TodosTool(snapshot: snapshot, log: log)], instructions: instructions)
        let first = try await session.respond(to: ask, generating: GReplan.self, options: options).content
        if log.calls > 0, !(first.later.isEmpty && first.keep.isEmpty) { return (first.later, first.keep) }
        // 2) 도구를 안 불렀거나 빈손이면 — 이 모델은 절반쯤 그런다 — 같은 사실을 넣어 주고 다시 묻는다
        let ruled = ReplanRules.read(text, snapshot: snapshot)
        let days = snapshot.days.filter { d in ruled.focus.contains(d) || (ruled.focus.isEmpty && snapshot.cells.contains { $0.day == d && $0.overflow > 0 }) }
        guard !days.isEmpty else { return (first.later, first.keep) }
        let facts = ReplanRules.weekText(snapshot) + "\n\n" + days.map { ReplanRules.todosText(snapshot, day: $0) }.joined(separator: "\n\n")
        let second = try await LanguageModelSession(instructions: direct).respond(to: facts + "\n\n" + ask, generating: GReplan.self, options: options).content
        return (second.later, second.keep)
    }
}
#endif

// MARK: - 받은 약속에 답장
// 모델은 문장만 쓴다. 날 · 시각 · 겹침 · 대신 되는 때는 ReplyRules 가 실제 기록으로 정해 facts 로 건네고, 쓴 문장은 ReplyRules.vet 이 다시 본다.

extension Brain {
    /// 세 가지 답장 문장 (검사 전): 수락 · 다른 시간 · 거절
    @concurrent nonisolated static func aiReply(_ facts: String) async throws -> [ReplyDraft.Kind: String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
            약속 제안에 보낼 답장을 써. 한두 문장으로 짧게, 사람이 메신저에 쓰듯이.
            말투는 적어 준 대로 맞춘다(반말이면 반말, 존댓말이면 존댓말). 이모지와 영어는 쓰지 않는다.
            날과 시각은 적어 준 것만 말한다. 다른 시각이나 장소를 지어내지 않는다.
            accept: 제안된 때에 좋다고 하는 답. alternative: 그때는 일정이 있어서 '대신 되는 때'가 어떠냐고 묻는 답. decline: 이번에는 어렵다고 부드럽게 거절하는 답.
            """)
            let r = try await session.respond(to: facts, generating: GReplies.self, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 220)).content
            return [.accept: r.accept, .alternative: r.alternative, .decline: r.decline]
        }
        #endif
        throw Unavailable()
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable private struct GReplies {
    @Guide(description: "제안된 때에 좋다고 하는 답장")
    var accept: String
    @Guide(description: "그때는 일정이 있어서 대신 되는 때를 제안하는 답장")
    var alternative: String
    @Guide(description: "이번에는 어렵다고 부드럽게 거절하는 답장")
    var decline: String
}
#endif
