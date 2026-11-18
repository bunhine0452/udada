import AppKit
import CoreText
import SwiftUI

// 우다다 소개 영상 렌더러.
// 앱의 '움직이는 사용법' 장면은 시각 t 의 순수 함수다 — 그래서 화면을 녹화하지 않고, 같은 SwiftUI 코드를 프레임마다 그려 ffmpeg 로 흘려보낸다.
// 구성: 여는 한 줄 → 다섯 컷(가장 놀라운 것부터: Siri) → 닫는 장면. 컷마다 바탕색이 바뀌고, 화면은 일이 벌어지는 곳으로 천천히 다가간다.
// usage: film <글꼴 ttf> <출력 mp4> [폭 높이 fps]   (기본 1920 1080 60) — 소리 넣을 자리(cues)는 <출력>.cues.json 에 적는다.

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: film <font.ttf> <out.mp4> [w h fps]"); exit(2) }
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: args[1]) as CFURL, .process, nil)
let outW = args.count > 3 ? Int(args[3])! : 1920
let outH = args.count > 4 ? Int(args[4])! : 1080
let fps = args.count > 5 ? Int(args[5])! : 60

// MARK: - 구성

/// 컷의 바탕: 종이 · 코발트 · 먹. 한 컷에 한 색.
struct Look {
    var bg: Color, ink: Color, sub: Color, accent: Color, bezel: Color, rule: Color
    static let paper = Look(bg: Color(hex: 0xE7EBE4), ink: Ink.text, sub: Ink.text2, accent: Ink.accent, bezel: Ink.block, rule: Ink.rule)
    static let cobalt = Look(bg: Color(hex: 0x2E4AE3), ink: .white, sub: Color(hex: 0xD5DCFB), accent: .white, bezel: Color(hex: 0x141C19), rule: Color(hex: 0x5A70EA))
    static let ink = Look(bg: Color(hex: 0x141C19), ink: Color(hex: 0xF1F5F1), sub: Color(hex: 0xA9B7B0), accent: Color(hex: 0x9DAEFF), bezel: Color(hex: 0x33403A), rule: Color(hex: 0x2C3833))
}

struct Shot {
    var chapter: Int              // AITour.chapters 의 몇 번째
    var kicker: String
    var head: String
    var from: Double, to: Double  // 그 장면에서 쓰는 구간 (초)
    var look: Look
    var focus: UnitPoint          // 화면이 다가가는 곳 (무대 안의 자리)
}

let shots: [Shot] = [
    Shot(chapter: 6, kicker: "Siri", head: "앱을 열지 않고\nSiri에게 한 문장", from: 0, to: 6.7, look: .ink, focus: UnitPoint(x: 0.5, y: 0.38)),
    Shot(chapter: 3, kicker: "쏟아내기", head: "쏟아내면\n한 줄씩 나눠 줘", from: 0, to: 10.2, look: .paper, focus: UnitPoint(x: 0.5, y: 0.55)),
    Shot(chapter: 0, kicker: "적기", head: "한 줄로 적으면\n자리를 찾아가", from: 0.2, to: 6.0, look: .cobalt, focus: UnitPoint(x: 0.5, y: 0.7)),
    Shot(chapter: 4, kicker: "말로 시키기", head: "한 문장으로\n여러 일을 바꿔", from: 0.3, to: 7.9, look: .paper, focus: UnitPoint(x: 0.5, y: 0.5)),
    Shot(chapter: 7, kicker: "하루 닫기", head: "저녁엔 닫아.\n도장, 쿵.", from: 5.0, to: 9.6, look: .paper, focus: UnitPoint(x: 0.5, y: 0.6)),
]

/// 여는 장면은 1.35배로
let introSpeed = 1.35
let introLen = 5.2 / introSpeed
let outroLen = 6.8
/// 컷 앞의 들어오는 시간 · 끝 모습으로 머무는 시간 · 나가는 시간
let lead = 0.6, hold = 0.55, exitLen = 0.32
func shotLen(_ s: Shot) -> Double { lead + (s.to - s.from) + hold + exitLen }
let total = introLen + shots.map(shotLen).reduce(0, +) + outroLen
func shotStart(_ i: Int) -> Double { introLen + shots[..<i].map(shotLen).reduce(0, +) }

// MARK: - 프레임

struct Film: View {
    var t: Double

    var body: some View {
        ZStack { content }.frame(width: 1920, height: 1080)
    }

    @ViewBuilder private var content: some View {
        if t < introLen {
            Look.paper.bg
            Intro(b: Beat(t: t * introSpeed))
        } else if t >= total - outroLen {
            Outro(b: Beat(t: t - (total - outroLen)))
        } else {
            let i = shots.indices.last { t >= shotStart($0) } ?? 0
            let local = t - shotStart(i)
            // 바탕은 앞 컷의 색에서 넘어온다
            shots[i].look.bg
            (i == 0 ? Look.paper.bg : shots[i - 1].look.bg).opacity(1 - Beat(t: local).p(0, 0.3))
            ShotView(n: i + 1, shot: shots[i], b: Beat(t: local), len: shotLen(shots[i]))
        }
    }
}

/// 여는 장면: 한 줄이 쳐지고, 이름이 선다
struct Intro: View {
    var b: Beat
    static let line = "머릿속이 시끄러울 때."

    var body: some View {
        let typedLine = typed(Self.line, b, from: 0.45, per: 0.085)
        let lift = b.p(2.5, 0.6)
        let out = 1 - b.p(5.2 - 0.5, 0.45)
        ZStack {
            HStack(spacing: 6) {
                Text(typedLine.isEmpty ? " " : typedLine).font(Typo.serif(96)).foregroundStyle(Ink.text)
                Rectangle().fill(Ink.accent).frame(width: 4, height: 90).opacity(b.on(0.3) && !b.on(2.5) ? 1 : 0)
            }
            .scaleEffect(1 - 0.45 * lift)
            .offset(y: -220 * lift)
            .opacity(1 - 0.45 * lift)

            // Apple Intelligence × 우다다
            VStack(spacing: 34) {
                HStack(alignment: .center, spacing: 34) {
                    HStack(spacing: 20) {
                        Image(systemName: "apple.intelligence").font(.system(size: 84, weight: .semibold))
                        Text("Apple Intelligence").font(.system(size: 84, weight: .semibold))
                    }
                    .foregroundStyle(Ink.accent)
                    .offset(x: CGFloat(1 - b.land(2.7, 0.7)) * -70).opacity(b.land(2.7, 0.5))
                    Text("×").font(.system(size: 76, weight: .light)).foregroundStyle(Ink.text3)
                        .scaleEffect(0.4 + 0.6 * min(1, b.pop(3.0))).opacity(min(1, b.pop(3.0)))
                    Text("우다다").font(Typo.serif(170)).foregroundStyle(Ink.text)
                        .offset(x: CGFloat(1 - b.land(2.85, 0.7)) * 70).opacity(b.land(2.85, 0.5))
                }
                .fixedSize()
                Capsule().fill(Ink.text).frame(width: 1380 * b.p(3.2, 0.6), height: 6).frame(width: 1380, alignment: .leading)
                Text("아이폰 안의 AI가 듣고, 나누고, 일정을 보고 답장까지.").font(.system(size: 44, weight: .medium)).foregroundStyle(Ink.text2)
                    .show(b.p(3.6, 0.5), rise: 16)
            }
            .offset(y: 60)
        }
        .opacity(out)
    }
}

/// 본문 컷: 왼쪽에 큰 말, 오른쪽에 움직이는 화면. 아래 한 줄은 화면이 그 대목에 닿을 때 바뀐다.
struct ShotView: View {
    var n: Int
    var shot: Shot
    var b: Beat
    var len: Double

    var body: some View {
        let ch = AITour.chapters[shot.chapter]
        let look = shot.look
        let st = min(shot.to, shot.from + max(0, b.t - lead))
        let active = ch.steps.lastIndex { $0.0 <= st } ?? 0
        let out = 1 - b.p(len - exitLen, exitLen - 0.04)
        let lines = shot.head.split(separator: "\n").map(String.init)
        // 화면이 일이 벌어지는 곳으로 천천히 다가간다
        let push = 1 + 0.045 * min(1, b.t / len)

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Text(String(format: "%02d", n)).font(Typo.num(size: 34, .bold)).foregroundStyle(look.sub.opacity(0.7))
                    Text(shot.kicker).font(.system(size: 34, weight: .semibold)).foregroundStyle(look.accent)
                    if ch.ai {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.intelligence").font(.system(size: 22, weight: .semibold))
                            Text("Apple Intelligence").font(.system(size: 24, weight: .semibold))
                        }
                        .foregroundStyle(look.accent)
                        .padding(.horizontal, 16).frame(height: 42)
                        .background(Capsule().strokeBorder(look.accent.opacity(0.55), lineWidth: 1.5))
                    }
                }
                .opacity(b.p(0.05, 0.35))
                .padding(.bottom, 30)

                // 머리말: 줄마다 아래에서 밀려 올라온다 (줄 높이로 잘라 가린다)
                ForEach(lines.indices, id: \.self) { i in
                    let p = b.land(0.08 + Double(i) * 0.1, 0.6)
                    Text(lines[i]).font(Typo.serif(118)).foregroundStyle(look.ink)
                        .fixedSize()
                        .offset(y: CGFloat(1 - p) * 160)
                        .frame(height: 156, alignment: .bottomLeading)
                        .clipped()
                }

                // 지금 대목의 설명 한 줄 (대목이 바뀌면 갈아 끼운다)
                ZStack(alignment: .topLeading) {
                    ForEach(ch.steps.indices, id: \.self) { i in
                        let at = lead + max(0, ch.steps[i].0 - shot.from)
                        let next = i + 1 < ch.steps.count ? lead + max(0, ch.steps[i + 1].0 - shot.from) : .infinity
                        let p = b.p(at, 0.35) * (1 - b.p(next - 0.2, 0.25))
                        Text(ch.steps[i].1).font(.system(size: 40, weight: .medium)).foregroundStyle(look.sub)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 860, alignment: .leading)
                            .show(i == active || p > 0 ? p : 0, rise: 12)
                    }
                }
                .frame(width: 860, height: 120, alignment: .topLeading)
                .padding(.top, 52)
            }
            .frame(width: 900, height: 940, alignment: .leading)
            .offset(x: 130, y: 40)

            device(ch, st, look)
                .scaleEffect(push, anchor: UnitPoint(x: 0.5, y: 0.25 + 0.5 * shot.focus.y))
                .offset(x: 1058, y: 76 + CGFloat(1 - b.land(0.12, 0.65)) * 80)
                .opacity(b.land(0.12, 0.45))

            // 어디쯤인지
            HStack(spacing: 18) {
                Text("우다다").font(Typo.serif(26)).foregroundStyle(look.sub)
                HStack(spacing: 8) {
                    ForEach(shots.indices, id: \.self) { i in
                        ZStack(alignment: .leading) {
                            Capsule().fill(look.rule)
                            Capsule().fill(look.ink).frame(width: 64 * (i < n - 1 ? 1 : i == n - 1 ? min(1, b.t / len) : 0))
                        }
                        .frame(width: 64, height: 5)
                    }
                }
            }
            .opacity(b.p(0.2, 0.35))
            .offset(x: 130, y: 978)
        }
        .frame(width: 1920, height: 1080, alignment: .topLeading)
        .opacity(out)
    }

    /// 평평한 기기 안에서 장면이 돈다 (무대 320×400 을 2.2배로)
    private func device(_ ch: AITour.Chapter, _ st: Double, _ look: Look) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 86, style: .continuous).fill(look.bezel)
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
        let dark = b.p(0, 0.5)
        let first = 1 - b.p(2.9, 0.4)
        let second = b.p(3.2, 0.5)
        ZStack {
            Look.paper.bg
            Look.ink.bg.opacity(dark)
            VStack(spacing: 46) {
                Text("전부 이 기기 안에서.").font(Typo.serif(112)).foregroundStyle(Look.ink.ink)
                    .show(b.land(0.35, 0.6), rise: 30)
                HStack(spacing: 18) {
                    ForEach(Self.none.indices, id: \.self) { i in
                        let p = b.pop(1.1 + Double(i) * 0.2)
                        Text(Self.none[i]).font(.system(size: 38, weight: .semibold)).foregroundStyle(Look.ink.ink)
                            .padding(.horizontal, 36).frame(height: 84)
                            .background(Capsule().strokeBorder(Look.ink.sub.opacity(0.6), lineWidth: 2))
                            .scaleEffect(0.9 + 0.1 * min(1, p)).opacity(min(1, p))
                    }
                }
                Text("지원 기기에서는 Apple Intelligence가, 아니면 같은 흐름이 규칙으로.")
                    .font(.system(size: 32)).foregroundStyle(Look.ink.sub).opacity(b.p(1.8, 0.45))
            }
            .opacity(first)

            VStack(spacing: 30) {
                HStack(alignment: .center, spacing: 30) {
                    HStack(spacing: 18) {
                        Image(systemName: "apple.intelligence").font(.system(size: 72, weight: .semibold))
                        Text("Apple Intelligence").font(.system(size: 72, weight: .semibold))
                    }
                    .foregroundStyle(Look.ink.accent)
                    Text("×").font(.system(size: 64, weight: .light)).foregroundStyle(Look.ink.sub)
                    Text("우다다").font(Typo.serif(150)).foregroundStyle(Look.ink.ink)
                }
                .fixedSize()
                Capsule().fill(Look.ink.ink).frame(width: 1200 * b.p(3.5, 0.55), height: 5).frame(width: 1200, alignment: .leading)
                Text("App Store에서 무료  ·  iPhone · Mac").font(.system(size: 42, weight: .semibold)).foregroundStyle(Look.ink.ink)
                    .show(b.p(3.9, 0.45), rise: 14)
                Text("오픈소스  github.com/bunhine0452/udada").font(Typo.num(size: 32, .semibold)).foregroundStyle(Look.ink.sub)
                    .show(b.p(4.2, 0.45), rise: 14)
            }
            .show(second, rise: 24)
        }
    }
}

// MARK: - 소리 넣을 자리

/// 컷마다 언제 시작하고 장면의 어느 구간을 쓰는지 — film/sfx.py 가 이것으로 효과음의 시각을 맞춘다
let cues: [String: Any] = [
    "total": total, "introSpeed": introSpeed, "introLen": introLen, "outroStart": total - outroLen, "lead": lead,
    "shots": shots.indices.map { ["chapter": shots[$0].chapter, "start": shotStart($0), "from": shots[$0].from, "to": shots[$0].to] },
]
try JSONSerialization.data(withJSONObject: cues, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: args[2] + ".cues.json"))

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
        if f % 600 == 0 { print("frame \(f)/\(frames)  \(Int(Date().timeIntervalSince(started)))s"); fflush(stdout) }
    }
}
try pipe.fileHandleForWriting.close()
ffmpeg.waitUntilExit()
print("done \(args[2])  \(String(format: "%.1f", total))s  \(frames) frames  ffmpeg=\(ffmpeg.terminationStatus)")
