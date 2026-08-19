import SwiftUI

struct LeafMenuBarIcon: View {
    let level: Int

    private var fillFraction: CGFloat {
        CGFloat(min(max(level, 0), 10)) / 10.0
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height

            ZStack(alignment: .bottom) {
                Image(systemName: "leaf")
                    .resizable()
                    .scaledToFit()

                Image(systemName: "leaf.fill")
                    .resizable()
                    .scaledToFit()
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: height * fillFraction)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
            }
        }
        .frame(width: 18, height: 18)
        .foregroundStyle(.primary)
    }
}
