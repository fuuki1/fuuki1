import SwiftUI
import SwiftData

struct ExerciseDatabaseView: View {

    @StateObject private var activityDataManager = ActivityDataManager.shared
    @StateObject private var calendarLogic: CalendarLogicManager
    

    init() {
        _calendarLogic = StateObject(wrappedValue: CalendarLogicManager(dataManager: ActivityDataManager.shared))
    }
    
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // カレンダーセクション
                    VStack(alignment: .leading, spacing: 12) {
                        WorkoutCalendar()
                            .environmentObject(calendarLogic)
                            .environmentObject(activityDataManager)
                    }
                    // ボタンセクション
                    HStack(spacing: 16) {
                        ActivityCardView(
                            navigationPath: $navigationPath,
                            onStartWorkout: {
                                navigationPath.append(WorkoutNavigationDestination.aiPlanView)
                            },
                            onAddActivity: {
                                navigationPath.append(WorkoutNavigationDestination.recordView)
                            }
                        )
                        .environmentObject(activityDataManager)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: WorkoutNavigationDestination.self) { destination in
                switch destination {
                case .aiPlanView:
                    AIPlanButtonView(navigationPath: $navigationPath)
                case .standbyView(let day):
                    StandbyView(day: day, navigationPath: $navigationPath)
                case .timerView(let day, _):
                    WorkoutTimerView(day: day, navigationPath: $navigationPath)
                case .completionView(let day, let elapsedSeconds, let isFullCompletion, let completedExerciseIndices, let setLogs):
                    PlanCompletionView(
                        day: day,
                        elapsedSeconds: elapsedSeconds,
                        isFullCompletion: isFullCompletion,
                        completedExerciseIndices: completedExerciseIndices,
                        setLogs: setLogs,
                        navigationPath: $navigationPath
                    )
                case .recordView:
                    WorkoutRecordView(navigationPath: $navigationPath)
                }
            }
        }
        .onAppear {
            activityDataManager.requestAuthorization()
            activityDataManager.fetchActivityData()
        }
    }
}

// ナビゲーション用の列挙型
enum WorkoutNavigationDestination: Hashable {
    case aiPlanView
    case recordView
    case standbyView(day: DaySchedule)
    case timerView(day: DaySchedule, elapsedSeconds: Int)
    case completionView(day: DaySchedule, elapsedSeconds: Int, isFullCompletion: Bool, completedExerciseIndices: [Int], setLogs: [SetLog])
}

#Preview("ExerciseDatabaseView") {
    ExerciseDatabaseView()
        .modelContainer(for: [WorkoutSessionEntity.self, WorkoutProgress.self], inMemory: true)
}
