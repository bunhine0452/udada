import SwiftUI

// 소개의 마지막 쪽: 필요한 것만 켜기. (쓰는 법은 움직이는 사용법 AITour 가 보여 준다)

/// 쪽 하나의 틀: 큰 제목 · 한 줄 설명 · 보기
private struct IntroPage<Content: View>: View {
    var id: Int
    var title: String
    var sub: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(Typo.serif(30, relativeTo: .largeTitle))
                        .foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(sub)
                        .font(.system(.body))
                        .foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("intro.page.\(id)")
    }
}

// MARK: - 필요한 것만 켜

struct IntroSetupPage: View {
    @Environment(Store.self) private var store
    @State private var notifyOn = false
    @State private var notifyAsked = false
    @State private var calendarOn = false
    @State private var calendarAsked = false

    var body: some View {
        IntroPage(id: 3, title: "필요한 것만 켜", sub: "안 켜도 다 쓸 수 있어. 나중에 설정에서 바꿔도 돼.") {
            VStack(spacing: 12) {
                SetupRow(symbol: "bell", title: "알림 켜기", sub: "약속 전에 한 번, 띠마다 한 번 묶어서.",
                         done: notifyOn, doneText: "켜짐", failed: notifyAsked && !notifyOn, id: "intro.notify") {
                    Task {
                        notifyOn = await Notifier.requestPermission()
                        notifyAsked = true
                        if notifyOn { Haptic.success() }
                    }
                }
                SetupRow(symbol: "calendar", title: "기기 달력 연결", sub: "달력의 약속을 띠에 같이 보여 줘.",
                         done: calendarOn, doneText: "연결됨", failed: calendarAsked && !calendarOn, id: "intro.calendar") {
                    Task {
                        let ok = await CalendarService.shared.requestAccess()
                        if ok {
                            store.setSettings { $0.calendarOn = true }
                            CalendarService.shared.refresh(store)
                            Haptic.success()
                        }
                        calendarOn = ok
                        calendarAsked = true
                    }
                }
                siriRow
                macRow
            }
        }
        .task {
            await Notifier.refreshStatus()
            notifyOn = Notifier.authorized
            calendarOn = CalendarService.shared.authorized && store.settings.calendarOn
        }
    }

    /// Mac 의 우다다와는 내 iCloud 로 알아서 맞춰진다
    private var macRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Mac 에서 이어서").font(Typo.row)
                Text("Mac 의 우다다에서 적으면 몇 초 뒤 여기 떠. 집중 시계도 이어져. 내 iCloud 로만 오가.")
                    .font(Typo.meta).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Ink.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro.mac")
    }

    /// 허락이 필요 없는 것: Siri 와 단축어는 처음부터 된다
    private var siriRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Siri에게 말로").font(Typo.row)
                Text("“우다다에 적어 줘”, “우다다 지금 뭐 해”. 켤 것 없이 바로 돼.")
                    .font(Typo.meta).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Ink.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro.siri")
    }
}

private struct SetupRow: View {
    var symbol: String
    var title: String
    var sub: String
    var done: Bool
    var doneText: String
    var failed: Bool
    var id: String
    var action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Typo.row)
                    Text(failed ? "허락이 없어도 괜찮아. 설정에서 다시 켤 수 있어." : sub)
                        .font(Typo.meta).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    if done && typeSize.isAccessibilitySize { doneLabel.padding(.top, 4) }
                }
                Spacer(minLength: 8)
                if done && !typeSize.isAccessibilitySize { doneLabel }
            }
            .foregroundStyle(Ink.text)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous)
                .strokeBorder(done ? Ink.text : Ink.rule, lineWidth: done ? 1.5 : 1))
        }
        .buttonStyle(PressStyle())
        .disabled(done)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? doneText : "")
        .accessibilityIdentifier(id)
    }

    private var doneLabel: some View {
        Label(doneText, systemImage: "checkmark")
            .font(.system(.subheadline, weight: .bold))
            .labelStyle(.titleAndIcon)
            .fixedSize()
    }
}
