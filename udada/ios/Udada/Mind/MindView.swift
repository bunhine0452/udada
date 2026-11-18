import SwiftUI

/// 비우기 탭: 머릿속 거 쏟아내기(쓰기 · 말 · 사진) · 걱정 상자 · 나중에 함 · 지금까지 내려놓은 것
struct MindView: View {
    @Environment(Store.self) private var store
    @State private var showLater = false
    @AppStorage(FlowMemory.draftKey) private var draft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(title: "비우기", sub: "머릿속 걸 꺼내서 하나씩 자리를 정하면 머리가 조용해져.")
                    .padding(.top, 8)
                if store.inboxCount > 0 { InboxCard().transition(Motion.rise) }
                dumpCard
                worryCard
                laterCard
                totals
                aiNote
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, Metric.gutter)
        }
        .background(Ink.ground.ignoresSafeArea())
        .overlay(alignment: .bottom) { ToastLayer().padding(.bottom, 12) }
        .sheet(isPresented: $showLater) { LaterSheet() }
        .onAppear { FlowMemory.prepare() }
    }

    private func start(_ mode: DumpMode) {
        store.dumpMode = mode
        store.cover = .dump
    }

    private var dumpCard: some View {
        let leftLines = BrainRules.split(draft).count
        return VStack(alignment: .leading, spacing: 12) {
            Text("쏟아내기").font(Typo.serif(26, relativeTo: .title)).foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
            Text("할 일, 걱정, 생각난 거 전부. 맞춤법도 순서도 상관없어. 꺼낸 뒤엔 한 장씩 자리만 정하면 돼.")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            if leftLines > 0 {
                Text("쓰던 게 \(leftLines)줄 남아 있어.").font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text)
                    .accessibilityIdentifier("dump.draft")
            }
            Button(leftLines > 0 ? "이어서 쏟아내기" : "쓰면서 쏟아내기") { start(.text) }
                .buttonStyle(FillButton(tone: .accent))
                .accessibilityIdentifier("dump.start")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { voiceKey; photoKey }
                VStack(spacing: 8) { voiceKey; photoKey }
            }
            if let last = store.data.dumps.last {
                Text("지난번 머리 소음 \(last.before) → \(last.after) · \(last.total)개 내려놓음")
                    .font(.system(.footnote)).foregroundStyle(Ink.text2)
                    .accessibilityIdentifier("dump.last")
            }
        }
        .card(padding: 18)
    }

    private var voiceKey: some View {
        Button { start(.voice) } label: { Label("말로", systemImage: "mic") }
            .buttonStyle(FillButton(tone: .quiet, height: 48))
            .accessibilityIdentifier("dump.voice")
    }

    private var photoKey: some View {
        Button { start(.photo) } label: { Label("사진으로", systemImage: "camera") }
            .buttonStyle(FillButton(tone: .quiet, height: 48))
            .accessibilityIdentifier("dump.photo")
    }

    private var worryCard: some View {
        let worries = store.data.worries
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("걱정 상자").font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Text("\(worries.count)").font(Typo.num(.title3)).foregroundStyle(Ink.text2)
                    .accessibilityLabel("\(worries.count)개")
                    .accessibilityIdentifier("worry.count")
                Spacer()
            }
            Text(store.settings.worryOn ? "내 손 밖의 걱정은 여기 모아 뒀다가 매일 \(Fmt.hm(store.settings.worryTime)) 걱정 시간에 10분만 봐." : "내 손 밖의 걱정은 여기 모아 뒀다가 정한 때에 10분만 봐.")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            if !worries.isEmpty {
                ForEach(worries.prefix(2)) { w in
                    Text("· \(w.title)").font(.system(.subheadline)).foregroundStyle(Ink.text).lineLimit(1)
                }
                if worries.count > 2 {
                    Text("그리고 \(worries.count - 2)개 더").font(.system(.footnote)).foregroundStyle(Ink.text3)
                }
                Button("지금 걱정 시간 열기") { store.cover = .worry }
                    .buttonStyle(FillButton(tone: .ink, height: 48))
                    .accessibilityIdentifier("worry.open")
            }
        }
        .card()
    }

    private var laterCard: some View {
        let later = store.data.laterItems
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("나중에 함").font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Text("\(later.count)").font(Typo.num(.title3)).foregroundStyle(Ink.text2)
                    .accessibilityLabel("\(later.count)개")
                Spacer()
                if !later.isEmpty {
                    Button("모두 보기") { showLater = true }.font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text)
                        .frame(minHeight: Metric.tap)
                        .accessibilityIdentifier("mind.later.all")
                }
            }
            if later.isEmpty {
                Text("날을 안 정한 일이 여기 모여. 지금은 비어 있어.").font(.system(.subheadline)).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(later.prefix(3)) { it in
                    let age = DayLogic.age(it, today: store.today)
                    HStack {
                        Text(it.title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text).lineLimit(1)
                        Spacer()
                        Text(age >= 10 ? "\(age)일째" : "\(age)일").font(Typo.num(.footnote, .semibold)).foregroundStyle(age >= 10 ? Ink.text : Ink.text3)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }

    private var totals: some View {
        let dumped = store.data.dumps.reduce(0) { $0 + $1.total }
        let closed = store.data.closes.reduce(0) { $0 + $1.tomorrow + $1.later + $1.dropped }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("지금까지 머리에서 내려놓은 것").font(.system(.subheadline)).foregroundStyle(Ink.text2)
            Spacer()
            Text("\(dumped + closed)").font(Typo.num(.title)).foregroundStyle(Ink.text)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mind.total")
    }

    private var aiNote: some View {
        HStack(spacing: 8) {
            if Brain.shared.isReady { AIBadge() }
            Text(Brain.shared.isReady ? "정리는 이 iPhone 의 Apple Intelligence 가 해. 밖으로 안 나가." : "정리 제안은 기기 안에서 규칙으로 해. 밖으로 안 나가.")
                .font(.system(.footnote)).foregroundStyle(Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("어떻게 해?") { store.showAITour = true }
                .font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.accent)
                .frame(minHeight: Metric.tap)
                .accessibilityIdentifier("mind.ai.tour")
        }
        .padding(.horizontal, 4)
    }
}
