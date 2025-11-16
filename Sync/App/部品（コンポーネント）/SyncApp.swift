import SwiftUI
import SwiftData

@main
struct SyncApp: App {
    var body: some Scene {
        WindowGroup {
            StartView() // あなたのルートView
        }
        .modelContainer(for: [
            UserProfileEntity.self,
            WeightLogEntity.self,
            OutboxItemEntity.self,
            AuditLogEntity.self
        ])
    }
}

#Preview {
    StartView()
        .modelContainer(for: [
            UserProfileEntity.self,
            WeightLogEntity.self,
            OutboxItemEntity.self,
            AuditLogEntity.self
        ], inMemory: true)
}
