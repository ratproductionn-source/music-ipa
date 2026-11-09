import AVKit
import SwiftUI

/// Small bar above the tab bar while something is loaded.
struct MiniPlayerBar: View {
    @EnvironmentObject private var player: AudioPlayer
    @State private var showFullPlayer = false

    var body: some View {
        if let track = player.current {
            HStack(spacing: 12) {
                ThumbnailView(track: track, size: 42, cornerRadius: 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    ProgressView(value: player.duration > 0 ? min(player.currentTime / player.duration, 1) : 0)
                }
                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .frame(width: 32, height: 36)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { showFullPlayer = true }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .sheet(isPresented: $showFullPlayer) {
                NowPlayingView()
                    .environmentObject(player)
            }
        }
    }
}

/// Full-screen player sheet.
struct NowPlayingView: View {
    @EnvironmentObject private var player: AudioPlayer
    @State private var scrubValue: Double?
    @State private var videoToWatch: Track?

    private let rates: [Float] = [0.75, 1, 1.25, 1.5, 2]

    private var shownTime: Double { scrubValue ?? player.currentTime }

    var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Spacer(minLength: 0)

            ThumbnailView(track: player.current, size: 280, cornerRadius: 22)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            Text(player.current?.title ?? "")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { shownTime }, set: { scrubValue = $0 }),
                    in: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        if !editing, let value = scrubValue {
                            player.seek(to: value)
                            scrubValue = nil
                        }
                    }
                )
                HStack {
                    Text(formatTime(shownTime))
                    Spacer()
                    Text("-" + formatTime(max(player.duration - shownTime, 0)))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)

            HStack(spacing: 26) {
                Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
                Button { player.previous() } label: { Image(systemName: "backward.fill") }
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 66))
                        .foregroundStyle(Color.brand)
                }
                Button { player.next() } label: { Image(systemName: "forward.fill") }
                Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
            }
            .font(.title2)
            .buttonStyle(.plain)

            HStack {
                Menu {
                    ForEach(rates, id: \.self) { rate in
                        Button(String(format: "%gx", Double(rate))) { player.rate = rate }
                    }
                } label: {
                    Text(String(format: "%gx", Double(player.rate)))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(minWidth: 44)
                }

                Spacer()

                Button { player.cycleRepeat() } label: {
                    Image(systemName: player.repeatMode.symbol)
                        .foregroundStyle(player.repeatMode == .off ? Color.secondary : Color.brand)
                }

                if player.current?.kind == .video {
                    Spacer()
                    Button {
                        if let track = player.current {
                            player.pause()
                            videoToWatch = track
                        }
                    } label: {
                        Image(systemName: "play.rectangle")
                    }
                }

                Spacer()

                RoutePicker()
                    .frame(width: 32, height: 32)
            }
            .font(.title3)
            .padding(.horizontal, 36)

            Spacer(minLength: 0)
        }
        .presentationDragIndicator(.hidden)
        .fullScreenCover(item: $videoToWatch) { track in
            VideoPlayerScreen(track: track, startAt: player.currentTime)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Plays a downloaded MP4 with picture.
struct VideoPlayerScreen: View {
    let track: Track
    var startAt: Double = 0

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .padding()
        }
        .onAppear {
            let newPlayer = AVPlayer(url: track.fileURL)
            if startAt > 0 {
                newPlayer.seek(to: CMTime(seconds: startAt, preferredTimescale: 600))
            }
            newPlayer.play()
            player = newPlayer
        }
        .onDisappear {
            player?.pause()
        }
    }
}

/// AirPlay / Bluetooth output picker.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = .secondaryLabel
        view.activeTintColor = .tintColor
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
