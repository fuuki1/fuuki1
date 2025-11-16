import SwiftUI
import UIKit

// MARK: - Weekday
public enum Weekday: String, CaseIterable, Hashable, Identifiable {
    case sunday = "日", monday = "月", tuesday = "火", wednesday = "水", thursday = "木", friday = "金", saturday = "土"
    public var id: Self { self }
    
    // Weekday to Int (1=日, 2=月, 3=火, 4=水, 5=木, 6=金, 7=土)
    var toInt: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

// MARK: - Main View
public struct WorkoutScheduleView: View {
    private let brand = Color(hex: "7C4DFF")
    private let calendar = Calendar.current
    
    // 初期表示用に上位から渡される選択済みの曜日（1=日 ... 7=土）
    let selectedWorkoutWeekdays: [Int]
    // 曜日選択を親ビューに渡すためのクロージャ
    let onContinue: ([Int]) -> Void

    public init(
        selectedWorkoutWeekdays: [Int] = [],
        onContinue: @escaping ([Int]) -> Void = { _ in }
    ) {
        self.selectedWorkoutWeekdays = selectedWorkoutWeekdays
        self.onContinue = onContinue
        // 初期選択をStateに反映
        let initialDays = Set(selectedWorkoutWeekdays.compactMap { intVal -> Weekday? in
            switch intVal {
            case 1: return .sunday
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return nil
            }
        })
        _selectedDays = State(initialValue: initialDays)
    }

    @State private var schedule: [Weekday: DateComponents] = {
        var dict: [Weekday: DateComponents] = [:]
        let def = DateComponents(hour: 18, minute: 0)
        Weekday.allCases.forEach { dict[$0] = def }
        return dict
    }()

    @State private var selectedDays: Set<Weekday> = []
    @State private var isReminderOn: Bool = false
    @State private var effectTriggers: [Weekday: Int] = [:]
    @State private var saveButtonPressed = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dataModel: DataModel

    public var body: some View {
        // NavigationStackを削除し、VStackを直接返す
        VStack(spacing: 20) {
            // Title
            Text("ワークアウトをする日を\n設定")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            // Days grid (2-item rows centered without resizing)
            GeometryReader { geo in
                let spacing: CGFloat = 12
                let horizontalPadding: CGFloat = 16.0
                let buttonWidth = (geo.size.width - horizontalPadding*2 - spacing*2) / 3.0
                let contentWidth = geo.size.width - horizontalPadding*2
                let halfWidth = contentWidth / 2.0

                VStack(spacing: spacing) {
                    // Row 1: 日 月 火 (3 items)
                    dayRowView([.sunday, .monday, .tuesday], width: buttonWidth)

                    // Row 2: 水 木（センタリング）
                    dayRowView([.wednesday, .thursday], width: buttonWidth)

                    // Row 3: 金 土（センタリング）
                    dayRowView([.friday, .saturday], width: buttonWidth)

                    // Row 4: 全部（横幅を半分にして中央揃え）
                    HStack {
                        Spacer(minLength: 0)
                        DayChipGlass(
                            day: nil,
                            displayText: "全部",
                            isSelected: selectedDays.count == Weekday.allCases.count,
                            brand: brand,
                            trigger: effectTriggers[.sunday, default: 0],
                            width: halfWidth
                        ) {
                            effectTriggers[.sunday, default: 0] += 1
                            if selectedDays.count == Weekday.allCases.count {
                                selectedDays.removeAll()
                            } else {
                                selectedDays = Set(Weekday.allCases)
                            }
                        }
                        .frame(height: 64)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

            // Reminder section with 
            VStack(spacing: 16) {
                Divider()
                    .padding(.horizontal)

                // Reminder row
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("リマインダー")
                            .font(.headline)
                            .bold()
                        Text("目標に向けて着実に進めるよう助けます")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isReminderOn.animation(.spring(response: 0.4, dampingFraction: 0.8)))
                        .labelsHidden()
                        .tint(brand)
                }
                .padding(.horizontal)

                // Wheel date picker
                if isReminderOn {
                    DatePicker("", selection: sharedTimeBinding, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isReminderOn)

            // Footer button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                saveSchedule()
            } label: {
                Text("続ける")
                    .font(.title3.weight(.bold))
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(
                        Capsule(style: .circular)
                            .fill(Color(UIColor.systemGray3))
                            .overlay(
                                Capsule(style: .circular)
                                    .fill(buttonGradient)
                            )
                            .glassEffect()
                    )
                    .overlay(
                        Capsule(style: .circular)
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    )
                    .scaleEffect(saveButtonPressed ? 0.98 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: saveButtonPressed)
                    .compositingGroup()
            }
            .buttonStyle(.plain)
            .pressEvents(onPress: { saveButtonPressed = true }, onRelease: { saveButtonPressed = false })
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background {
            Color(uiColor: .systemBackground).ignoresSafeArea()
        }
    }

    // MARK: - Rows
    @ViewBuilder
    private func dayRowView(_ days: [Weekday], width: CGFloat) -> some View {
        HStack(spacing: 12) {
            if days.count == 2 { Spacer() }
            ForEach(days, id: \.self) { day in
                DayChipGlass(
                    day: day,
                    displayText: nil,
                    isSelected: selectedDays.contains(day),
                    brand: brand,
                    trigger: effectTriggers[day] ?? 0
                ) {
                    effectTriggers[day, default: 0] += 1
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }
                .frame(width: width)
            }
            if days.count == 2 { Spacer() }
        }
    }

    private var sharedTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let day = selectedDays.first ?? Weekday.allCases.first!
                let comps = schedule[day] ?? DateComponents(hour: 18, minute: 0)
                return calendar.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = calendar.dateComponents([.hour, .minute], from: newValue)
                guard !selectedDays.isEmpty else { return }
                for d in selectedDays { schedule[d] = comps }
            }
        )
    }

    private func saveSchedule() {
        // 選択された曜日をInt配列に変換（1=日, 2=月, 3=火, 4=水, 5=木, 6=金, 7=土）
        let selectedWeekdays = selectedDays.map { $0.toInt }.sorted()
        
        // 何も選択されていない場合は、月・水・金（2, 4, 6）をデフォルトに
        let weekdaysToSave = selectedWeekdays.isEmpty ? [2, 4, 6] : selectedWeekdays
        
        // スケジュールをモデルに変換して DataModel 側の userProfile に保存する
        var dayTimes: [Int: WorkoutTime] = [:]
        for (weekday, comps) in schedule {
            let hour = comps.hour ?? 18
            let minute = comps.minute ?? 0
            dayTimes[weekday.toInt] = WorkoutTime(hour: hour, minute: minute)
        }
        let scheduleModel = WorkoutSchedule(
            selectedWeekdays: weekdaysToSave,
            dayTimes: dayTimes,
            reminderOn: isReminderOn
        )
        dataModel.userProfile.workoutSchedule = scheduleModel
        
        #if DEBUG
        print("Saved days: \(selectedDays.map { $0.rawValue }.sorted())")
        print("Saved weekdays as Int: \(weekdaysToSave)")
        print("Saved schedule: \(schedule)")
        #endif
        
        // 親ビューに曜日を渡す
        onContinue(weekdaysToSave)
    }
    
    private var buttonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 107.0/255.0, green: 94.0/255.0,  blue: 255.0/255.0), location: 0.0),
                .init(color: Color(red: 124.0/255.0, green: 77.0/255.0,  blue: 255.0/255.0), location: 0.62),
                .init(color: Color(red: 140.0/255.0, green: 84.0/255.0,  blue: 255.0/255.0), location: 0.94)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Card Day Chip
private struct DayChipGlass: View {
    let day: Weekday?
    var displayText: String?
    var isSelected: Bool
    var brand: Color
    var trigger: Int
    var width: CGFloat? = nil
    var action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var text: String {
        displayText ?? (day?.rawValue ?? "")
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: width)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .frame(height: 64)
                .contentShape(Rectangle())
                .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous), isSelected: isSelected)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isPressed ? 0.9 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
        .animation(.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: trigger)
    }
}

#if DEBUG
#Preview("Workout Schedule – Glass Card") {
    WorkoutScheduleView(onContinue: { weekdays in
        print("Selected weekdays: \(weekdays)")
    })
    .environmentObject(DataModel())
    .environment(\.locale, Locale(identifier: "ja_JP"))
}
#endif
