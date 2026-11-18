import SwiftUI
import UniformTypeIdentifiers

// 설정 — 데이터 · 정보 · 근거.

// MARK: - 8. 데이터

struct SettingsDataSection: View {
    var store: Store
    @State private var confirmWipe = false

    var body: some View {
        Section {
            ShareLink(item: ExportFile(data: store.data, day: store.today), preview: SharePreview("우다다 데이터")) {
                Label("데이터 내보내기 (JSON)", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("settings.export")
            Button {
                let now = store.now
                store.change(undo: "예시로 채웠어") { $0 = Seed.day(now: now, keep: $0) }
                Haptic.tap()
            } label: {
                Label("예시로 채워 보기", systemImage: "square.on.square")
            }
            .accessibilityIdentifier("settings.seed")
            Button(role: .destructive) {
                confirmWipe = true
            } label: {
                Label("모두 지우기", systemImage: "trash").foregroundStyle(Ink.stamp)
            }
            .accessibilityIdentifier("settings.wipe")
            .confirmationDialog("할 일과 기록을 모두 지울까?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("모두 지우기", role: .destructive) {
                    store.change { var fresh = AppData(); fresh.seenIntro = true; $0 = fresh }
                    Haptic.warn()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("되돌릴 수 없어. 필요하면 먼저 내보내 둬.")
            }
        } header: {
            Text("데이터")
        } footer: {
            Text("데이터는 이 기기와, 켜 두었다면 내 iCloud 에만 있어. 모두 지우면 맞춰 둔 Mac 에서도 지워져. 예시로 채우면 지금 할 일이 예시로 바뀌고, 되돌리기로 돌아올 수 있어.")
        }
        .listRowBackground(Ink.sheet)
    }
}

/// 공유할 때 임시 파일로 쓴다
fileprivate struct ExportFile: Transferable {
    var data: AppData
    var day: DayKey

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { f in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("udada-\(f.day).json")
            try DataFile.exportData(f.data).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

// MARK: - 9. 정보

struct SettingsInfoSection: View {
    var store: Store
    /// 시트를 내린 뒤 소개로 (띄운 쪽이 처리한다)
    var replayIntro: () -> Void

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    var body: some View {
        Section("정보") {
            LabeledContent("버전") { Text(version).font(Typo.num(.body, .medium)).foregroundStyle(Ink.text2) }
            NavigationLink("근거 보기") { EvidencePage() }
                .accessibilityIdentifier("settings.evidence")
            Button {
                Haptic.tap()
                replayIntro()
            } label: {
                Label("소개 다시 보기", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("settings.intro")
        }
        .listRowBackground(Ink.sheet)
        Section {
            CallRow(name: "자살예방 상담", number: "109", tel: "109")
            CallRow(name: "정신건강위기 상담", number: "1577-0199", tel: "15770199")
        } header: {
            Text("힘들 때")
        } footer: {
            Text("혼자 견디기 버거우면 지금 전화해. 24시간 받아.")
        }
        .listRowBackground(Ink.sheet)
    }
}

private struct CallRow: View {
    var name: String
    var number: String
    var tel: String

    var body: some View {
        if let url = URL(string: "tel:\(tel)") {
            Link(destination: url) {
                HStack {
                    Text(name).foregroundStyle(Ink.text)
                    Spacer()
                    Text(number).font(Typo.num(.body)).foregroundStyle(Ink.text)
                    Image(systemName: "phone").foregroundStyle(Ink.text2).accessibilityHidden(true)
                }
                .frame(minHeight: Metric.tap)
            }
            .accessibilityLabel("\(name) \(number) 전화 걸기")
        }
    }
}

// MARK: - 근거

private struct Evidence: Identifiable {
    var finding: String
    var app: String
    var source: String
    var id: String { finding }
}

private struct EvidencePage: View {
    private static let day: [Evidence] = [
        .init(finding: "시각도 띠도 없는 할 일은 23%만 끝났고, 시각 있는 일은 50% 끝났어.", app: "할 일은 아침·낮·저녁 띠 하나에 놓여.", source: "Halder et al. 2026 · 프리프린트"),
        .init(finding: "시각 박은 일의 78%가 계획보다 늦게 끝났어.", app: "지난 띠의 일은 빨간 표시 없이 다음 띠로 옮겨.", source: "Halder et al. 2026"),
        .init(finding: "버림은 10일째에 굳어.", app: "나중에 함에 10일 넘게 있던 일만 다시 물어.", source: "Halder et al. 2026"),
        .init(finding: "약속 앞의 한 시간은 실제보다 짧게 느껴져.", app: "지금 줄이 남은 시간과 들어갈 일을 말해.", source: "Tonietto, Malkoc & Nowlis 2019"),
        .init(finding: "걸릴 시간을 적게 잡는 경향이 있어.", app: "길이를 받고, 띠가 넘치면 알려 줘.", source: "Kruger & Evans 2004"),
        .init(finding: "시간 관리는 성과보다 삶의 만족과 더 이어졌어.", app: "점수·연속 기록이 없어.", source: "Aeon, Faber & Panaccio 2021"),
        .init(finding: "구체적인 계획만 세워도 안 끝난 일이 덜 떠올라.", app: "하루 닫기: 남은 것마다 내일·나중에·안 해.", source: "Masicampo & Baumeister 2011"),
        .init(finding: "스스로 정한 휴식이 기분·집중·의욕이 더 좋았어.", app: "식히기는 내가 누를 때만.", source: "Behav. Sci. 2026"),
        .init(finding: "짧은 휴식은 활력을 올리고, 폰으로 쉬면 가장 덜 쉬어져.", app: "식히기 화면엔 볼 게 없어.", source: "Albulescu 2022 · Kang & Kurtzberg 2019"),
        .init(finding: "알림을 하루 3번으로 묶으면 스트레스가 줄었어.", app: "띠마다 한 번 묶음 알림.", source: "Fitz et al. 2019"),
        .init(finding: "밝은 바탕에 어두운 글자가 더 정확하게 읽혔어.", app: "밝은 화면이 기본.", source: "Piepenbrock et al. 2013"),
    ]
    private static let mind: [Evidence] = [
        .init(finding: "걱정을 정한 시간으로 미루면 걱정·불안이 줄었어.", app: "걱정 상자와 걱정 시간.", source: "McGowan & Behar 2013"),
        .init(finding: "두 번 들이쉬고 길게 내쉬는 호흡이 기분을 더 올렸어.", app: "1분 숨 고르기.", source: "Balban et al. 2023"),
        .init(finding: "초록을 40초 본 쪽이 주의를 더 오래 지켰어.", app: "3분 멀리 보기.", source: "Lee et al. 2015"),
        .init(finding: "결과에 거는 보상은 하고 싶은 마음을 깎아.", app: "무작위 보상·레벨이 없어.", source: "Deci, Koestner & Ryan 1999"),
        .init(finding: "정보를 주는 피드백은 동기를 올려.", app: "기록의 숫자는 사실로만.", source: "Deci, Koestner & Ryan 1999"),
        .init(finding: "자기 용서가 다음 미루기를 줄였어.", app: "‘나중에’를 눌러도 벌점이 없어.", source: "Wang et al. 2026"),
    ]

    var body: some View {
        Form {
            group("하루 한 장", Self.day)
            group("머리 식히기", Self.mind)
            Section {} footer: {
                Text("프리프린트와 작은 연구도 있어. 효과는 사람마다 달라.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ink.ground.ignoresSafeArea())
        .navigationTitle("근거")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, _ rows: [Evidence]) -> some View {
        Section(title) {
            ForEach(rows) { e in
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.finding).font(.system(.body)).foregroundStyle(Ink.text)
                    Text("→ " + e.app).font(.system(.subheadline, weight: .medium)).foregroundStyle(Ink.text)
                    Text(e.source).font(Typo.caption).foregroundStyle(Ink.text3)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .listRowBackground(Ink.sheet)
    }
}
