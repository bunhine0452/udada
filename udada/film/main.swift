import AppKit
import CoreText
import SwiftUI

// 우다다 소개 영상 렌더러.
// 앱의 '움직이는 사용법' 장면은 시각 t 의 순수 함수다 — 그래서 화면을 녹화하지 않고, 같은 SwiftUI 코드를 프레임마다 그려 ffmpeg 로 흘려보낸다.
// usage: film <글꼴 ttf> <출력 mp4> [폭 높이 fps]   (기본 1920 1080 60)

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: film <font.ttf> <out.mp4> [w h fps]"); exit(2) }
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: args[1]) as CFURL, .process, nil)
let outW = args.count > 3 ? Int(args[3])! : 1920
let outH = args.count > 4 ? Int(args[4])! : 1080
let fps = args.count > 5 ? Int(args[5])! : 60

/// 포스터 바탕: 앱 바탕보다 한 톤 깊은 종이 (화면이 바탕에서 떠 보이게)
let paper = Color(hex: 0xE7EBE4)

// MARK: - 구성

struct Shot {
    var chapter: Int      // AITour.chapters 의 몇 번째
    var kicker: String
    var head: String
}

let shots: [Shot] = [
    Shot(chapter: 0, kicker: "적기", head: "한 줄로 적으면\n자리를 찾아가"),
    Shot(chapter: 1, kicker: "하루 한 장", head: "하루는 세 칸,\n파란 칸이 지금"),
    Shot(chapter: 3, kicker: "쏟아내기", head: "쏟아내면\n한 줄씩 나눠 줘"),
    Shot(chapter: 4, kicker: "말로 시키기", head: "한 문장으로\n여러 일을 바꿔"),
    Shot(chapter: 6, kicker: "Siri", head: "앱을 열지 않고\nSiri에게"),
    Shot(chapter: 7, kicker: "식히기 · 하루 닫기", head: "뜨거우면 식히고,\n저녁엔 닫아"),
]

let introLen = 5.2
let outroLen = 7.5
/// 장면 앞의 들어오는 시간 · 끝 모습으로 머무는 시간 · 나가는 시간
let lead = 0.8, hold = 0.7, exitLen = 0.45
func shotLen(_ s: Shot) -> Double { lead + AITour.chapters[s.chapter].length + hold + exitLen }
let total = introLen + shots.map(shotLen).reduce(0, +) + outroLen

// MARK: - 프레임

struct Film: View {
    var t: Double

    var body: some View {
        ZStack {
            content
        }
        .frame(width: 1920, height: 1080)
    }

    @ViewBuilder private var content: some View {
        if t < introLen {
            paper
            Intro(b: Beat(t: t))
        } else if t >= total - outroLen {
            Outro(b: Beat(t: t - (total - outroLen)))
        } else {
            paper
            let (i, local) = locate()
            ShotView(n: i + 1, shot: shots[i], b: Beat(t: local), len: shotLen(shots[i]))
        }
    }

    private func locate() -> (Int, Double) {
        var start = introLen
        for (i, s) in shots.enumerated() {
            let l = shotLen(s)
            if t < start + l { return (i, t - start) }
            start += l
        }
        return (shots.count - 1, shotLen(shots[shots.count - 1]))
    }
}

/// 여는 장면: 한 줄이 쳐지고, 이름이 선다
struct Intro: View {
    var b: Beat
    private static let line = "머릿속이 시끄러울 때."

    var body: some View {
        let typedLine = typed(Self.line, b, from: 0.45, per: 0.085)
        let lift = b.p(2.5, 0.6)
        let out = 1 - b.p(introLen - 0.5, 0.45)
        ZStack {
            HStack(spacing: 6) {
                Text(typedLine.isEmpty ? " " : typedLine).font(Typo.serif(88)).foregroundStyle(Ink.text)
                Rectangle().fill(Ink.accent).frame(width: 4, height: 84)
                    .opacity(b.on(0.3) && !b.on(2.5) ? (Int(b.t * 2.4) % 2 == 0 || !b.on(1.55 + 0.45) ? 1 : 0.15) : 0)
            }
            .scaleEffect(1 - 0.42 * lift)
            .offset(y: -210 * lift)
            .opacity(1 - 0.45 * lift)

            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Text("우다다").font(Typo.serif(230)).foregroundStyle(Ink.text)
                        .offset(y: CGFloat(1 - b.land(2.7, 0.7)) * 60).opacity(b.land(2.7, 0.5))
                    // 이름 아래로 코발트 줄이 그어진다
                    Capsule().fill(Ink.accent).frame(width: 560 * b.p(3.1, 0.6), height: 10)
                        .frame(width: 560, alignment: .leading)
                }
                Text("쏟아내면 조용해지는, 하루 한 장").font(.system(size: 40, weight: .medium)).foregroundStyle(Ink.text2)
                    .show(b.p(3.5, 0.5), rise: 16)
            }
            .offset(y: 60)
        }
        .opacity(out)
    }
}

/// 본문 장면: 왼쪽에 말, 오른쪽에 움직이는 화면. 설명 세 줄은 화면이 그 대목에 닿을 때 켜진다.
struct ShotView: View {
    var n: Int
    var shot: Shot
    var b: Beat
    var len: Double

    var body: some View {
        let ch = AITour.chapters[shot.chapter]
        let st = min(ch.length, max(0, b.t - lead))
        let active = ch.steps.lastIndex { $0.0 <= st } ?? 0
        let out = 1 - b.p(len - exitLen, exitLen - 0.05)
        let lines = shot.head.split(separator: "\n").map(String.init)

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Text(String(format: "%02d", n)).font(Typo.num(size: 34, .bold)).foregroundStyle(Ink.text3)
                    Text(shot.kicker).font(.system(size: 34, weight: .semibold)).foregroundStyle(Ink.accent)
                    if ch.ai { GAIMark().scaleEffect(2.0, anchor: .leading).frame(width: 260, alignment: .leading) }
                }
                .opacity(b.p(0.05, 0.4))
                .padding(.bottom, 30)

                // 머리말: 줄마다 아래에서 밀려 올라온다 (줄 높이로 잘라 가린다)
                ForEach(lines.indices, id: \.self) { i in
                    let p = b.land(0.12 + Double(i) * 0.11, 0.65)
                    Text(lines[i]).font(Typo.serif(112)).foregroundStyle(Ink.text)
                        .fixedSize()
                        .offset(y: CGFloat(1 - p) * 150)
                        .frame(height: 148, alignment: .bottomLeading)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(ch.steps.indices, id: \.self) { i in
                        step(i, ch.steps[i].1, on: i == active && b.on(lead), past: i < active)
                            .show(b.p(0.45 + Double(i) * 0.08, 0.45), rise: 14)
                    }
                }
                .padding(.top, 70)
            }
            .frame(width: 880, height: 940, alignment: .leading)
            .offset(x: 130, y: 40)

            device(ch, st)
                .offset(x: 1058, y: 76 + CGFloat(1 - b.land(0.2, 0.7)) * 70)
                .opacity(b.land(0.2, 0.5))

            // 어디쯤인지
            HStack(spacing: 18) {
                Text("우다다").font(Typo.serif(26)).foregroundStyle(Ink.text2)
                HStack(spacing: 8) {
                    ForEach(shots.indices, id: \.self) { i in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Ink.rule)
                            Capsule().fill(Ink.text).frame(width: 64 * (i < n - 1 ? 1 : i == n - 1 ? st / ch.length : 0))
                        }
                        .frame(width: 64, height: 5)
                    }
                }
            }
            .opacity(b.p(0.3, 0.4))
            .offset(x: 130, y: 978)
        }
        .frame(width: 1920, height: 1080, alignment: .topLeading)
        .opacity(out)
    }

    private func step(_ i: Int, _ text: String, on: Bool, past: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text("\(i + 1)").font(Typo.num(size: 25, .bold))
                .foregroundStyle(on ? Ink.accentText : Ink.text3)
                .frame(width: 44, height: 44)
                .background(Circle().fill(on ? Ink.accent : Ink.fill))
            Text(text).font(.system(size: 35, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Ink.text : past ? Ink.text2 : Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 860, alignment: .leading)
    }

    /// 평평한 기기 안에서 장면이 돈다 (무대 320×400 을 2.2배로)
    private func device(_ ch: AITour.Chapter, _ st: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 86, style: .continuous).fill(Ink.block)
            GuideStage { scene(shot.chapter, Beat(t: st)) }
                .frame(width: 704, height: 880)
                .background(ch.night ? Ink.night : Ink.ground)
                .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
        }
        .frame(width: 752, height: 928)
    }

    @ViewBuilder private func scene(_ i: Int, _ b: Beat) -> some View {
        switch i {
        case 0: AddScene(b: b)
        case 1: BandsScene(b: b)
        case 2: DoneScene(b: b)
        case 3: DumpScene(b: b)
        case 4: CommandScene(b: b)
        case 5: CaptureScene(b: b)
        case 6: SiriScene(b: b)
        case 7: RestScene(b: b)
        default: InsideScene(b: b)
        }
    }
}

/// 닫는 장면: 기기 안에서만 → 이름과 받는 곳
struct Outro: View {
    var b: Beat
    private static let none = ["서버 없음", "계정 없음", "광고 없음"]

    var body: some View {
        let dark = b.p(0, 0.6)
        let first = 1 - b.p(3.3, 0.45)
        let second = b.p(3.7, 0.5)
        ZStack {
            paper
            Ink.night.opacity(dark)
            VStack(spacing: 44) {
                Text("전부 이 기기 안에서.").font(Typo.serif(104)).foregroundStyle(Ink.nightText)
                    .show(b.land(0.5, 0.6), rise: 30)
                HStack(spacing: 18) {
                    ForEach(Self.none.indices, id: \.self) { i in
                        let p = b.pop(1.4 + Double(i) * 0.22)
                        Text(Self.none[i]).font(.system(size: 38, weight: .semibold)).foregroundStyle(Ink.nightText)
                            .padding(.horizontal, 36).frame(height: 84)
                            .background(Capsule().strokeBorder(Ink.nightSoft, lineWidth: 2))
                            .scaleEffect(0.9 + 0.1 * min(1, p)).opacity(min(1, p))
                    }
                }
                Text("지원 기기에서는 Apple Intelligence가, 아니면 같은 흐름이 규칙으로.")
                    .font(.system(size: 32)).foregroundStyle(Ink.nightSoft).opacity(b.p(2.2, 0.5))
            }
            .opacity(first)

            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("우다다").font(Typo.serif(210)).foregroundStyle(Ink.nightText)
                    Capsule().fill(Color(hex: 0x8399FF)).frame(width: 510 * b.p(4.0, 0.6), height: 9)
                        .frame(width: 510, alignment: .leading)
                }
                Text("App Store에서 무료  ·  iPhone · Mac").font(.system(size: 40, weight: .semibold)).foregroundStyle(Ink.nightText)
                    .show(b.p(4.4, 0.5), rise: 14)
                Text("오픈소스  github.com/bunhine0452/udada").font(Typo.num(size: 30, .semibold)).foregroundStyle(Ink.nightSoft)
                    .show(b.p(4.8, 0.5), rise: 14)
            }
            .show(second, rise: 24)
        }
    }
}

// MARK: - 그려서 ffmpeg 로

let ffmpeg = Process()
ffmpeg.executableURL = URL(fileURLWithPath: "/usr/bin/env")
ffmpeg.arguments = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(outW)x\(outH)", "-r", "\(fps)", "-i", "-",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "15", "-pix_fmt", "yuv420p", "-movflags", "+faststart", args[2]]
let pipe = Pipe()
ffmpeg.standardInput = pipe
try ffmpeg.run()

let frames = Int(total * Double(fps))
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: outW * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
let started = Date()
MainActor.assumeIsolated {
    for f in 0..<frames {
        autoreleasepool {
            let r = ImageRenderer(content: Film(t: Double(f) / Double(fps)))
            r.proposedSize = ProposedViewSize(width: 1920, height: 1080)
            r.scale = CGFloat(outW) / 1920
            guard let img = r.cgImage else { fatalError("frame \(f) 을 못 그렸다") }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: outW, height: outH))
            pipe.fileHandleForWriting.write(Data(bytesNoCopy: ctx.data!, count: outW * outH * 4, deallocator: .none))
        }
        if f % 300 == 0 { print("frame \(f)/\(frames)  \(Int(Date().timeIntervalSince(started)))s"); fflush(stdout) }
    }
}
try pipe.fileHandleForWriting.close()
ffmpeg.waitUntilExit()
print("done \(args[2])  \(String(format: "%.1f", total))s  \(frames) frames  ffmpeg=\(ffmpeg.terminationStatus)")
