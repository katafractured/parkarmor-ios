import SwiftUI

// Local inline replacements for KatafractStyle package symbols.

// MARK: - Brand Colors

extension Color {
    static let kataGold = Color(red: 0.776, green: 0.596, blue: 0.220)
    static let kataIce = Color(red: 0.780, green: 0.900, blue: 0.950)
    static let kataChampagne = Color(red: 0.950, green: 0.870, blue: 0.730)
}

enum KataAccent {
    static let gold = Color.kataGold
}

// MARK: - Brand Fonts

extension Font {
    static func kataDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .default)
    }

    static func kataMono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    static func kataBody(_ size: CGFloat) -> Font {
        .system(size: size)
    }

    static func kataHeadline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}

// MARK: - Brand Components

struct KataProgressRing: View {
    let size: CGFloat

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.kataGold)
            .frame(width: size, height: size)
    }
}
