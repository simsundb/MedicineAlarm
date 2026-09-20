import SwiftUI

/// 「服药记录」窗口：按天倒序展示每条流水。
struct HistoryView: View {
    @ObservedObject var log: DoseLog
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 500, height: 520)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("服药记录")
                    .font(.system(size: 18, weight: .semibold))
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("关闭") { onClose() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.lg)
        .background(Color.cardSurface)
    }

    private var summary: String {
        let days = log.recentDays(limit: 7)
        let records = days.flatMap(\.records)
        guard !records.isEmpty else { return "还没有记录" }
        let taken = records.filter { $0.status == .taken }.count
        let missed = records.filter { $0.status == .missed }.count
        var text = "最近 7 天：已服用 \(taken)/\(records.count) 次"
        if missed > 0 { text += " · 错过 \(missed) 次" }
        return text
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if log.records.isEmpty {
            VStack(spacing: Theme.Space.md) {
                IconBadge(systemName: "tray", size: 60, tint: .brand)
                Text("还没有记录")
                    .font(.system(size: 14, weight: .medium))
                Text("每次点「已服用」或「稍后提醒」都会记在这里")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(log.recentDays(limit: 30), id: \.day) { group in
                    Section {
                        ForEach(group.records) { record in
                            row(record)
                        }
                    } header: {
                        dayHeader(day: group.day, records: group.records)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private func dayHeader(day: String, records: [DoseRecord]) -> some View {
        let taken = records.filter { $0.status == .taken }.count
        let allTaken = taken == records.count
        return HStack(spacing: Theme.Space.sm) {
            Text(friendlyDay(day))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Text(day)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Text("\(taken)/\(records.count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(allTaken ? Color.statusTaken : Color.secondary)
        }
        .textCase(nil)
    }

    private func row(_ record: DoseRecord) -> some View {
        HStack(spacing: Theme.Space.md) {
            Text(record.scheduledTime)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(width: 52, alignment: .leading)

            Text(record.label)
                .font(.system(size: 13))

            Spacer(minLength: Theme.Space.sm)

            StatusChip(status: record.status)

            Text(clockTime(record.actedAt))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, Theme.Space.xs)
    }

    // MARK: - 文案

    /// "2026-09-16" → "今天" / "昨天" / "9月16日 周三"
    private func friendlyDay(_ dayKey: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dayKey) else { return dayKey }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }

        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = "M月d日 EEE"
        return display.string(from: date)
    }

    private func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
