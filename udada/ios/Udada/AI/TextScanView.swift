import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import VisionKit

/// 사진으로 옮기기: 손글씨 목록·일정표 캡처를 찍거나 고르면 줄마다 읽어 체크 목록으로 보여 준다.
/// 빼고 싶은 줄은 칸을 눌러 끄고, 글은 그 자리에서 고친다 → [N개 가져오기]. 사진은 저장하지 않는다.
struct TextScanView: View {
    var onDone: ([String]) -> Void
    var onCancel: () -> Void

    init(onDone: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
    }

    private enum Stage: Equatable { case pick, reading, empty, review }

    @State private var stage: Stage = .pick
    @State private var rows: [ScanRow] = []
    /// 글자 인식이 읽은 줄 그대로 (Apple Intelligence 가 고른 일정 대신 볼 때)
    @State private var rawLines: [String] = []
    /// Apple Intelligence 가 사진을 보고 일정을 골랐나
    @State private var sawPhoto = false
    @State private var showingRaw = false
    @State private var seenLines: [String] = []
    @State private var pickItem: PhotosPickerItem?
    @State private var camera: CameraKind?
    @State private var cameraDenied = false
    @Environment(\.openURL) private var openURL

    private var chosen: [String] {
        rows.filter(\.on).map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch stage {
            case .pick: pickView
            case .reading: readingView
            case .empty: emptyView
            case .review: reviewView
            }
        }
        .background(Ink.ground.ignoresSafeArea())
        .fullScreenCover(item: $camera) { kind in
            CameraSheet(kind: kind) { image in
                camera = nil
                read(image)
            } onCancel: {
                camera = nil
            }
        }
        .onChange(of: pickItem) { _, item in
            guard let item else { return }
            pickItem = nil
            stage = .reading
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                guard let data, let image = UIImage(data: data) else { stage = .empty; return }
                read(image)
            }
        }
    }

    // MARK: - 위

    private var topBar: some View {
        HStack {
            if stage == .review || stage == .empty {
                Button("다른 사진") { Haptic.tick(); rows = []; stage = .pick }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Ink.text2)
                    .frame(minHeight: Metric.tap)
                    .padding(.horizontal, 10)
                    .accessibilityIdentifier("scan.again")
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Ink.text2)
                    .frame(width: Metric.tap, height: Metric.tap)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("scan.close")
        }
        .padding(.horizontal, Metric.gutter - 10)
        .padding(.top, 4)
    }

    // MARK: - 고르기

    private var pickView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle(title: "사진으로 옮기기", sub: "손글씨 목록이나 일정표를 찍어. 한 줄이 할 일 하나가 돼.")
            if cameraDenied {
                VStack(alignment: .leading, spacing: 12) {
                    Text("카메라가 꺼져 있어. 설정에서 카메라를 켜 줘.")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Ink.text)
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(FillButton(tone: .line, height: 46, full: false))
                }
                .card()
                .padding(.top, 20)
            }
            Spacer()
            Text("사진은 저장하지 않아. 글자는 기기 안에서 읽어.")
                .font(Typo.meta)
                .foregroundStyle(Ink.text3)
                .padding(.bottom, 12)
            VStack(spacing: 10) {
                PhotosPicker(selection: $pickItem, matching: .images) {
                    Label("앨범에서 고르기", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(FillButton(tone: hasCamera ? .quiet : .accent))
                .accessibilityIdentifier("scan.library")
                if hasCamera {
                    Button { openCamera() } label: {
                        Label("사진 찍기", systemImage: "camera")
                    }
                    .buttonStyle(FillButton(tone: .accent))
                    .accessibilityIdentifier("scan.camera")
                }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 8)
    }

    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private func openCamera() {
        Haptic.tap()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            cameraDenied = true
        case .notDetermined:
            // 라이브 텍스트는 권한이 있어야 isAvailable 이 참이라 먼저 묻는다
            Task {
                let ok = await AVCaptureDevice.requestAccess(for: .video)
                cameraDenied = !ok
                if ok { camera = liveOrPhoto }
            }
        default:
            cameraDenied = false
            camera = liveOrPhoto
        }
    }

    private var liveOrPhoto: CameraKind {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable ? .live : .photo
    }

    // MARK: - 읽는 중 / 못 찾음

    private var readingView: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Ink.text2)
            Text("글자 읽는 중…")
                .font(Typo.label)
                .foregroundStyle(Ink.text2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle(title: "글자를 못 찾았어", sub: "밝은 곳에서, 글자가 화면에 꽉 차게 찍어 봐. 흐린 손글씨는 또박또박 쓴 게 잘 읽혀.")
            Spacer()
            VStack(spacing: 10) {
                PhotosPicker(selection: $pickItem, matching: .images) {
                    Text("앨범에서 고르기")
                }
                .buttonStyle(FillButton(tone: .quiet))
                if hasCamera {
                    Button("다시 찍기") { openCamera() }
                        .buttonStyle(FillButton(tone: .accent))
                }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 8)
    }

    // MARK: - 고치고 고르기

    private var reviewView: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: sawPhoto && !showingRaw ? "사진에서 찾은 일정" : "읽은 줄",
                        sub: sawPhoto && !showingRaw ? "날짜와 이름을 묶어 놨어. 빼고 싶은 줄은 칸을 눌러 꺼." : "빼고 싶은 줄은 칸을 눌러 꺼. 글은 눌러서 고쳐.")
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 8)
            if sawPhoto {
                // 모델이 놓쳤을 수 있으니, 읽은 글자 그대로도 언제든 볼 수 있게
                HStack(spacing: 10) {
                    if !showingRaw { AIBadge() }
                    Spacer()
                    Button(showingRaw ? "찾은 일정 보기" : "읽은 글자 전부 보기") {
                        Haptic.tick()
                        showingRaw.toggle()
                        rows = (showingRaw ? rawLines : seenLines).map { ScanRow(text: $0) }
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Ink.text2)
                    .frame(minHeight: Metric.tap)
                    .accessibilityIdentifier("scan.toggleRaw")
                }
                .padding(.horizontal, Metric.gutter)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($rows) { $row in
                        ScanRowView(row: $row)
                        Hairline().padding(.leading, 56)
                    }
                }
                .padding(.horizontal, Metric.gutter - 8)
            }
            .scrollDismissesKeyboard(.interactively)
            Button("\(chosen.count)개 가져오기") {
                Haptic.success()
                onDone(chosen)
            }
            .buttonStyle(FillButton(tone: .accent))
            .disabled(chosen.isEmpty)
            .opacity(chosen.isEmpty ? 0.5 : 1)
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .accessibilityIdentifier("scan.import")
        }
    }

    // MARK: - 읽기

    private func read(_ image: UIImage) {
        stage = .reading
        Task {
            guard let cg = TextScan.upright(image) else { Haptic.warn(); stage = .empty; return }
            let lines = await TextScan.recognize(cg)
            guard !lines.isEmpty else { Haptic.warn(); stage = .empty; return }
            rawLines = lines
            // 그림을 볼 수 있는 기기면 Apple Intelligence 가 포스터·안내문에서 일정을 찾아 날짜와 이름을 묶는다. 아니면 읽은 줄 그대로.
            let seen = await Brain.shared.readPhoto(cg, ocr: lines)
            sawPhoto = seen.fromAI
            seenLines = seen.lines
            showingRaw = false
            rows = seen.lines.map { ScanRow(text: $0) }
            Haptic.soft()
            stage = .review
        }
    }
}

// MARK: - 줄 한 개

private struct ScanRow: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var on = true
}

private struct ScanRowView: View {
    @Binding var row: ScanRow

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                Haptic.tick()
                row.on.toggle()
            } label: {
                CheckBox(done: row.on)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(row.text)
            .accessibilityValue(row.on ? "가져옴" : "뺌")
            .accessibilityHint("두 번 눌러 \(row.on ? "빼기" : "넣기")")
            TextField("할 일", text: $row.text, axis: .vertical)
                .font(Typo.row)
                .foregroundStyle(row.on ? Ink.text : Ink.text3)
                .strikethrough(!row.on, color: Ink.text3)
                .lineLimit(1...4)
                .submitLabel(.done)
                .padding(.vertical, 12)
                .accessibilityLabel("할 일 고치기")
        }
        .frame(minHeight: Metric.rowMin)
    }
}

// MARK: - 카메라

private enum CameraKind: String, Identifiable {
    case live, photo
    var id: String { rawValue }
}

private struct CameraSheet: View {
    var kind: CameraKind
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        switch kind {
        case .live: LiveTextCamera(onImage: onImage, onCancel: onCancel)
        case .photo: PhotoCamera(onImage: onImage, onCancel: onCancel).ignoresSafeArea()
        }
    }
}

/// VisionKit 라이브 텍스트: 글자를 비추면 표시해 주고, [찍기] 로 한 장 찍어 TextScan 으로 읽는다.
private struct LiveTextCamera: View {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void
    @State private var handle = ScannerHandle()
    @State private var shooting = false

    var body: some View {
        ZStack {
            ScannerView(handle: handle).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Ink.nightText)
                            .frame(width: Metric.tap, height: Metric.tap)
                            .background(Circle().fill(Ink.night.opacity(0.7)))
                    }
                    .accessibilityLabel("닫기")
                }
                Spacer()
                Text("글자가 화면에 꽉 차게 비춰 줘")
                    .font(Typo.label)
                    .foregroundStyle(Ink.nightText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Ink.night.opacity(0.7)))
                Button(shooting ? "읽는 중…" : "찍기") { shoot() }
                    .buttonStyle(FillButton(tone: .night, height: 60))
                    .disabled(shooting)
                    .accessibilityIdentifier("scan.shutter")
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 8)
        }
        .background(Ink.night.ignoresSafeArea())
    }

    private func shoot() {
        guard let scanner = handle.scanner else { return }
        shooting = true
        Haptic.firm()
        Task {
            let image = try? await scanner.capturePhoto()
            shooting = false
            if let image { onImage(image) }
        }
    }
}

@MainActor
private final class ScannerHandle {
    weak var scanner: DataScannerViewController?
}

private struct ScannerView: UIViewControllerRepresentable {
    var handle: ScannerHandle

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let supported = DataScannerViewController.supportedTextRecognitionLanguages
        let langs = ["ko-KR", "en-US"].filter { want in supported.contains { $0.hasPrefix(String(want.prefix(2))) } }
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text(languages: langs)],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true)
        handle.scanner = vc
        DispatchQueue.main.async { try? vc.startScanning() }
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: ()) {
        vc.stopScanning()
    }
}

/// 라이브 텍스트를 못 쓰는 기기: 기본 카메라로 한 장 찍는다.
private struct PhotoCamera: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoCamera
        init(_ parent: PhotoCamera) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) } else { parent.onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
    }
}
