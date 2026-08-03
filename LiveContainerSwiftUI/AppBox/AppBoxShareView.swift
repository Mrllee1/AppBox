import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct AppBoxShareView: View {
    let language: AppBoxLanguage
    let skin: AppBoxSkin
    let dismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var shareItems: [Any] = []
    @State private var showActivity = false

    private let shareURL = URL(string: "https://github.com/LiveContainer/LiveContainer")!
    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    private var qrImage: UIImage { AppBoxQRCodeGenerator.image(for: shareURL.absoluteString) }

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.32 : 0.20)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        AppBoxGlyph(icon: .close)
                            .frame(width: 18, height: 18)
                            .foregroundColor(palette.primaryText)
                            .frame(width: 40, height: 40)
                            .appBoxGlassControl(palette, radius: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copy.text("关闭", "Close"))
                }
                .padding(.trailing, 2)

                VStack(spacing: 16) {
                    Image("AppBoxLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.10), radius: 7, y: 3)

                    Text("AppBox")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(palette.primaryText)

                    Text(copy.text("应用聚合 · 安全隔离\n轻松安装 · 独立空间", "One place for your apps\nPrivate, simple, organized"))
                        .font(.system(size: 14, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(palette.secondaryText)
                        .lineSpacing(4)

                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 176, height: 176)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        }

                    Text(copy.text("扫码查看 AppBox", "Scan to view AppBox"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }
                .frame(maxWidth: 330)
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .appBoxSurface(palette, addsShadow: true)

                HStack(spacing: 48) {
                    shareButton(
                        .cameraImage,
                        copy.text("图片", "Image"),
                        tint: Color(red: 0.96, green: 0.55, blue: 0.20)
                    ) {
                        shareItems = [AppBoxSharePosterRenderer.render(language: language, qrImage: qrImage)]
                        showActivity = true
                    }
                    shareButton(.link, copy.text("链接", "Link"), tint: palette.accent) {
                        shareItems = [shareURL]
                        showActivity = true
                    }
                }
            }
            .frame(maxWidth: 330)
            .padding(.horizontal, 28)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .sheet(isPresented: $showActivity) {
            AppBoxActivityView(items: shareItems)
        }
    }

    private func shareButton(
        _ icon: AppBoxIcon,
        _ title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .appBoxGlassControl(palette, radius: 26, tint: tint)
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
    }
}

private enum AppBoxQRCodeGenerator {
    static func image(for value: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}

private enum AppBoxSharePosterRenderer {
    static func render(language: AppBoxLanguage, qrImage: UIImage) -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let iconRect = CGRect(x: 420, y: 150, width: 240, height: 240)
            UIImage(named: "AppBoxLogo")?.draw(in: iconRect)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            ("AppBox" as NSString).draw(
                in: CGRect(x: 80, y: 430, width: 920, height: 90),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: paragraph
                ]
            )

            let subtitle = language == .simplifiedChinese ? "应用聚合 · 安全隔离" : "One place for your apps"
            (subtitle as NSString).draw(
                in: CGRect(x: 80, y: 535, width: 920, height: 60),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 34, weight: .medium),
                    .foregroundColor: UIColor.systemBlue,
                    .paragraphStyle: paragraph
                ]
            )

            qrImage.draw(in: CGRect(x: 300, y: 690, width: 480, height: 480))
            let footer = language == .simplifiedChinese ? "扫码查看 AppBox" : "Scan to view AppBox"
            (footer as NSString).draw(
                in: CGRect(x: 80, y: 1210, width: 920, height: 60),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 30, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: paragraph
                ]
            )
        }
    }
}

private struct AppBoxActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
