# Temp Mail A Surface Design System

## Reference lock

- Structural source: Android Temp Mail `com.tempmail` version 4.09, verified from its installed APK resources and live view hierarchy on the connected Samsung device.
- Platform adaptation: preserve Temp Mail's hierarchy and dimensions while using native SwiftUI navigation, sheets, menus, accessibility, Dynamic Type, and iOS Liquid Glass tab bars.
- Product identity remains this app's own. Do not copy Temp Mail trademarks, store metadata, icon, or subscription UI.

## Visual theme and atmosphere

The A surface is a fast, content-first disposable inbox. The mailbox address and received messages are the focus; decoration retreats. One green accent communicates interaction and unread state. Empty, loading, error, offline, and populated states must all remain useful.

## Color palette and roles

- Accent and positive state: `#18CA88`.
- Light canvas: `#EAEEF2`; light surface: system white.
- Dark canvas: `#303234`; dark surface: `#3C3E40`.
- Primary text: semantic label; secondary text: `#96979F` in light mode and a semantic high-contrast equivalent in dark mode.
- Sender initials: `#6C96F2` on a 14%-15% blue tint.
- Destructive state: system red. Color never carries state alone.

## Typography

- Chinese uses the native system font with weights 400, 500, or 600 only.
- Reading body: 17pt with at least 1.5 line height inside rendered email HTML.
- Inbox sender: 16pt/500-600; subject and preview: 14-15pt/400-500; time and metadata: native caption.
- Email subject: title3/600, maximum two lines. Long sender, address, subject, and attachment names wrap or truncate predictably.

## Components

- Address home: show one mailbox address with only two actions—copy the address and replace it. Do not duplicate inbox navigation or hide repeated copy actions in an overflow menu.
- Address artwork: use an original-drawn 328:398 envelope silhouette with a continuous rounded top edge, a separate 26pt-inset shadow plate, a large folded flap, and a one-shot 110pt mail-flag mark. Preserve the reference hierarchy without embedding third-party artwork.
- The copy action stays inside the envelope with 25pt horizontal and 27pt bottom insets. Replace-address is a quiet icon-and-label command 20pt below the artwork, not a second filled primary button.
- Inbox selector: a single 50pt mailbox picker above content.
- Normal empty inbox is illustration-led: one original pale-paper animation centered in the remaining viewport, without permanent explanatory copy or a permanent retry button. Retry remains available through pull-to-refresh and the toolbar; a dedicated retry control appears only for an actual error state.
- Pull-to-refresh uses the reference's 125pt reveal zone beneath the mailbox picker. Content follows the finger, an original wordless mail-carrier indicator appears above it, and existing messages stay visible while the request runs.
- Message row: 17pt radius surface, 18pt horizontal and 10-12pt vertical padding, unread point, sender, time, subject, real body preview, disclosure indicator, and attachment indicator when present.
- Message detail: subject above one 17pt radius reading surface. The surface contains sender identity, time, a collapsible From/To/Date block, a divider, auto-height HTML or selectable plain text, then attachments.
- Secondary mail actions live in one native sheet opened from the overflow button. Delete remains confirmed.
- HTML mail uses a non-persistent `WKWebView`, disables scripts/forms/frames, adapts to theme, and reports its real content height to SwiftUI.

## Layout principles

- Functional contract: within three seconds the user sees who sent the email, its subject, when it arrived, and the beginning of the body.
- Base spacing is 4pt; primary sequence is 4/7/8/10/12/16/18/20/24.
- Related metadata stays inside the same mail surface. Do not split the header and body into decorative cards.
- Existing content remains visible during refresh. Empty and error states always provide one clear recovery action.

## Depth hierarchy

- Level 0: canvas.
- Level 1: message surfaces with color separation and no heavy shadow; the address envelope alone may use a quiet multi-layer paper shadow plus its recessed shadow plate.
- Level 2: native navigation, Liquid Glass tab bar, sheets, confirmation dialogs, and share/print controllers.
- Use material only for actual floating layers. Do not stack glass surfaces.

## Do and do not

- Do render real previews, long HTML, tables, HTTPS images, CID images supplied by the API, and attachment metadata.
- Do support read state, pull-to-refresh, copy, external links, reply/forward handoff, print, EML export, original source, attachment export, and deletion when data exists.
- Do not show placeholder preview copy when no preview exists; omit the line or say the message has no text.
- Do not enable sender-provided JavaScript, frames, objects, forms, media autoplay, or arbitrary navigation inside the mail WebView.
- Do not force a fixed email-body height or create nested vertical scrolling.

## Responsive behavior

- iPhone uses compact navigation and the native bottom tab bar. iPad keeps readable line lengths and uses platform-appropriate sheets/popovers.
- Dynamic Type may increase row height; it must not hide the subject, preview, or selected mailbox.
- Wide HTML tables scroll horizontally inside the document; the page itself must not overflow horizontally.
- Light, dark, Reduce Motion, and Reduce Transparency follow system settings or the user's explicit appearance choice.

## Motion philosophy

- High-frequency inbox navigation has no decorative entrance animation.
- Address and empty-inbox illustrations animate once on appearance or on a confirmed copy; they never bob forever.
- Pull-to-refresh is continuous and interruptible: reveal progress follows the drag, the carrier loops only while loading, then the content returns in 260ms or less.
- Native swipe actions, disclosure, navigation, and sheets remain interruptible. Reduce Motion replaces illustration transitions with an immediate final state and the loading carrier with a static progress indicator.
- Haptics are limited to confirmed copy/export/state-change actions.

## Reference DNA used

- From Temp Mail 4.09: 17pt card radius, 7pt detail margin, 12pt mail-header padding, `#EAEEF2/#303234/#3C3E40/#18CA88`, and the subject → header → expandable metadata → body → attachments hierarchy.
- From Apple: 44pt minimum touch targets, native SF optical sizing, semantic colors, a single soft 3×5×30-style product shadow adapted to mobile, and platform navigation/print/share behavior.
- From Notion: content-first reading, 1pt whisper borders, restrained four-layer low-opacity surface depth, and a 16-17pt body rhythm.
