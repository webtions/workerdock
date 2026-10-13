import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: Space.l) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
            VStack(spacing: Space.xs) {
                Text(AppInfo.name).font(.dTitle)
                Text("Version \(AppInfo.version)").font(.dCaption).foregroundStyle(Brand.muted)
            }
            Text("Manage all your local Cloudflare Workers projects in one place.")
                .font(.dBody).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
            HStack(spacing: Space.s) {
                Link(destination: AppInfo.website) { Text("Website") }.buttonStyle(.dockSecondary)
                if let support = AppInfo.supportURL {
                    Link(destination: support) { Label { Text("Support \(AppInfo.name)") } icon: { Icon("heart", size: IconSize.sm) } }
                        .buttonStyle(.dockPrimary)
                }
            }
            Divider().overlay(Brand.borderSoft)
            VStack(spacing: Space.xs) {
                Text("MIT License · © 2026 Webtions OÜ")
                Text("Icons by Lucide (ISC). Framework logos are trademarks of their owners and only identify the framework a project uses.")
                Text("\(AppInfo.name) is an independent project and is not affiliated with or endorsed by Cloudflare.")
            }
            .font(.dCaption).foregroundStyle(Brand.faint).multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(width: 380)
        .background(Brand.background)
    }
}
