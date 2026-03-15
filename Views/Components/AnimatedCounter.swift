import SwiftUI

struct AnimatedCounter: View {
    let value: Double
    let duration: Double
    @State private var displayed: Double = 0

    init(value: Double, duration: Double = 1.0) {
        self.value = value
        self.duration = duration
    }

    var body: some View {
        Text("\(Int(displayed.rounded()))")
            .onAppear {
                displayed = 0
                withAnimation(.easeOut(duration: duration)) {
                    displayed = value
                }
            }
            .onChange(of: value) { newValue in
                displayed = 0
                withAnimation(.easeOut(duration: duration)) {
                    displayed = newValue
                }
            }
    }
}
