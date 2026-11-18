import AppIntents
import SwiftUI

// Siri·Spotlight 결과 안에 뜨는 작은 화면. iPhone 과 Mac 이 같이 쓴다.

// MARK: - 스니펫

/// "지금 뭐 해?" 결과: 큰 한 줄 + 할 일 하나
struct NowSnippet: View {
    var line: NowLine?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("지금").font(Typo.caption).foregroundStyle(Ink.text3)
                if let m = line?.minute { Text(Fmt.hm(m)).font(Typo.num(.caption)).foregroundStyle(Ink.text3) }
                Spacer()
            }
            Text(line?.headline ?? "오늘은 비어 있어")
                .font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(line.advice).font(.system(.subheadline)).foregroundStyle(Ink.text2)
                if let fit = line.fit {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(Ink.accent).frame(width: 4, height: 18)
                        Text(fit.title).font(Typo.row).foregroundStyle(Ink.text).lineLimit(1)
                        Spacer()
                        Text(Fmt.dur(fit.duration)).font(Typo.num(.footnote, .semibold)).foregroundStyle(Ink.text2)
                    }
                    .padding(.top, 2)
                    #if os(iOS)
                    // Siri·Spotlight 결과 안에서 바로: 끝냄(앱을 안 연다) · 집중(앱의 집중 화면으로)
                    HStack(spacing: 8) {
                        Button(intent: ToggleEntryIntent(entryID: fit.id)) {
                            Label("끝냄", systemImage: "checkmark").font(.system(.subheadline, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Ink.blockText)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.block))
                        Button(intent: UdadaControlOpenIntent(path: "focus")) {
                            Label("집중", systemImage: "play.fill").font(.system(.subheadline, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Ink.accentText)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.accent))
                    }
                    .padding(.top, 6)
                    #endif
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.sheet)
    }
}

/// "오늘 할 일" 결과: 세 띠, 띠마다 약속(시각)과 할 일 몇 개
struct TodaySnippet: View {
    var sheet: DaySheet
    private let perBand = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sheet.bands.enumerated()), id: \.element.id) { i, band in
                if i > 0 { Hairline() }
                row(band)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.sheet)
    }

    private func row(_ band: Band) -> some View {
        let open = band.todos.filter { !$0.done }
        let lines: [Entry] = Array((band.events.filter { !$0.done } + open).prefix(perBand))
        let more = band.events.filter { !$0.done }.count + open.count - lines.count
        return HStack(alignment: .top, spacing: 12) {
            Text(band.part.name)
                .font(Typo.serif(16, relativeTo: .headline))
                .foregroundStyle(band.live ? Ink.accent : (band.gone ? Ink.text3 : Ink.text))
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                if lines.isEmpty {
                    Text("비어 있음").font(.system(.subheadline)).foregroundStyle(Ink.text3)
                }
                ForEach(lines) { e in
                    HStack(spacing: 6) {
                        if let t = e.time {
                            Text(Fmt.hm(t)).font(Typo.num(.subheadline, .semibold)).foregroundStyle(Ink.text2)
                        } else {
                            RoundedRectangle(cornerRadius: 3).strokeBorder(Ink.text2, lineWidth: 1.5).frame(width: 12, height: 12)
                        }
                        Text(e.title).font(.system(.subheadline, weight: .medium)).foregroundStyle(Ink.text).lineLimit(1)
                    }
                }
                if more > 0 { Text("외 \(more)개").font(Typo.caption).foregroundStyle(Ink.text3) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

/// "우다다에서 찾기" 결과: 답 한 줄 + 찾은 것 몇 개 (전부 실제 기록)
struct FindSnippet: View {
    var answer: FindAnswer
    var today: DayKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(answer.line).font(Typo.serif(17, relativeTo: .headline)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(answer.hits.prefix(5)) { h in
                HStack(spacing: 8) {
                    Text(h.title).font(.system(.subheadline, weight: .medium)).foregroundStyle(h.done ? Ink.text3 : Ink.text).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(FindRules.when(h, today: today).trimmingCharacters(in: .whitespaces))
                        .font(Typo.num(.footnote, .semibold)).foregroundStyle(Ink.text2).lineLimit(1)
                }
            }
            if answer.hits.count > 5 { Text("외 \(answer.hits.count - 5)개").font(Typo.caption).foregroundStyle(Ink.text3) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.sheet)
    }
}
