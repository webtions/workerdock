import SwiftUI

/// The app icon, drawn in SwiftUI so it can be rendered to PNGs (see the WORKERDOCK_DEBUG_ICON hook).
struct AppIconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#FF6A7C"), Color(hex: "#FF3253"), Color(hex: "#D91C3E")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .overlay(
                    RoundedRectangle(cornerRadius: 186, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.0)], startPoint: .top, endPoint: .center), lineWidth: 6)
                        .frame(width: 824, height: 824)
                )
                .shadow(color: .black.opacity(0.28), radius: 26, y: 16)

            VStack(spacing: 46) {
                Icon("cloud", size: 430).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                Capsule().fill(.white.opacity(0.35)).frame(width: 300, height: 34)
            }
            .offset(y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}
