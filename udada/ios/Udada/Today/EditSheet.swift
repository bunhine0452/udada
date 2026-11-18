import SwiftUI

/// 고치기: 아래에서 올라오는 시트. 닫으면 저장된다(따로 저장 버튼을 찾지 않게).
struct EditSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: Entry

    struct Form: Equatable {
        var title: String
        var note: String
        var day: DayKey?
        var part: Part
        var timeOn: Bool
        var time: Int
        var duration: Int
        var rule: RepeatRule?
        var lead: Int?
    }
    enum Scope: Hashable { case one, all }

    @State private var form: Form
    @State private var original: Form
    @State private var scope: Scope = .one
    @State private var askDelete = false
    @State private var finished = false
    @State private var pickingDate = false
    @State private var splitting: SplitRequest?
    @FocusState private var titleFocused: Bool

    init(entry: Entry) {
        self.entry = entry
        let f = Form(title: entry.title, note: entry.note, day: entry.day, part: entry.part, timeOn: entry.time != nil,
                     time: entry.time ?? EditSheet.suggestedTime(for: entry), duration: entry.duration, rule: nil, lead: nil)
        _form = State(initialValue: f)
        _original = State(initialValue: f)
    }

    /// 할 일에 처음 시각을 정할 때의 시작값: 오늘 지금 띠면 다음 30분 눈금, 아니면 그 띠의 무난한 시각
    private static func suggestedTime(for e: Entry) -> Int {
        let parts = Store.live?.settings.parts ?? DayParts()
        let now = Store.live?.now ?? Date()
        if e.day == DayKey(now) {
            let m = minuteOfDay(now)
            let next = (m / 30 + 1) * 30
            if parts.part(at: m) == e.part && next < parts.range(e.part).upperBound { return next }
        }
        let r = parts.range(e.part)
        let nice: Int
        switch e.part { case .morning: nice = 540; case .afternoon: nice = 840; case .evening: nice = 1140 }
        return min(max(nice, r.lowerBound), r.upperBound - 30)
    }

    /// 반복의 하루치 (아직 떼어 내지 않은)
    private var isSeriesOccurrence: Bool { if case .occurrence = entry.source { true } else { false } }
    /// 반복에서 이미 떼어 낸 하루 (그날만 고쳤거나 끝낸 것)
    private var isDetached: Bool { entry.repeating && !isSeriesOccurrence }

    var body: some View {
        if entry.isExternal {
            ExternalEventSheet(entry: entry)
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if isSeriesOccurrence {
                            VStack(alignment: .leading, spacing: 6) {
                                Picker("바꿀 범위", selection: $scope) {
                                    Text("이날만").tag(Scope.one)
                                    Text("반복 전체").tag(Scope.all)
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("edit.scope")
                                Text(scope == .one ? "\(Fmt.day(entry.day, today: store.today)) 것만 바뀌어. 다른 날은 그대로." : "앞으로 오는 날이 다 바뀌어.")
                                    .font(.system(.footnote))
                                    .foregroundStyle(Ink.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else if isDetached {
                            Label("반복 중 이날만 따로 고친 거야. 여기서 바꾸면 이날만 바뀌어.", systemImage: "repeat")
                                .font(.system(.footnote))
                                .foregroundStyle(Ink.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("이름", text: $form.title, axis: .vertical)
                                .font(.system(.title3, weight: .bold))
                                .foregroundStyle(Ink.text)
                                .focused($titleFocused)
                                .submitLabel(.done)
                                .onChange(of: form.title) { _, t in
                                    // 이름은 한 줄: 엔터는 줄바꿈 대신 '다 적었음'
                                    if t.contains("\n") {
                                        form.title = t.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                                        titleFocused = false
                                    }
                                }
                                .accessibilityIdentifier("edit.title")
                            Hairline()
                            TextField("메모", text: $form.note, axis: .vertical)
                                .font(.system(.body))
                                .foregroundStyle(Ink.text2)
                                .lineLimit(1...4)
                                .accessibilityIdentifier("edit.note")
                        }
                        .card()

                        group("날") {
                            Chip(title: "오늘", on: form.day == store.today) { form.day = store.today }
                            Chip(title: "내일", on: form.day == store.today.adding(days: 1)) { form.day = store.today.adding(days: 1) }
                            Chip(title: "나중에", on: form.day == nil) { form.day = nil; form.timeOn = false; form.rule = nil }
                            Chip(title: dayChipLabel, on: isOtherDay, id: "edit.otherday") { pickingDate = true }
                        }
                        .disabled(scope == .all)
                        .opacity(scope == .all ? 0.45 : 1)

                        group("때") {
                            ForEach(Part.allCases) { p in
                                Chip(title: p.name, on: !form.timeOn && form.day != nil && form.part == p, id: "edit.part.\(p.rawValue)") {
                                    form.part = p; form.timeOn = false
                                    if form.day == nil { form.day = store.today }
                                }
                            }
                            Chip(title: form.timeOn ? Fmt.hm(form.time) : "시각 정하기", on: form.timeOn, id: "edit.time") {
                                form.timeOn = true
                                if form.day == nil { form.day = store.today }
                            }
                        }
                        if form.timeOn {
                            DatePicker("시각", selection: timeBinding, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .clipped()
                                .accessibilityIdentifier("edit.wheel")
                        }

                        group("길이") {
                            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { m in
                                Chip(title: Fmt.dur(m), on: form.duration == m) { form.duration = m }
                            }
                        }

                        if !isDetached {
                            group("반복") {
                                Chip(title: "안 함", on: form.rule == nil) { setRule(nil) }
                                Chip(title: "매일", on: form.rule?.kind == .daily) { setRule(.daily) }
                                Chip(title: "평일", on: form.rule?.kind == .weekdays) { setRule(.weekdaysOnly) }
                                Chip(title: "매주", on: form.rule?.kind == .weekly) {
                                    setRule(.weekly([(form.day ?? store.today).weekday()]))
                                }
                                Chip(title: "매달", on: form.rule?.kind == .monthly) {
                                    setRule(.monthly((form.day ?? store.today).d))
                                }
                            }
                            if form.rule?.kind == .weekly { weekdayRow }
                        }

                        if form.timeOn {
                            group("알림") {
                                ForEach([0, 5, 10, 30, 60], id: \.self) { m in
                                    Chip(title: m == 0 ? "정각" : "\(Fmt.dur(m)) 전", on: (form.lead ?? store.settings.eventLead) == m) { form.lead = m }
                                }
                            }
                        }

                        if !entry.done && !entry.repeating {
                            // 큰일이면: Apple Intelligence 가 서너 걸음으로 나누고 마감 전 날들에 놓는다 (미리 보고 넣는다)
                            Button {
                                save()
                                splitting = SplitRequest(title: form.title, due: form.day, part: form.part)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: Brain.shared.isReady ? "apple.intelligence" : "list.bullet.indent")
                                    Text("작게 쪼개기")
                                }
                            }
                            .buttonStyle(FillButton(tone: .quiet, height: 48))
                            .disabled(form.title.trimmingCharacters(in: .whitespaces).count < 2)
                            .padding(.top, 4)
                            .accessibilityIdentifier("edit.split")
                        }

                        if !form.timeOn && !entry.done {
                            VStack(spacing: 8) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 8) { pinAndFocus }
                                    VStack(spacing: 8) { pinAndFocus }
                                }
                                Button { save(); store.toWorry(currentEntry()); finish() } label: {
                                    Text("걱정 상자로 옮기기")
                                }
                                .buttonStyle(FillButton(tone: .line, height: 48))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .background(Ink.ground)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(form.timeOn ? "약속 고치기" : "할 일 고치기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) { deleteTapped() } label: { Text("지우기").foregroundStyle(Ink.text2) }
                            .accessibilityIdentifier("edit.delete")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("됐어") { finish() }.fontWeight(.bold).foregroundStyle(Ink.accent)
                            .accessibilityIdentifier("edit.done")
                    }
                }
                .confirmationDialog("반복 일정이야", isPresented: $askDelete, titleVisibility: .visible) {
                    Button("이날만 지우기", role: .destructive) { finished = true; store.delete(entry); dismiss() }
                    Button("반복 전체 지우기", role: .destructive) { finished = true; store.delete(entry, wholeSeries: true); dismiss() }
                    Button("그만두기", role: .cancel) {}
                }
                .sheet(isPresented: $pickingDate) {
                    DateOnlyPicker(initial: (form.day ?? store.today).date()) { form.day = DayKey($0) }
                }
                .sheet(item: $splitting) { r in
                    BreakdownSheet(request: r) { finish() }.environment(store)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Ink.ground)
            .onAppear(perform: loadDetails)
            .onDisappear { save() }
            // 고치고 있는 할 일을 시스템에 알린다 (화면 인식: Siri 가 '이거'를 안다)
            .userActivity(OnScreen.taskActivity, isActive: entry.itemID != nil) { a in
                if let id = entry.itemID { OnScreen.annotate(a, itemID: id, title: entry.title) }
            }
        }
    }

    // MARK: 부품

    private func group<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text2)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { content() }.padding(.vertical, 1)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder private var pinAndFocus: some View {
        Button { save(); store.pin(currentEntry()); finish() } label: {
            Text(entry.pinned ? "하나에서 빼기" : "오늘의 하나로")
        }
        .buttonStyle(FillButton(tone: .quiet, height: 48))
        Button { save(); let e = currentEntry(); finish(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.cover = .focus(e) } } label: {
            Text("집중 시작")
        }
        .buttonStyle(FillButton(tone: .quiet, height: 48))
    }

    /// 요일 고르기: 일곱 칸이 폭을 나눠 갖는다 (작은 화면에서도 넘치지 않게). 큰 글자면 두 줄.
    private var weekdayRow: some View {
        let days = [2, 3, 4, 5, 6, 7, 1]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: typeSize.isAccessibilitySize ? 4 : 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days, id: \.self) { wd in
                let on = form.rule?.weekdays.contains(wd) ?? false
                Button {
                    Haptic.tick()
                    var set = Set(form.rule?.weekdays ?? [])
                    if on { set.remove(wd) } else { set.insert(wd) }
                    if set.isEmpty { set.insert(wd) }
                    form.rule = .weekly(Array(set))
                } label: {
                    Text(Fmt.weekday[wd])
                        .font(.system(.subheadline, weight: .semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: Metric.tap)
                        .foregroundStyle(on ? Ink.sheet : Ink.text)
                        .background(RoundedRectangle(cornerRadius: Metric.radiusChip, style: .continuous).fill(on ? Ink.text : Ink.fill))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("\(Fmt.weekday[wd])요일")
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("edit.wd.\(wd)")
            }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding {
            (form.day ?? store.today).date(minute: form.time)
        } set: { d in
            form.time = minuteOfDay(d)
            form.part = store.settings.parts.part(at: form.time)
        }
    }

    private var isOtherDay: Bool {
        guard let d = form.day else { return false }
        return d != store.today && d != store.today.adding(days: 1)
    }
    private var dayChipLabel: String {
        guard isOtherDay, let d = form.day else { return "날짜…" }
        return Fmt.day(d, today: store.today)
    }

    /// 반복 규칙을 바꾸는 것은 '반복 전체'의 일이다 — 하루치에서 고르면 범위를 전체로 넘긴다
    private func setRule(_ rule: RepeatRule?) {
        if form.day == nil { form.day = store.today }
        form.rule = rule
        if isSeriesOccurrence && scope == .one {
            withAnimation(.snappy) { scope = .all }
        }
    }

    private func loadDetails() {
        guard let id = entry.itemID, let it = store.data.item(id) else { return }
        form.rule = it.repeatRule
        form.lead = it.lead
        original = form
        if entry.title.isEmpty { titleFocused = true }
    }

    // MARK: 저장

    private func currentEntry() -> Entry {
        // 저장 뒤 같은 항목을 가리키는 Entry (반복 하루치는 떼어 낸 항목)
        if case .occurrence(let sid, let day) = entry.source, scope == .one,
           let it = store.data.items.first(where: { $0.seriesID == sid && $0.occurrence == day }) {
            var e = entry
            e.source = .item(it.id)
            return e
        }
        return entry
    }

    private func save() {
        guard !finished else { return }
        guard form != original else { return }
        let f = form
        let title = f.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        original = form
        let parts = store.settings.parts
        let scope = self.scope
        let occurrenceDay = entry.day
        store.change { data in
            func apply(_ it: inout Item, keepDay: Bool) {
                it.title = title
                it.note = f.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !keepDay { it.day = f.day }
                it.time = f.timeOn ? f.time : nil
                it.part = f.timeOn ? parts.part(at: f.time) : f.part
                it.duration = f.duration
                it.lead = f.lead
                it.movedFrom = nil
                if it.day == nil { it.time = nil; it.repeatRule = nil } else { it.repeatRule = f.rule }
            }
            switch entry.source {
            case .item(let id):
                data.update(id) { apply(&$0, keepDay: false) }
            case .occurrence(let sid, _):
                if scope == .all {
                    data.update(sid) { s in
                        if f.rule == nil {
                            // 반복을 그만두면 고른 그날 하루짜리로 남는다
                            apply(&s, keepDay: true)
                            s.day = occurrenceDay
                            s.exceptions = []
                        } else {
                            apply(&s, keepDay: true)
                        }
                    }
                } else if let nid = data.materialize(entry.source) {
                    data.update(nid) { apply(&$0, keepDay: false); $0.repeatRule = nil }
                }
            case .external:
                break
            }
        }
    }

    private func finish() {
        save()
        finished = true
        dismiss()
    }

    private func deleteTapped() {
        if isSeriesOccurrence || (entry.itemID.flatMap { store.data.item($0)?.isSeries } ?? false) {
            askDelete = true
        } else {
            finished = true
            store.delete(entry)
            dismiss()
        }
    }
}

/// 기기 달력 약속: 읽기만
struct ExternalEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let entry: Entry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: entry.color ?? 0x8B9691)).frame(width: 4, height: 20)
                    Text(entry.calendarName ?? "기기 달력").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                }
                Text(entry.title).font(.system(.title2, weight: .bold)).foregroundStyle(Ink.text)
                Text(entry.allDay ? "종일" : "\(Fmt.hm(entry.time ?? 0)) · \(Fmt.dur(entry.duration))")
                    .font(Typo.num(.title3))
                    .foregroundStyle(Ink.text)
                Text("기기 달력에 있는 약속이야. 고치려면 달력 앱에서.").font(.system(.subheadline)).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("달력 앱에서 보기") {
                    let t = entry.day.date(minute: entry.time ?? 0).timeIntervalSinceReferenceDate
                    if let u = URL(string: "calshow:\(t)") { openURL(u) }
                }
                .buttonStyle(FillButton(tone: .ink))
                .padding(.top, 6)
                Button("닫기") { dismiss() }.buttonStyle(FillButton(tone: .quiet))
            }
            .padding(Metric.gutter)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Ink.ground)
    }
}

/// 날짜 하나 고르기
struct DateOnlyPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    var onPick: (Date) -> Void
    init(initial: Date, onPick: @escaping (Date) -> Void) { _date = State(initialValue: initial); self.onPick = onPick }
    var body: some View {
        NavigationStack {
            DatePicker("날짜", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Ink.accent)
                .padding(.horizontal)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle("어느 날?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("고르기") { onPick(date); dismiss() }.fontWeight(.bold) }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Ink.sheet)
    }
}
