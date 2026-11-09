import SwiftUI

struct LibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "ទាំងអស់"
        case audio = "សំឡេង"
        case video = "វីដេអូ"
        var id: Self { self }
    }

    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: AudioPlayer

    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var videoToWatch: Track?
    @State private var trackToDelete: Track?

    private var visible: [Track] {
        library.tracks.filter { track in
            let kindMatches: Bool
            switch filter {
            case .all: kindMatches = true
            case .audio: kindMatches = track.kind == .audio
            case .video: kindMatches = track.kind == .video
            }
            return kindMatches && (search.isEmpty || track.title.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if library.tracks.isEmpty {
                    EmptyLibraryView()
                } else {
                    list
                }
            }
            .navigationTitle("បណ្ណាល័យ")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            player.play(visible)
                        } label: {
                            Label("ចាក់ទាំងអស់", systemImage: "play.fill")
                        }
                        Button {
                            player.play(visible.shuffled())
                        } label: {
                            Label("ចាក់ចៃដន្យ", systemImage: "shuffle")
                        }
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .disabled(visible.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) { MiniPlayerBar() }
            .fullScreenCover(item: $videoToWatch) { track in
                VideoPlayerScreen(track: track)
            }
            .confirmationDialog(
                "លុបឯកសារនេះ?",
                isPresented: Binding(
                    get: { trackToDelete != nil },
                    set: { if !$0 { trackToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: trackToDelete
            ) { track in
                Button("លុប", role: .destructive) { delete(track) }
            } message: { track in
                Text(track.title)
            }
        }
    }

    private var list: some View {
        List {
            Picker("តម្រង", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            ForEach(visible) { track in
                Button {
                    player.play(track, in: visible)
                } label: {
                    TrackRow(
                        track: track,
                        isCurrent: player.current?.id == track.id,
                        isPlaying: player.isPlaying
                    )
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        trackToDelete = track
                    } label: {
                        Label("លុប", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        player.play(track, in: visible)
                    } label: {
                        Label("ស្ដាប់", systemImage: "play.fill")
                    }
                    if track.kind == .video {
                        Button {
                            player.pause()
                            videoToWatch = track
                        } label: {
                            Label("មើលវីដេអូ", systemImage: "play.rectangle")
                        }
                    }
                    ShareLink(item: track.fileURL) {
                        Label("ចែករំលែក / រក្សាទុក", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        trackToDelete = track
                    } label: {
                        Label("លុប", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $search, prompt: "ស្វែងរក")
    }

    private func delete(_ track: Track) {
        player.remove(track)
        library.delete(track)
    }
}

struct TrackRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(track: track)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isCurrent ? Color.brand : Color.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: track.kind.symbol)
                    Text(track.kind == .audio ? "M4A" : "MP4")
                    Text("·")
                    Text(track.sizeText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isCurrent {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct ThumbnailView: View {
    let track: Track?
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let url = track?.thumbnailURL, let image = ImageCache.image(at: url) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
                Image(systemName: track?.kind.symbol ?? "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.system(size: 52))
                .foregroundStyle(Color.brand)
            Text("មិនទាន់មានឯកសារទេ")
                .font(.title3.weight(.semibold))
            Text("ចូលទៅ tab «ទាញយក» រួចបិទភ្ជាប់ link YouTube ដើម្បីទុកស្ដាប់ពេលគ្មាន internet។")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
