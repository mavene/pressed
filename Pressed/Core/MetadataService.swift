import UIKit
import LinkPresentation
import UniformTypeIdentifiers

struct MetadataResult {
    var title: String?
    var siteName: String?
    var imageData: Data?
    var kind: CardKind
    var estMinutes: Int?
}

/// Fills in title, picture, kind and read time. Runs in the main app so saving stays instant.
@MainActor
final class MetadataService {
    static let shared = MetadataService()

    private var inFlight = Set<UUID>()
    private var attempted = Set<UUID>()

    /// Looks up every pending card that has no title yet. Each card is tried once per launch.
    func enrichMissing() {
        for record in CardStore.shared.fetchPending() where record.title == nil && !attempted.contains(record.id) {
            enrich(record)
        }
    }

    func enrich(_ record: CardRecord) {
        guard inFlight.insert(record.id).inserted else { return }
        attempted.insert(record.id)
        let id = record.id
        let url = record.url
        Task { @MainActor in
            let result = await MetadataService.fetch(url: url)
            CardStore.shared.updateMetadata(id: id, result: result)
            self.inFlight.remove(id)
        }
    }

    // MARK: Fetching

    private static func fetch(url: URL) async -> MetadataResult {
        async let linkInfo = fetchLinkPresentation(url)
        async let htmlResult = fetchHTML(url)
        let (lpTitle, lpImage) = await linkInfo
        let html = await htmlResult

        var info: PageInfo?
        if let html {
            info = await Task.detached(priority: .utility) {
                PageParser.parse(html: html, base: url)
            }.value
        }

        var imageData = lpImage
        if imageData == nil, let imageURL = info?.imageURL {
            imageData = await downloadImage(imageURL)
        }
        var thumbnail: Data?
        if let imageData {
            thumbnail = await Task.detached(priority: .utility) {
                MetadataService.makeThumbnail(imageData)
            }.value
        }

        let kind = KindDetector.detect(url: url, isRecipePage: info?.isRecipe ?? false)
        let minutes: Int?
        switch kind {
        case .video, .podcast: minutes = info?.durationMinutes
        case .article: minutes = info?.readMinutes
        default: minutes = nil
        }

        let cleanLPTitle = lpTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MetadataResult(
            title: (cleanLPTitle?.isEmpty ?? true) ? info?.title : cleanLPTitle,
            siteName: info?.siteName,
            imageData: thumbnail,
            kind: kind,
            estMinutes: minutes
        )
    }

    private static func fetchLinkPresentation(_ url: URL) async -> (String?, Data?) {
        let provider = LPMetadataProvider()
        provider.timeout = 8
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return (nil, nil) }
        var image: Data?
        if let imageProvider = metadata.imageProvider {
            image = await loadImageData(imageProvider)
        }
        return (metadata.title, image)
    }

    private static func loadImageData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private nonisolated static func fetchHTML(_ url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }
        return String(decoding: data.prefix(1_500_000), as: UTF8.self)
    }

    private nonisolated static func downloadImage(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count < 6_000_000 else { return nil }
        return data
    }

    /// Shrinks a picture to a small JPEG so the store stays light.
    nonisolated static func makeThumbnail(_ data: Data, maxDimension: CGFloat = 360) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
