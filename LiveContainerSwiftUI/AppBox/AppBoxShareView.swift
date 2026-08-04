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

    private let shareURL = URL(string: "appbox://")!
    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    private var qrImage: UIImage { AppBoxQRCodeGenerator.image(for: shareURL.absoluteString) }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack {
                    Image("AppBoxLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(AppBoxBrand.name(for: language))
                        .font(.headline)
                        .foregroundColor(palette.primaryText)

                    Spacer(minLength: 12)

                    Button { dismiss() } label: {
                        AppBoxGlyph(icon: .close)
                            .frame(width: 13, height: 13)
                            .foregroundColor(palette.primaryText)
                            .frame(width: 32, height: 32)
                            .background(palette.mutedSurface)
                            .clipShape(Circle())
                            .frame(width: AppBoxLayout.controlHeight, height: AppBoxLayout.controlHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copy.text("关闭", "Close"))
                }
                .padding(.bottom, 18)

                VStack(spacing: 14) {
                    Text(copy.text("应用聚合 · 安全隔离\n轻松安装 · 独立空间", "One place for your apps\nPrivate, simple, organized"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(palette.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 160, height: 160)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        }

                    Text(
                        copy.text(
                            "扫码查看\(AppBoxBrand.chineseName)",
                            "Scan to view \(AppBoxBrand.englishName)"
                        )
                    )
                        .font(.footnote)
                        .foregroundColor(palette.secondaryText)
                }
                .padding(.bottom, 20)

                Divider()

                HStack(spacing: 36) {
                    shareButton(
                        .cameraImage,
                        copy.text("图片", "Image"),
                        tint: Color(uiColor: .systemOrange)
                    ) {
                        shareItems = [AppBoxSharePosterRenderer.render(language: language, qrImage: qrImage)]
                        showActivity = true
                    }
                    shareButton(.link, copy.text("链接", "Link"), tint: palette.accent) {
                        shareItems = [shareURL]
                        showActivity = true
                    }
                }
                .padding(.top, 16)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(palette.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(palette.border, lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.36 : 0.14), radius: 28, y: 12)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { }
            .transition(.scale(scale: 0.92, anchor: .center).combined(with: .opacity))
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
                    .foregroundColor(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.13))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption)
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)
            }
            .frame(width: 76)
            .frame(minHeight: AppBoxLayout.controlHeight)
            .contentShape(Rectangle())
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
            (AppBoxBrand.name(for: language) as NSString).draw(
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
            let footer = language == .simplifiedChinese
                ? "扫码查看\(AppBoxBrand.chineseName)"
                : "Scan to view \(AppBoxBrand.englishName)"
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
