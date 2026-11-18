import SwiftUI
import UIKit

/// 받은 약속에 답장 (iPhone). 받은 글 → 내 일정에 대어 본 결과(그날의 띠 그림) → 답장 고르기 → 복사하고 약속 넣기.
/// 날 · 시각 · 겹침 · 대신 되는 때는 규칙이 실제 기록으로 정하고, Apple Intelligence 는 받은 글의 말투에 맞춰 문장만 쓴다.
struct ReplyView: View {
    var request: ReplyRequest

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var check: ReplyCheck?
    @State private var drafts: [ReplyDraft] = []
    @State private var picked: ReplyDraft.Kind?
    @State private var writing = false
    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("약속 답장").font(Typo.serif(28, relativeTo: .title)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("reply.close")
            }
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 받은 글
                    Text(request.text)
                        .font(.system(.body)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Ink.fill))
                        .frame(maxWidth: 300, alignment: .leading)
                        .accessibilityLabel("받은 글: \(request.text)")

                    if let c = check {
                        if shown >= 1 { verdict(c).transition(Motion.rise) }
                        if shown >= 2 { answers(c).transition(Motion.rise) }
                    } else {
                        Text("약속을 묻는 글이 아닌 것 같아. 날이나 시각이 있고 ‘어때’ · ‘볼래’처럼 묻는 글이면 답장을 써 줄게.")
                            .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("reply.none")
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 24)
            }

            if let c = check, let kind = picked, let d = drafts.first(where: { $0.kind == kind }) {
                let adds = ReplyRules.item(for: kind, check: c, parts: store.settings.parts, created: store.now) != nil
                Button(adds ? "복사하고 약속 넣기" : "답장 복사하기") { send(d, c) }
                    .buttonStyle(FillButton(tone: .accent))
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("reply.send")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .background(Ink.ground.ignoresSafeArea())
        .task { await work() }
    }

    // MARK: 내 일정에 대어 본 결과

    private func verdict(_ c: ReplyCheck) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: c.free ? "checkmark.circle.fill" : "calendar.badge.exclamationmark")
                    .font(.system(.title3, weight: .semibold)).foregroundStyle(Ink.text)
                    .accessibilityHidden(true)
                Text(ReplyRules.verdict(c)).font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reply.verdict")
            }
            ReplyDayStrip(check: c)
            if let a = c.alt {
                Text("대신 \((a.day == c.offer.day ? "" : ReplyRules.dayWord(a.day, today: c.today) + " ") + Fmt.hm(a.time))부터는 비어 있어.")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.accent)
            }
            Text("내 일정을 직접 보고 답했어. 기기 밖으로 나가는 건 없어.").font(Typo.meta).foregroundStyle(Ink.text3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
    }

    // MARK: 답장 고르기

    private func answers(_ c: ReplyCheck) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                if drafts.contains(where: \.fromAI) { AIBadge(text: "Apple Intelligence가 말투에 맞춰 썼어") }
                else if writing { ThinkingLine(text: "말투에 맞춰 다시 쓰는 중…") }
                Spacer(minLength: 0)
            }
            ForEach(drafts) { d in
                let on = picked == d.kind
                Button {
                    Haptic.tick()
                    withAnimation(reduceMotion ? nil : Motion.quick) { picked = d.kind }
                } label: {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(d.label).font(.system(.caption, weight: .bold)).foregroundStyle(on ? Ink.accent : Ink.text3)
                        Text(d.text)
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(on ? Ink.accentText : Ink.text)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? Ink.accent : Ink.sheet))
                            .contentTransition(.opacity)
                    }
                    .frame(maxWidth: 320, alignment: .trailing)
                }
                .buttonStyle(PressStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(d.label): \(d.text)")
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("reply.draft.\(d.kind.rawValue)")
            }
        }
    }

    // MARK: 하기

    private func work() async {
        guard let offer = ReplyRules.offer(from: request.text, now: store.now) else { return }
        let c = ReplyRules.check(offer, data: store.data, external: store.external, now: store.now)
        check = c
        drafts = ReplyRules.drafts(c)
        picked = drafts.first?.kind
        // 받은 글 → 일정 확인 → 답장, 한 박자씩
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(reduceMotion ? nil : Motion.page) { shown = 1 }
        Haptic.soft()
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(reduceMotion ? nil : Motion.page) { shown = 2 }
        guard Brain.shared.isReady else { return }
        writing = true
        let better = await Brain.shared.polish(c)
        writing = false
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : Motion.soft) { drafts = better }
    }

    private func send(_ d: ReplyDraft, _ c: ReplyCheck) {
        UIPasteboard.general.string = d.text
        if let item = ReplyRules.item(for: d.kind, check: c, parts: store.settings.parts, created: store.now) {
            store.change(undo: "답장을 복사하고 ‘\(item.title)’ \(ReplyRules.dayWord(item.day ?? c.today, today: c.today)) \(Fmt.hm(item.time ?? 0))에 넣었어") { $0.add(item) }
            Task { _ = await Notifier.requestPermission() }
            store.tab = .today
            if let day = item.day { store.selectedDay = day }
        } else {
            store.show("답장을 복사했어. 메시지에 붙여 넣어.")
        }
        // 받아 둔 것에서 온 글이면 치운다
        if let u = request.source { Inbox.remove([u]); store.inboxCount = Inbox.items().count }
        Haptic.success()
        dismiss()
    }
}

/// 그날의 띠 그림 (9시–23시): 내 약속은 먹색 덩어리, 제안된 때는 코발트 테두리(겹치면 빗금 대신 점선), 대신 되는 때는 코발트로 찬다.
private struct ReplyDayStrip: View {
    var check: ReplyCheck
    private let from = 9 * 60, to = 23 * 60
    /// 그 시각의 가로 자리
    private func x(_ m: Int, _ w: CGFloat) -> CGFloat { w * CGFloat(min(max(m, from), to) - from) / CGFloat(to - from) }

    var body: some View {
        let o = check.offer
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Ink.fill)
                    ForEach(check.events) { e in
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.block)
                            .frame(width: max(6, x(e.end ?? 0, w) - x(e.time ?? 0, w)), height: g.size.height)
                            .offset(x: x(e.time ?? 0, w))
                    }
                    if let a = check.alt, a.day == o.day {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.accent)
                            .frame(width: max(6, x(a.time + o.duration, w) - x(a.time, w)), height: g.size.height)
                            .offset(x: x(a.time, w))
                    }
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Ink.accent, style: StrokeStyle(lineWidth: 2.5, dash: check.free ? [] : [5, 4]))
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(check.free ? Ink.accentSoft : .clear))
                        .frame(width: max(8, x(o.time + o.duration, w) - x(o.time, w)), height: g.size.height)
                        .offset(x: x(o.time, w))
                }
            }
            .frame(height: 38)
            HStack {
                ForEach([9, 12, 15, 18, 21], id: \.self) { h in
                    Text("\(h)").font(Typo.num(.caption2, .semibold)).foregroundStyle(Ink.text3)
                    if h != 21 { Spacer(minLength: 0) }
                }
                Spacer(minLength: 0).frame(maxWidth: 30)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(check.events.isEmpty ? "그날은 약속이 없어" : "그날의 약속: " + check.events.map { "\(Fmt.hm($0.time ?? 0)) \($0.title)" }.joined(separator: ", "))
        .accessibilityIdentifier("reply.strip")
    }
}
