import SwiftUI

struct AppBoxDecoySpaceView: View {
    let language: AppBoxLanguage
    let skin: AppBoxSkin

    @Environment(\.colorScheme) private var colorScheme
    @State private var tasks: [AppBoxDecoyTask] = AppBoxDecoyTask.defaults
    @State private var quietModeEnabled = true

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            AppBoxFocusBackground(palette: palette)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    overviewCard
                    tasksCard
                    quickSettingsCard
                }
                .padding(.horizontal, AppBoxLayout.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(copy.text("今日", "Today"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(palette.primaryText)

                Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.secondaryText)
            }

            Spacer()

            AppBoxGlyph(icon: .calendarClock)
                .frame(width: 22, height: 22)
                .foregroundColor(palette.accent)
                .frame(width: 52, height: 52)
                .appBoxGlassControl(palette, radius: 26, isInteractive: false)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(copy.text("日程概览", "Schedule"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    Text(copy.text("保持轻量安排，避免遗漏重要事项。", "Keep a light plan and avoid missed items."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 14)

                AppBoxGlyph(icon: .today)
                    .frame(width: 24, height: 24)
                    .foregroundColor(palette.accent)
                    .frame(width: 46, height: 46)
                    .appBoxGlassControl(palette, radius: 18, isInteractive: false)
            }

            HStack(spacing: 10) {
                AppBoxDecoyMetricView(
                    value: "\(tasks.filter(\.isDone).count)/\(tasks.count)",
                    label: copy.text("已完成", "Done"),
                    icon: .checkCircle,
                    palette: palette
                )
                AppBoxDecoyMetricView(
                    value: "25m",
                    label: copy.text("专注", "Focus"),
                    icon: .timer,
                    palette: palette
                )
            }
        }
        .padding(18)
        .appBoxLiquidCard(palette, radius: 24)
    }

    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.text("待办", "Tasks"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(palette.primaryText)
                .padding(.bottom, 2)

            ForEach($tasks) { $task in
                Button {
                    task.isDone.toggle()
                } label: {
                    HStack(spacing: 12) {
                        AppBoxGlyph(icon: task.isDone ? .checkCircle : .circle)
                            .frame(width: 22, height: 22)
                            .foregroundColor(task.isDone ? palette.accent : palette.secondaryText.opacity(0.55))

                        Text(title(for: task))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(task.isDone ? palette.secondaryText : palette.primaryText)
                            .strikethrough(task.isDone, color: palette.secondaryText.opacity(0.5))

                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if task.id != tasks.last?.id {
                    Divider()
                        .overlay(palette.border.opacity(0.55))
                        .padding(.leading, 34)
                }
            }
        }
        .padding(18)
        .appBoxLiquidCard(palette, radius: 24)
    }

    private var quickSettingsCard: some View {
        VStack(spacing: 0) {
            AppBoxDecoySettingRow(
                icon: .pause,
                title: copy.text("休息提醒", "Break Reminder"),
                detail: copy.text("每 45 分钟", "Every 45 min"),
                palette: palette
            )

            Divider()
                .overlay(palette.border.opacity(0.55))
                .padding(.leading, 36)

            Toggle(isOn: $quietModeEnabled) {
                HStack(spacing: 12) {
                    AppBoxGlyph(icon: .timer)
                        .frame(width: 20, height: 20)
                        .foregroundColor(palette.accent)

                    Text(copy.text("轻量模式", "Light Mode"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.primaryText)
                }
            }
            .tint(palette.accent)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .appBoxLiquidCard(palette, radius: 24)
    }

    private func title(for task: AppBoxDecoyTask) -> String {
        copy.text(task.chineseTitle, task.englishTitle)
    }
}

private struct AppBoxDecoyTask: Identifiable, Equatable {
    let id = UUID()
    let chineseTitle: String
    let englishTitle: String
    var isDone: Bool

    static let defaults: [AppBoxDecoyTask] = [
        AppBoxDecoyTask(chineseTitle: "整理今日计划", englishTitle: "Review today's plan", isDone: true),
        AppBoxDecoyTask(chineseTitle: "记录一个灵感", englishTitle: "Capture one note", isDone: false),
        AppBoxDecoyTask(chineseTitle: "完成晚间复盘", englishTitle: "Finish evening review", isDone: false)
    ]
}

private struct AppBoxDecoyMetricView: View {
    let value: String
    let label: String
    let icon: AppBoxIcon
    let palette: AppBoxPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AppBoxGlyph(icon: icon)
                    .frame(width: 18, height: 18)
                    .foregroundColor(palette.accent)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(palette.primaryText)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appBoxGlassControl(palette, radius: 18, isInteractive: false)
    }
}

private struct AppBoxDecoySettingRow: View {
    let icon: AppBoxIcon
    let title: String
    let detail: String
    let palette: AppBoxPalette

    var body: some View {
        HStack(spacing: 12) {
            AppBoxGlyph(icon: icon)
                .frame(width: 20, height: 20)
                .foregroundColor(palette.accent)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(palette.primaryText)

            Spacer()

            Text(detail)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.secondaryText)
        }
        .frame(minHeight: 48)
    }
}
