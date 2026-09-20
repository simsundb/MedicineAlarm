import SwiftUI

/// 新增 / 编辑单个闹钟的表单。
struct AlarmEditView: View {
    let title: String
    let initial: Alarm
    let onCancel: () -> Void
    let onSave: (Alarm) -> Void

    @State private var time: Date
    @State private var label: String
    @State private var enabled: Bool

    init(
        title: String,
        initial: Alarm,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Alarm) -> Void
    ) {
        self.title = title
        self.initial = initial
        self.onCancel = onCancel
        self.onSave = onSave

        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = initial.hour
        components.minute = initial.minute
        _time = State(initialValue: Calendar.current.date(from: components) ?? Date())
        _label = State(initialValue: initial.label)
        _enabled = State(initialValue: initial.enabled)
    }

    /// 常用名称，点一下就能填上，省得每次打字
    private let suggestions = ["激素服药", "排异服药", "服药", "早餐后", "晚餐后", "睡前"]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            HStack(spacing: Theme.Space.md) {
                IconBadge(systemName: "pills.fill", size: 40, tint: .brand)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }

            field("时间") {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .accessibilityLabel("闹钟时间")
            }

            field("名称") {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    TextField("例如：激素服药", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("闹钟名称")

                    // 快捷填入
                    HStack(spacing: Theme.Space.xs) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { label = suggestion }
                                .buttonStyle(.borderless)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.brand)
                        }
                    }
                }
            }

            field("启用") {
                Toggle("到点提醒我", isOn: $enabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel("到点提醒我")
            }

            Divider()

            HStack {
                Spacer()
                Button("取消", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Theme.Space.xl)
        .frame(width: 400)
    }

    private func field<Content: View>(
        _ name: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
                .padding(.top, Theme.Space.xs)
            content()
            Spacer(minLength: 0)
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        var updated = initial
        updated.hour = components.hour ?? initial.hour
        updated.minute = components.minute ?? initial.minute
        updated.label = label.trimmingCharacters(in: .whitespaces)
        updated.enabled = enabled
        onSave(updated)
    }
}
