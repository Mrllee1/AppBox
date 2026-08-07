import CryptoKit
import SwiftUI

struct AppBoxEncryptedImageView<Placeholder: View>: View {
    let url: URL?
    let cornerRadius: CGFloat
    let placeholder: () -> Placeholder

    @StateObject private var loader = AppBoxEncryptedImageLoader()

    init(
        url: URL?,
        cornerRadius: CGFloat,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            await loader.load(url)
        }
    }
}

@MainActor
private final class AppBoxEncryptedImageLoader: ObservableObject {
    @Published var image: UIImage?

    private static let cache = NSCache<NSURL, UIImage>()

    func load(_ url: URL?) async {
        guard let url else {
            image = nil
            return
        }

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let resolved = Self.decodeImage(data) else {
                image = nil
                return
            }
            Self.cache.setObject(resolved, forKey: url as NSURL)
            image = resolved
        } catch {
            image = nil
        }
    }

    private static func decodeImage(_ data: Data) -> UIImage? {
        if let plain = UIImage(data: data) {
            return plain
        }

        guard let decrypted = LCUtils.appBoxDecryptAESCBCData(
            data,
            key: AppBoxAssetImageCrypto.defaultKey,
            iv: AppBoxAssetImageCrypto.defaultIV
        ) as Data? else {
            return nil
        }
        return UIImage(data: decrypted)
    }
}

private enum AppBoxAssetImageCrypto {
    static let defaultKey = Data(SHA256.hash(data: Data("appbox-asset-image-key-v1".utf8)))
    static let defaultIV = Data(SHA256.hash(data: Data("appbox-asset-image-iv-v1".utf8))).prefix(16)
}
