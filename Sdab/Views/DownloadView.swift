import SwiftUI

struct DownloadView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @AppStorage("defaultKind") private var kind: Track.Kind = .audio
    @AppStorage("videoQuality") private var quality: VideoQuality = .p720

    @State private var link = ""
    @State private var message: String?
    @FocusState private var linkFocused: Bool

    private var canStart: Bool {
        !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("បិទភ្ជាប់ link YouTube នៅទីនេះ", text: $link)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .focused($linkFocused)
                            .onSubmit(startDownload)
                        if !link.isEmpty {
                            Button {
                                link = ""
                                message = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    PasteButton(payloadType: String.self) { strings in
                        guard let pasted = strings.first else { return }
                        Task { @MainActor in
                            link = pasted
                            message = nil
                        }
                    }
                    .labelStyle(.titleAndIcon)
                } header: {
                    Text("Link")
                } footer: {
                    Text("ប្រើបានជាមួយ youtube.com, youtu.be, Shorts និង music.youtube.com")
                }

                Section("ទម្រង់") {
                    Picker("ប្រភេទ", selection: $kind) {
                        ForEach(Track.Kind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if kind == .video {
                        Picker("គុណភាពខ្ពស់បំផុត", selection: $quality) {
                            ForEach(VideoQuality.allCases) { quality in
                                Text(quality.label).tag(quality)
                            }
                        }
                    }
                }

                Section {
                    Button(action: startDownload) {
                        Label("ទាញយក", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canStart)

                    if let message {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !downloads.jobs.isEmpty {
                    Section {
                        ForEach(downloads.jobs) { job in
                            JobRow(job: job)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        downloads.remove(job)
                                    } label: {
                                        Label("លុប", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("ការទាញយក")
                            Spacer()
                            if downloads.jobs.contains(where: { !$0.isActive }) {
                                Button("សម្អាត") { downloads.clearFinished() }
                                    .font(.caption)
                                    .textCase(nil)
                            }
                        }
                    } footer: {
                        Text("សូមបើក app ទុកពេលកំពុងទាញយក។ បើចេញពី app យូរពេក iOS នឹងផ្អាកការទាញយក។")
                    }
                }
            }
            .navigationTitle("ទាញយក")
            .safeAreaInset(edge: .bottom) { MiniPlayerBar() }
        }
    }

    private func startDownload() {
        guard canStart else { return }
        message = downloads.start(link: link, kind: kind, quality: quality)
        if message == nil {
            link = ""
            linkFocused = false
        }
    }
}

private struct JobRow: View {
    @EnvironmentObject private var downloads: DownloadManager
    let job: DownloadManager.Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: job.kind.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(job.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 8)
                actionButton
            }

            switch job.status {
            case .preparing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("កំពុងរៀបចំ…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

            case .downloading:
                ProgressView(value: job.progress)
                Text("\(Int(job.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

            case .merging:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("កំពុងបញ្ចូលរូបភាព និងសំឡេង…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

            case .finished:
                Label("រួចរាល់ — មាននៅក្នុងបណ្ណាល័យ", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)

            case .cancelled:
                Text("បានបោះបង់")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch job.status {
        case .preparing, .downloading, .merging:
            Button { downloads.cancel(job) } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        case .failed, .cancelled:
            Button { downloads.retry(job) } label: {
                Image(systemName: "arrow.clockwise.circle")
            }
            .buttonStyle(.borderless)
        case .finished:
            EmptyView()
        }
    }
}
