import SwiftUI

@main
struct SdabApp: App {
    @StateObject private var library: Library
    @StateObject private var downloads: DownloadManager
    @StateObject private var player = AudioPlayer()

    init() {
        let library = Library()
        _library = StateObject(wrappedValue: library)
        _downloads = StateObject(wrappedValue: DownloadManager(library: library))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(downloads)
                .environmentObject(player)
                .tint(.brand)
        }
    }
}

extension Color {
    /// Accent colour used across the app.
    static let brand = Color(red: 0.91, green: 0.36, blue: 0.29)
}
