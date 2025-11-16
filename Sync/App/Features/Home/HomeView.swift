import SwiftUI

public struct HomeView: View {
    // Inject managers here so WeeklyBurnCard can receive the calendarManager argument
    @StateObject private var dataManager: ActivityDataManager
    @StateObject private var calendarManager: CalendarLogicManager

    public init() {
        let dm = ActivityDataManager()
        _dataManager = StateObject(wrappedValue: dm)
        _calendarManager = StateObject(wrappedValue: CalendarLogicManager(dataManager: dm))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
            }
            WeeklyBurnCard(calendarManager: calendarManager)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HomeView() }
}
