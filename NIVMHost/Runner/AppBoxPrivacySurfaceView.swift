import SwiftUI

/// Hosts the complete temporary-mail product surface inside AppBox's existing
/// UIKit A/B coordinator. The coordinator remains the sole owner of surface
/// transitions; this view owns only the first-party mailbox experience.
struct AppBoxPrivacySurfaceView: View {
  @StateObject private var store = TempMailStore()
  private let onInternalUnlock: () -> Void

  init(onInternalUnlock: @escaping () -> Void = {}) {
    self.onInternalUnlock = onInternalUnlock
  }

  var body: some View {
    TempMailRootView(onInternalUnlock: onInternalUnlock)
      .environmentObject(store)
  }
}
