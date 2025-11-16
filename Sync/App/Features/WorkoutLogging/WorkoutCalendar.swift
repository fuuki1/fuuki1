import SwiftUI

// MARK: - Apple Calendar-style Transition
private struct WorkoutCalendar3DTransitionModifier: ViewModifier {
    var progress: Double
    var isLeading: Bool
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(progress * (isLeading ? -15 : 15)),
                axis: (x: 0, y: 1, z: 0),
                anchor: isLeading ? .leading : .trailing,
                perspective: 0.5
            )
            .offset(x: progress * (isLeading ? -400 : 400))
            .opacity(1 - (progress * 0.4))
            .scaleEffect(1 - (progress * 0.05))
    }
}

/// 横長の Liquid Glass カード(実データ連携版)
struct WorkoutCalendar: View {
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ 実データマネージャーを注入
    @EnvironmentObject private var calendarLogic: CalendarLogicManager
    @EnvironmentObject private var activityData: ActivityDataManager
    
    private let sevenColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    
    // Brand color (#7C4DFF)
    private let brand = Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0)
    
    // Calendar
    private let calendar = Calendar(identifier: .gregorian)
    private let weekdaySymbolsJP = ["日","月","火","水","木","金","土"]

    @State private var selectedDate: Date? = nil
    @State private var slideDirection: SlideDirection = .none
    
    enum SlideDirection {
        case none, left, right
    }
    
    private func monthTitle() -> String {
        let targetDate = selectedDate ?? calendarLogic.weekDates.first ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: targetDate)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        return String(format: "%04d年%02d月", year, month)
    }
    
    private var selectedTileGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 107.0/255.0, green: 94.0/255.0,  blue: 255.0/255.0), location: 0.0),
                .init(color: Color(red: 124.0/255.0, green: 77.0/255.0,  blue: 255.0/255.0), location: 0.62),
                .init(color: Color(red: 140.0/255.0, green: 84.0/255.0,  blue: 255.0/255.0), location: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // label outside, top-left
            Text(monthTitle())
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.top, 0)
                .zIndex(1)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.30),
                                        Color.white.opacity(0.08),
                                        .clear
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.plusLighter)
                    )
                    .shadow(
                        color: (colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.12)),
                        radius: (colorScheme == .dark ? 24 : 12), x: 0, y: (colorScheme == .dark ? 16 : 8)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.40 : 0.10), radius: 2, x: 0, y: 1)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.06) : .clear, radius: 2, x: 0, y: 0)
                
                // コンテンツ
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: sevenColumns, alignment: .center, spacing: 0) {
                        
                        // ✅ calendarLogic.weekDates を使用
                        ForEach(calendarLogic.weekDates.indices, id: \.self) { idx in
                            let date = calendarLogic.weekDates[idx]
                            let isToday = calendar.isDateInToday(date)
                            let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                            
                            // ✅ 実データを取得
                            let dayData = activityData.activityData[date]

                            ZStack {
                                // Base tile
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedTileGradient)
                                        .glassEffect(in: .rect(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .glassEffect(in: .rect(cornerRadius: 12))
                                }
                                
                                // Today ring (only when not selected)
                                if isToday && !isSelected {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedTileGradient, lineWidth: 2)
                                        .blendMode(.plusLighter)
                                }

                                // Content
                                VStack(spacing: 6) {
                                    let weekdayColor: Color = {
                                        if isSelected {
                                            return Color.white.opacity(0.85)
                                        } else if idx == 0 { // Sunday
                                            return Color(red: 1.0, green: 0.45, blue: 0.58) // cute red/pink
                                        } else if idx == 6 { // Saturday
                                            return Color(red: 0.45, green: 0.62, blue: 1.0) // cute blue
                                        } else {
                                            return .secondary
                                        }
                                    }()
                                    
                                    Text(weekdaySymbolsJP[idx])
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(weekdayColor)

                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(isSelected ? Color.white : .primary)
                                    
                                    // ✅ 実際のアクティビティリングを表示
                                    if let data = dayData {
                                        MiniActivityRingsView(
                                            moveProgress: data.move,
                                            exerciseProgress: data.exercise,
                                            standProgress: data.stand
                                        )
                                        .frame(width: 24, height: 24)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                            .frame(height: 92)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onTapGesture { selectedDate = date }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                Text("\(weekdaySymbolsJP[idx])曜日 \(calendar.component(.day, from: date))日" + (isToday ? "(今日)" : ""))
                            )
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    // ✅ calendarLogic.weekOffset を使用
                    .id(calendarLogic.weekOffset)
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.modifier(
                                active: WorkoutCalendar3DTransitionModifier(
                                    progress: 1,
                                    isLeading: slideDirection == .right
                                ),
                                identity: WorkoutCalendar3DTransitionModifier(
                                    progress: 0,
                                    isLeading: slideDirection == .right
                                )
                            ),
                            removal: AnyTransition.modifier(
                                active: WorkoutCalendar3DTransitionModifier(
                                    progress: 1,
                                    isLeading: slideDirection == .left
                                ),
                                identity: WorkoutCalendar3DTransitionModifier(
                                    progress: 0,
                                    isLeading: slideDirection == .left
                                )
                            )
                        )
                    )
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                // ✅ calendarLogicのメソッドを呼び出し
                                if value.translation.width <= -40 {
                                    slideDirection = .left
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)) {
                                        calendarLogic.moveToNextWeek()
                                    }
                                } else if value.translation.width >= 40 {
                                    slideDirection = .right
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)) {
                                        calendarLogic.moveToPreviousWeek()
                                    }
                                }
                            }
                    )
                    .sensoryFeedback(.selection, trigger: calendarLogic.weekOffset)
                }
                .padding(16)
                .clipped()
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 146)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - ミニアクティビティリング用のビュー
struct MiniActivityRingsView: View {
    let moveProgress: Double
    let exerciseProgress: Double
    let standProgress: Double
    
    var body: some View {
        ZStack {
            // Move (Red) - 外側
            Circle()
                .trim(from: 0, to: moveProgress)
                .stroke(Color.red, lineWidth: 2)
                .rotationEffect(.degrees(-90))
            
            // Exercise (Green) - 中央
            Circle()
                .trim(from: 0, to: exerciseProgress)
                .stroke(Color.green, lineWidth: 2)
                .rotationEffect(.degrees(-90))
                .padding(3)
            
            // Stand (Blue) - 内側
            Circle()
                .trim(from: 0, to: standProgress)
                .stroke(Color.blue, lineWidth: 2)
                .rotationEffect(.degrees(-90))
                .padding(6)
        }
    }
}

// --- Preview ---

#Preview("Weekly Burn Card - Static") {
    let dataManager = ActivityDataManager.shared
    let calendarLogic = CalendarLogicManager(dataManager: dataManager)
    
    ZStack {
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 24) {
            WorkoutCalendar()
                .environmentObject(calendarLogic)
                .environmentObject(dataManager)
        }
        .padding(20)
    }
}
