import SwiftUI
import UIKit

/// Original artwork that preserves the dimensional hierarchy of the reference
/// screen without embedding or tracing its third-party vector assets.
struct TempMailEnvelopeBackdrop: View {
  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack(alignment: .top) {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
          .fill(TempMailPalette.envelopeShadowPlate)
          .frame(width: max(0, width - 52), height: height * 0.82)
          .offset(y: height * 0.23)
          .shadow(color: TempMailPalette.shadowColor.opacity(0.025), radius: 3, y: 1)

        TempMailEnvelopeShellShape()
          .fill(TempMailPalette.surface)
          .overlay {
            TempMailEnvelopeShellShape()
              .stroke(TempMailPalette.whisperBorder, lineWidth: 1)
          }
          .shadow(color: TempMailPalette.shadowColor.opacity(0.04), radius: 18, y: 4)
          .shadow(color: TempMailPalette.shadowColor.opacity(0.025), radius: 8, y: 2)
          .shadow(color: TempMailPalette.shadowColor.opacity(0.016), radius: 3, y: 1)

        TempMailEnvelopeFoldShape()
          .fill(
            LinearGradient(
              colors: [TempMailPalette.envelopeFoldTop, TempMailPalette.envelopeFoldBottom],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .overlay {
            TempMailEnvelopeFoldShape()
              .stroke(TempMailPalette.whisperBorder.opacity(0.7), lineWidth: 0.8)
          }
          .frame(height: height * 0.42)
          .offset(y: height * 0.16)
      }
    }
    .allowsHitTesting(false)
  }
}

struct TempMailAnimatedFlagMark: View {
  let isRaised: Bool

  var body: some View {
    GeometryReader { proxy in
      let unit = min(proxy.size.width, proxy.size.height) / 110

      ZStack {
        Circle()
          .fill(TempMailPalette.softGreen.opacity(0.72))
          .frame(width: 88 * unit, height: 88 * unit)

        RoundedRectangle(cornerRadius: 13 * unit, style: .continuous)
          .fill(TempMailPalette.envelope)
          .overlay {
            RoundedRectangle(cornerRadius: 13 * unit, style: .continuous)
              .stroke(TempMailPalette.whisperBorder, lineWidth: max(0.8, unit))
          }
          .frame(width: 65 * unit, height: 48 * unit)
          .offset(x: -5 * unit, y: 8 * unit)
          .shadow(color: TempMailPalette.shadowColor.opacity(0.07), radius: 5 * unit, y: 3 * unit)

        Path { path in
          path.move(to: CGPoint(x: 26 * unit, y: 51 * unit))
          path.addLine(to: CGPoint(x: 51 * unit, y: 67 * unit))
          path.addLine(to: CGPoint(x: 76 * unit, y: 51 * unit))
        }
        .stroke(
          TempMailPalette.green,
          style: StrokeStyle(lineWidth: max(2, 2.6 * unit), lineCap: .round, lineJoin: .round)
        )

        Capsule()
          .fill(TempMailPalette.darkGreen)
          .frame(width: 4 * unit, height: 45 * unit)
          .offset(x: 27 * unit, y: -5 * unit)

        TempMailFlagShape()
          .fill(TempMailPalette.green)
          .frame(width: 32 * unit, height: 24 * unit)
          .rotationEffect(.degrees(isRaised ? 0 : 34), anchor: .bottomLeading)
          .offset(x: 43 * unit, y: -24 * unit)

        Circle()
          .fill(TempMailPalette.green)
          .frame(width: 9 * unit, height: 9 * unit)
          .overlay(Circle().stroke(TempMailPalette.surface, lineWidth: max(1, 1.5 * unit)))
          .offset(x: 27 * unit, y: 17 * unit)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityHidden(true)
  }
}

struct TempMailEmptyInboxArtwork: View {
  let animationsEnabled: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealed = false

  var body: some View {
    GeometryReader { proxy in
      let scale = min(proxy.size.width / 330, proxy.size.height / 420, 1)

      ZStack {
        Ellipse()
          .fill(TempMailPalette.shadowColor.opacity(0.055))
          .frame(width: 214 * scale, height: 30 * scale)
          .offset(y: 119 * scale)

        RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
          .fill(TempMailPalette.paperSecondary)
          .overlay(alignment: .topLeading) {
            TempMailLetterLines(scale: scale)
              .padding(.top, 25 * scale)
              .padding(.leading, 21 * scale)
          }
          .frame(width: 170 * scale, height: 204 * scale)
          .rotationEffect(.degrees(revealed ? -7 : 0))
          .offset(x: -30 * scale, y: (revealed ? -58 : 8) * scale)
          .opacity(revealed ? 1 : 0.18)

        RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
          .fill(TempMailPalette.paperPrimary)
          .overlay(alignment: .topLeading) {
            TempMailLetterLines(scale: scale)
              .padding(.top, 25 * scale)
              .padding(.leading, 21 * scale)
          }
          .overlay {
            RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
              .stroke(TempMailPalette.whisperBorder.opacity(0.8), lineWidth: 1)
          }
          .frame(width: 176 * scale, height: 214 * scale)
          .rotationEffect(.degrees(revealed ? 5 : 0))
          .offset(x: 29 * scale, y: (revealed ? -46 : 12) * scale)
          .opacity(revealed ? 1 : 0.18)
          .shadow(color: TempMailPalette.shadowColor.opacity(0.035), radius: 9 * scale, y: 4 * scale)

        TempMailOpenEnvelopeShape()
          .fill(TempMailPalette.paperPrimary)
          .overlay {
            TempMailOpenEnvelopeShape()
              .stroke(TempMailPalette.whisperBorder, lineWidth: 1)
          }
          .frame(width: 254 * scale, height: 162 * scale)
          .offset(y: 67 * scale)
          .shadow(color: TempMailPalette.shadowColor.opacity(0.045), radius: 12 * scale, y: 7 * scale)

        TempMailEnvelopeLipShape()
          .fill(TempMailPalette.paperSecondary)
          .frame(width: 254 * scale, height: 112 * scale)
          .offset(y: 42 * scale)

        Circle()
          .fill(TempMailPalette.green.opacity(0.86))
          .frame(width: 12 * scale, height: 12 * scale)
          .offset(x: -102 * scale, y: revealed ? -121 * scale : -84 * scale)
          .opacity(revealed ? 1 : 0)

        Circle()
          .fill(TempMailPalette.green.opacity(0.44))
          .frame(width: 7 * scale, height: 7 * scale)
          .offset(x: 105 * scale, y: revealed ? -96 * scale : -72 * scale)
          .opacity(revealed ? 1 : 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      guard !revealed else { return }
      if animationsEnabled && !reduceMotion {
        withAnimation(.easeOut(duration: 0.26)) { revealed = true }
      } else {
        revealed = true
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("收件箱暂无邮件")
  }
}

struct TempMailPullToRefreshScrollView<Content: View>: View {
  let isRefreshing: Bool
  let animationsEnabled: Bool
  let refresh: () async -> Void
  @ViewBuilder let content: () -> Content

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pullDistance: CGFloat = 0
  @State private var isArmed = false
  @State private var isDragging = false

  private let revealHeight: CGFloat = 125
  private let triggerDistance: CGFloat = 62.5

  var body: some View {
    GeometryReader { viewport in
      ZStack(alignment: .top) {
        TempMailCarrierIndicator(
          progress: isRefreshing ? 1 : min(1, pullDistance / triggerDistance),
          isRefreshing: isRefreshing,
          isAnimating: isRefreshing && animationsEnabled && !reduceMotion
        )
        .frame(height: revealHeight)
        .offset(y: isRefreshing ? 0 : -revealHeight + min(revealHeight, pullDistance))
        .opacity(isRefreshing ? 1 : min(1, pullDistance / 28))

        ScrollView {
          VStack(spacing: 0) {
            GeometryReader { proxy in
              Color.clear.preference(
                key: TempMailPullDistanceKey.self,
                value: max(0, proxy.frame(in: .named("temp-mail-refresh")).minY)
              )
            }
            .frame(height: 0)

            content()
              .frame(maxWidth: .infinity)
              .frame(minHeight: max(0, viewport.size.height - 1), alignment: .top)
          }
        }
        .scrollBounceBehavior(.always)
        .coordinateSpace(name: "temp-mail-refresh")
        .offset(y: isRefreshing ? revealHeight : 0)
        .animation(
          animationsEnabled && !reduceMotion ? .easeOut(duration: 0.26) : nil,
          value: isRefreshing
        )
        .simultaneousGesture(
          DragGesture(minimumDistance: 8)
            .onChanged { _ in
              isDragging = true
            }
            .onEnded { _ in
              let shouldRefresh = isArmed && pullDistance >= triggerDistance * 0.72 && !isRefreshing
              isDragging = false
              isArmed = false
              guard shouldRefresh else { return }
              Task { await refresh() }
            }
        )
      }
      .clipped()
      .onPreferenceChange(TempMailPullDistanceKey.self) { value in
        pullDistance = isRefreshing ? 0 : value
        guard !isRefreshing else {
          isArmed = false
          return
        }
        if value >= triggerDistance, !isArmed {
          isArmed = true
          UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else if isDragging, value < triggerDistance * 0.72, isArmed {
          isArmed = false
        }
      }
    }
  }
}

private struct TempMailCarrierIndicator: View {
  let progress: CGFloat
  let isRefreshing: Bool
  let isAnimating: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { timeline in
      let phase = isAnimating
        ? sin(timeline.date.timeIntervalSinceReferenceDate * 13) * 10
        : (1 - progress) * 12

      HStack(spacing: 12) {
        Spacer(minLength: 24)

        HStack(spacing: 5) {
          Capsule()
            .fill(TempMailPalette.letterLine.opacity(0.22))
            .frame(width: 30, height: 3)
          Capsule()
            .fill(TempMailPalette.letterLine.opacity(0.38))
            .frame(width: 18, height: 3)
          Capsule()
            .fill(TempMailPalette.letterLine.opacity(0.54))
            .frame(width: 9, height: 3)
        }
        .offset(x: (1 - progress) * 22)
        .opacity(progress)

        ZStack {
          Capsule()
            .fill(TempMailPalette.paperSecondary)
            .frame(width: 27, height: 17)
            .rotationEffect(.degrees(-22 - phase), anchor: .trailing)
            .offset(x: -18, y: -3)

          Capsule()
            .fill(TempMailPalette.paperSecondary)
            .frame(width: 27, height: 17)
            .rotationEffect(.degrees(22 + phase), anchor: .leading)
            .offset(x: 18, y: -3)

          Capsule()
            .fill(TempMailPalette.green)
            .frame(width: 39, height: 30)

          HStack(spacing: 7) {
            Circle().fill(Color.white).frame(width: 6, height: 6)
            Circle().fill(Color.white).frame(width: 6, height: 6)
          }
          .offset(y: -3)

          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white)
            .overlay {
              Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(TempMailPalette.green)
            }
            .frame(width: 25, height: 17)
            .offset(y: 17)
        }
        .frame(width: 86, height: 52)
        .scaleEffect(0.94 + 0.06 * progress)

        Spacer(minLength: 30)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isRefreshing ? "正在刷新收件箱" : "下拉刷新收件箱")
  }
}

private struct TempMailLetterLines: View {
  let scale: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 10 * scale) {
      Capsule().fill(TempMailPalette.letterLine).frame(width: 82 * scale, height: 8 * scale)
      Capsule().fill(TempMailPalette.letterLine.opacity(0.78)).frame(width: 126 * scale, height: 7 * scale)
      Capsule().fill(TempMailPalette.letterLine.opacity(0.62)).frame(width: 104 * scale, height: 7 * scale)
      HStack(spacing: 7 * scale) {
        Circle().fill(TempMailPalette.green.opacity(0.7)).frame(width: 12 * scale, height: 12 * scale)
        Capsule().fill(TempMailPalette.letterLine.opacity(0.54)).frame(width: 70 * scale, height: 7 * scale)
      }
      .padding(.top, 7 * scale)
    }
  }
}

private struct TempMailEnvelopeShellShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let r = min(28, w * 0.085)
    var path = Path()

    path.move(to: CGPoint(x: r, y: 0))
    path.addLine(to: CGPoint(x: w - r, y: 0))
    path.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
    path.addLine(to: CGPoint(x: w, y: h - r))
    path.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))
    path.addLine(to: CGPoint(x: r, y: h))
    path.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
    path.addLine(to: CGPoint(x: 0, y: r))
    path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
    path.closeSubpath()
    return path
  }
}

private struct TempMailEnvelopeFoldShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX * 0.89, y: rect.maxY * 0.60))
    path.addQuadCurve(
      to: CGPoint(x: rect.midX * 1.11, y: rect.maxY * 0.60),
      control: CGPoint(x: rect.midX, y: rect.maxY * 0.68)
    )
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

private struct TempMailFlagShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.14))
    path.addLine(to: CGPoint(x: rect.maxX * 0.78, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.86))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

private struct TempMailOpenEnvelopeShape: Shape {
  func path(in rect: CGRect) -> Path {
    let r = min(18, rect.height * 0.12)
    var path = Path()
    path.move(to: CGPoint(x: r, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
    path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: r, y: rect.maxY))
    path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    path.addQuadCurve(to: CGPoint(x: r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
    path.closeSubpath()
    return path
  }
}

private struct TempMailEnvelopeLipShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.84))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

private struct TempMailPullDistanceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
