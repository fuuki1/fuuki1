import SwiftUI
import HealthKit
import HealthKitUI

// MARK: - Activity Rings (official HKActivityRingView wrapper)
private struct ActivityRingMiniView: UIViewRepresentable {
    var move: Double
    var exercise: Double
    var stand: Double
    var animate: Bool = true

    func makeUIView(context: Context) -> HKActivityRingView {
        HKActivityRingView()
    }

    func updateUIView(_ uiView: HKActivityRingView, context: Context) {
        // Clamp 0...1 and map to ActivitySummary (goals=1.0 so value==progress)
        let m = max(0, min(1, move))
        let e = max(0, min(1, exercise))
        let s = max(0, min(1, stand))

        let summary = HKActivitySummary()
        summary.activeEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: m)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 1.0)
        summary.appleExerciseTime = HKQuantity(unit: HKUnit.minute(), doubleValue: e)
        summary.appleExerciseTimeGoal = HKQuantity(unit: HKUnit.minute(), doubleValue: 1.0)
        summary.appleStandHours = HKQuantity(unit: HKUnit.count(), doubleValue: s)
        summary.appleStandHoursGoal = HKQuantity(unit: HKUnit.count(), doubleValue: 1.0)
        uiView.setActivitySummary(summary, animated: animate)
    }
}

// MARK: - Apple Calendar-style Transition
private struct AppleCalendarTransitionModifier: ViewModifier {
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

/// 横長の Liquid Glass カード。
/// CalendarLogicManager と連動して実際のHealthKitデータを表示
struct WeeklyBurnCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ 親View (HomeView) からマネージャーを注入してもらう
    @ObservedObject var calendarManager: CalendarLogicManager
    
    private let sevenColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    
    // Brand color (#7C4DFF)
    private let brand = Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0)
    
    // Calendar
    private let calendar = Calendar(identifier: .gregorian)
    @State private var selectedDate: Date? = nil
    
    // ✅ アニメーション用の状態
    @State private var slideDirection: SlideDirection = .none
    
    enum SlideDirection {
        case none, left, right
    }
    
    // ✅ Manager から週の日付を取得
    private var weekDates: [Date] {
        calendarManager.weekDates
    }
    
    // ✅ Manager を経由してデータ取得
    private func ringProgress(for date: Date) -> ActivityProgress {
        let startOfDay = calendar.startOfDay(for: date)
        // データがあればそれを返す、なければゼロ
        return calendarManager.dataManager.activityData[startOfDay] ?? .zero
    }
    
    private let weekdaySymbolsJP = ["日","月","火","水","木","金","土"]
    
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
                    // ✅ Manager の weekDates を使用
                    ForEach(weekDates.indices, id: \.self) { idx in
                        let date = weekDates[idx]
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

                        GlassEffectContainer {
                            ZStack {
                                // Base tile
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(selectedTileGradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .glassEffect()
                                    }
                                }

                                // Content
                                VStack(spacing: 6) {
                                    Text(weekdaySymbolsJP[idx])
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)

                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(isSelected ? Color.white : .primary)

                                    // Activity Rings
                                    let p = ringProgress(for: date)
                                    ActivityRingMiniView(move: p.move, exercise: p.exercise, stand: p.stand, animate: true)
                                        .frame(width: 24, height: 24)
                                        .allowsHitTesting(false)
                                }
                                .padding(.vertical, 10)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isSelected ? brand : (isToday ? Color.white.opacity(0.28) : Color.white.opacity(colorScheme == .dark ? 0.10 : 0.16)),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                                    .blendMode(isSelected ? .plusLighter : .normal)
                            )
                            .shadow(color: isSelected ? Color.black.opacity(0.12) : .clear, radius: isSelected ? 8 : 0, x: 0, y: 2)
                            .frame(height: 92)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onTapGesture { selectedDate = date }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("\(weekdaySymbolsJP[idx])曜日 \(calendar.component(.day, from: date))日"))
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                // ✅ Apple Calendar風の3Dアニメーション
                .id(calendarManager.weekOffset) // 週が変わるたびに再生成
                .transition(
                    .asymmetric(
                        insertion: AnyTransition.modifier(
                            active: AppleCalendarTransitionModifier(
                                progress: 1,
                                isLeading: slideDirection == .right
                            ),
                            identity: AppleCalendarTransitionModifier(
                                progress: 0,
                                isLeading: slideDirection == .right
                            )
                        ),
                        removal: AnyTransition.modifier(
                            active: AppleCalendarTransitionModifier(
                                progress: 1,
                                isLeading: slideDirection == .left
                            ),
                            identity: AppleCalendarTransitionModifier(
                                progress: 0,
                                isLeading: slideDirection == .left
                            )
                        )
                    )
                )
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // ✅ Manager の関数を呼び出す
                            if value.translation.width <= -40 {
                                slideDirection = .left
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)) {
                                    calendarManager.goToNextWeek()
                                }
                            } else if value.translation.width >= 40 {
                                slideDirection = .right
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0)) {
                                    calendarManager.goToPreviousWeek()
                                }
                            }
                        }
                )
                // ✅ Manager の状態を監視
                .sensoryFeedback(.selection, trigger: calendarManager.weekOffset)
            }
            .padding(16)
            .clipped() // ✅ アニメーション時に前後の週が見えないようにクリッピング
        }
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear {
            // ✅ Manager に初回データ取得をキック
            calendarManager.activate()
        }
    }
}

// --- ここから Preview 専用のセットアップ ---
// ✅ 修正: Previewマクロの「外」にヘルパークラスを定義します

/// Preview専用のダミーデータマネージャー
/// `fetchWeeklyData` が呼ばれるたびに、その週のダミーデータを動的に生成する
fileprivate class PreviewDataManager: ActivityDataManager {
    let calendar = Calendar(identifier: .gregorian)
    
    @MainActor
    override func fetchWeeklyData(startDate: Date) async {
        var dummyData: [Date: ActivityProgress] = [:]
        
        // `startDate` から始まる週の7日間のデータを生成
        // (CalendarLogicManagerの週計算ロジックと合わせる)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)) ?? startDate
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let startOfDay = calendar.startOfDay(for: date)
                
                // 週ごとに異なるユニークな値を生成 (日付のハッシュを元に)
                let progress = abs(sin(Double(startOfDay.hashValue) / 1_000_000_000.0)) // 0.0〜1.0
                
                dummyData[startOfDay] = ActivityProgress(
                    move: min(1.0, 0.2 + progress * 0.7),
                    exercise: min(1.0, 0.15 + progress * 0.6),
                    stand: min(1.0, 0.25 + progress * 0.65)
                )
            }
        }
        
        // データをセットしてUIを更新
        self.activityData = dummyData
        self.isAuthorized = true
    }
}

// --- ここまで Preview 専用のセットアップ ---


#Preview("Weekly Burn Card - Integrated") {
    
    // 実際のPreview本体
    ZStack {
        Color(UIColor.systemGroupedBackground).ignoresSafeArea() // 背景色
        VStack(spacing: 24) {
            
            // ✅ PreviewDataManager を使用
            let dataManager = PreviewDataManager()
            let calendarManager = CalendarLogicManager(dataManager: dataManager)
            
            WeeklyBurnCard(calendarManager: calendarManager)
        }
        .padding(20)
    }
}
