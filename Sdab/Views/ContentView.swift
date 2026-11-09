import SwiftUI

struct ContentView: View {
    enum Tab: Hashable { case library, download }

    @EnvironmentObject private var downloads: DownloadManager
    @AppStorage("defaultKind") private var defaultKind: Track.Kind = .audio
    @AppStorage("videoQuality") private var quality: VideoQuality = .p720

    @State private var tab: Tab = .library
    @State private var alertMessage: String?

    var body: some View {
        TabView(selection: $tab) {
            LibraryView()
                .tabItem { Label("បណ្ណាល័យ", systemImage: "music.note.list") }
                .tag(Tab.library)

            DownloadView()
                .tabItem { Label("ទាញយក", systemImage: "arrow.down.circle") }
                .tag(Tab.download)
        }
        .onOpenURL(perform: handleOpenURL)
        .alert(
            "មិនអាចទាញយក",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("យល់ព្រម", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    /// Supports `sdab://download?url=<link>&kind=audio|video`,
    /// so an iOS Shortcut in the Share sheet can send links straight here.
    private func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == "sdab",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = components.queryItems ?? []
        guard let link = items.first(where: { $0.name == "url" })?.value, !link.isEmpty else { return }
        let kind = items.first(where: { $0.name == "kind" })?.value
            .flatMap { Track.Kind(rawValue: $0.lowercased()) } ?? defaultKind

        tab = .download
        if let message = downloads.start(link: link, kind: kind, quality: quality) {
            alertMessage = message
        }
    }
}
