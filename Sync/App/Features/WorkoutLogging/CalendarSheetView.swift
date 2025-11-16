import SwiftUI
import SwiftData

struct CalendarSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var progressRecords: [WorkoutProgress]
    @Binding var selectedDate: Date
    @State private var currentDate = Date()
    
    private let calendar = Calendar.current
    private let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Month header with navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 31/255, green: 35/255, blue: 64/255))
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 31/255, green: 35/255, blue: 64/255))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 14) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasWorkout: hasWorkout(on: date),
                            onTap: {
                                selectedDate = date
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 56)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            Spacer(minLength: 30)
        }
        .padding(.vertical, 0)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: currentDate)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        // Adjust for Monday start (1 = Monday in our calendar)
        let adjustedFirstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
        let paddingDays = adjustedFirstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: paddingDays)
        
        let range = calendar.range(of: .day, in: .month, for: currentDate)!
        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: monthInterval.start) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - Helper Methods
    
    private func hasWorkout(on date: Date) -> Bool {
        return progressRecords.contains { progress in
            guard let completedDate = progress.completedAt else { return false }
            return calendar.isDate(completedDate, inSameDayAs: date) && progress.isCompleted
        }
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentDate = newDate
            }
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentDate = newDate
            }
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let hasWorkout: Bool
    let onTap: () -> Void
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"   // 先頭ゼロなし
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 18, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                isToday
                                ? Color(red: 30/255, green: 32/255, blue: 48/255)
                                : (isSelected ? Color(.systemGray6) : Color.clear)
                            )
                    )
                
                if hasWorkout {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.6, blue: 0.4))
                        .frame(width: 5, height: 5)
                } else {
                    Color.clear
                        .frame(width: 5, height: 5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()
        
        var body: some View {
            CalendarSheetView(selectedDate: $selectedDate)
                .presentationDetents([.medium])
        }
    }
    
    return PreviewWrapper()
        .modelContainer(for: [WorkoutProgress.self], inMemory: true)
}
