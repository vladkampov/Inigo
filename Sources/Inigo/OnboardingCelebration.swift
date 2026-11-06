import SwiftUI

struct OnboardingCelebration: View {
    let start: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let colors: [Color] = [.purple, .blue, .pink, .mint, .yellow]
    var body: some View {
        if reduceMotion {
            VStack { Spacer(); Label(L("Your first rewrite. Nicely done!"), systemImage:"checkmark.seal.fill")
                .font(.headline).padding(14).background(.regularMaterial,in:Capsule()); Spacer() }
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(start)
                    guard t >= 0, t < 3 else { return }
                    context.opacity = min(1, max(0, (3 - t) / 0.7))
                    for i in 0..<100 {
                        let seed = Double((i * 73 + 19) % 101) / 100
                        let speed = 140 + Double((i * 37) % 160)
                        let x = size.width * seed + sin(t * 3 + Double(i)) * 35
                        let y = -80 - Double((i * 29) % 220) + speed * t + 45 * t * t
                        var piece = context
                        piece.translateBy(x:x,y:y)
                        piece.rotate(by:.radians(t * Double(i % 5 + 1) + Double(i)))
                        piece.fill(Path(roundedRect:CGRect(x:-3,y:-5,width:6,height:10),cornerRadius:1),with:.color(colors[i % colors.count]))
                    }
                }
            }
            .clipped()
        }
    }
}
