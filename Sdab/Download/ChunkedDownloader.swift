import Foundation

enum DownloadError: LocalizedError {
    case invalidLink
    case noStream
    case badResponse
    case http(Int)
    case mergeFailed

    var errorDescription: String? {
        switch self {
        case .invalidLink: return "Link YouTube មិនត្រឹមត្រូវ"
        case .noStream: return "រកមិនឃើញ format ដែលអាចទាញយកបាន"
        case .badResponse: return "Server ឆ្លើយតបមិនត្រឹមត្រូវ"
        case .http(let code): return "Server បដិសេធ (HTTP \(code)) — សាកម្ដងទៀត"
        case .mergeFailed: return "មិនអាចបញ្ចូលរូបភាព និងសំឡេងបាន"
        }
    }
}

/// Downloads a file in small HTTP Range pieces.
///
/// YouTube slows down one long request to roughly playback speed, but serves
/// short range requests at full speed. Pieces also give a smooth progress bar
/// and let a single failed piece be retried instead of the whole file.
enum ChunkedDownloader {
    static let chunkSize: Int64 = 2 * 1024 * 1024

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func download(
        from url: URL,
        to destination: URL,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        fm.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        var offset: Int64 = 0
        var total: Int64?

        while true {
            try Task.checkCancellation()
            let (data, response) = try await fetchChunk(url: url, from: offset)

            switch response.statusCode {
            case 200:
                // Server ignored the Range header and sent the whole file.
                try handle.write(contentsOf: data)
                await onProgress(1)
                return

            case 206:
                if total == nil { total = totalLength(from: response) }
                if data.isEmpty { return }
                try handle.write(contentsOf: data)
                offset += Int64(data.count)

                if let total {
                    await onProgress(min(Double(offset) / Double(total), 1))
                    if offset >= total { return }
                } else if Int64(data.count) < chunkSize {
                    return
                }

            case 416:
                // Asked for bytes past the end: the file is complete.
                return

            default:
                throw DownloadError.http(response.statusCode)
            }
        }
    }

    private static func fetchChunk(url: URL, from offset: Int64, attempts: Int = 4) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = DownloadError.badResponse
        for attempt in 0..<attempts {
            try Task.checkCancellation()
            do {
                var request = URLRequest(url: url)
                request.setValue("bytes=\(offset)-\(offset + chunkSize - 1)", forHTTPHeaderField: "Range")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw DownloadError.badResponse }
                if (500...599).contains(http.statusCode) { throw DownloadError.http(http.statusCode) }
                return (data, http)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000)
            }
        }
        throw lastError
    }

    /// Reads the full size from a header like `Content-Range: bytes 0-2097151/48213112`.
    private static func totalLength(from response: HTTPURLResponse) -> Int64? {
        guard let range = response.value(forHTTPHeaderField: "Content-Range"),
              let slash = range.lastIndex(of: "/") else { return nil }
        return Int64(range[range.index(after: slash)...])
    }
}
