import SwiftUI

struct SplashView: View {
    @State private var isActive: Bool = false
    @State private var size: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    
    // 初期化が必要なリポジトリや依存関係をここに追加
    // 例: @StateObject private var appState = AppState()
    
    var body: some View {
        ZStack {
            if isActive {
                StartView()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.heart")
                        .font(.system(size: 56, weight: .semibold))
                    Text("Sync")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    // 拡大＋フェードインアニメーション
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 0.9
                        self.opacity = 1.0
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        .task {
            // 非同期で初期化処理を実行
            await performInitialization()
            
            // アニメーションが完了するまで最低限の時間を確保
            let minimumDisplayTime: TimeInterval = 1.5
            try? await Task.sleep(nanoseconds: UInt64(minimumDisplayTime * 1_000_000_000))
            
            // メイン画面へ切替
            withAnimation {
                self.isActive = true
            }
        }
    }
    
    /// アプリの初期化処理をここに実装
    private func performInitialization() async {
        // 並列で複数の初期化タスクを実行
        await withTaskGroup(of: Void.self) { group in
            // 例1: プロファイルデータの読み込み
            group.addTask {
                await loadUserProfile()
            }
            
            // 例2: キャッシュの初期化
            group.addTask {
                await initializeCache()
            }
            
            // 例3: リモート設定の取得
            group.addTask {
                await fetchRemoteConfig()
            }
            
            // すべてのタスクが完了するまで待機
            await group.waitForAll()
        }
    }
    
    // MARK: - 初期化タスクの例
    
    private func loadUserProfile() async {
        // プロファイルリポジトリからデータを読み込む
        // 例: let profile = try? await profileRepository.getProfile()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒のシミュレーション
    }
    
    private func initializeCache() async {
        // キャッシュの初期化処理
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒のシミュレーション
    }
    
    private func fetchRemoteConfig() async {
        // リモート設定の取得
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4秒のシミュレーション
    }
}

#Preview { SplashView() }
