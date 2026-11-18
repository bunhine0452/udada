import Foundation

// 딥링크 규약 — 위젯·알림·제어 센터·단축어가 앱을 이 주소로 연다.
//   udada://today                오늘 탭 (오늘 날짜)
//   udada://day/2026-11-15       그날의 하루 한 장
//   udada://add                  빠른 넣기 줄에 바로 커서
//   udada://add?text=치과%203시   넣기 줄을 채워서 연다 (확인 후 넣기)
//   udada://rest                 식히기 고르기
//   udada://rest/breath|far|walk 바로 시작
//   udada://focus                지금 줄이 고른 일로 집중
//   udada://dump                 비우기 (쏟아내기)
//   udada://dump/voice           말로 쏟아내기
//   udada://dump/photo           사진으로 넣기
//   udada://worry                걱정 시간
//   udada://close                하루 닫기
//   udada://gate                 숏폼 열기 전 '잠깐' 화면 (단축어 자동화)
//   udada://find?q=…            말로 찾기 (물음을 채워서)
//   udada://mind · udada://calendar · udada://records · udada://settings

extension Store {
    func open(_ url: URL) {
        guard url.scheme == "udada" else { return }
        let host = url.host() ?? ""
        let path = url.pathComponents.filter { $0 != "/" }
        // 주소로 온 한글은 풀어 쓴 꼴(NFD)일 수 있다 — 낱말 규칙(정규식)이 읽게 모아 쓴 꼴로 바꾼다
        let query = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { URLQueryItem(name: $0.name, value: $0.value?.precomposedStringWithCanonicalMapping) }
        cover = nil
        switch host {
        case "today":
            tab = .today
            selectedDay = today
        case "day":
            tab = .today
            if let s = path.first, let k = DayKey(string: s) { selectedDay = k }
        case "add":
            tab = .today
            selectedDay = today
            pendingAddText = query.first { $0.name == "text" }?.value ?? ""
            addFocusRequest += 1
        case "rest":
            tab = .today
            restStart = path.first.flatMap(RestKind.init(rawValue:))
            cover = .rest
        case "focus":
            tab = .today
            cover = .focus(sheet(for: today).now?.fit)
        case "dump":
            tab = .mind
            dumpMode = path.first == "voice" ? .voice : path.first == "photo" ? .photo : .text
            cover = .dump
        case "worry":
            tab = .mind
            cover = .worry
        case "close":
            tab = .today
            selectedDay = today
            cover = .close
        case "gate":
            tab = .today
            selectedDay = today
            cover = .gate
        case "find":
            // udada://find?q=다음 주 병원 — 물음을 채워서 연다
            pendingAddText = query.first { $0.name == "q" }?.value ?? ""
            cover = .find
        case "mind": tab = .mind
        case "calendar": tab = .calendar
        case "records": tab = .records
        case "settings":
            tab = .records
            showSettings = true
        default: break
        }
    }
}
