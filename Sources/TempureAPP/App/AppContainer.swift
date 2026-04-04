import Foundation

public struct AppContainer: Sendable {
    public let repository: BBTRepository
    public let authRepository: AuthRepository
    public let recordSyncService: WorkerRecordSyncService?
    public let dateService: DateService
    public let haptics: HapticsService

    public init(
        repository: BBTRepository,
        authRepository: AuthRepository,
        recordSyncService: WorkerRecordSyncService? = nil,
        dateService: DateService = .shared,
        haptics: HapticsService = SystemHapticsService()
    ) {
        self.repository = repository
        self.authRepository = authRepository
        self.recordSyncService = recordSyncService
        self.dateService = dateService
        self.haptics = haptics
    }

    public static func bootstrap() throws -> AppContainer {
        let db = try SQLiteDatabase()
        let repository = SQLiteBBTRepository(db: db)

        if let url = AppConfig.workerBaseURL {
            let client = CloudflareWorkerClient(baseURL: url)
            return AppContainer(
                repository: repository,
                authRepository: WorkerAuthRepository(client: client),
                recordSyncService: WorkerRecordSyncService(client: client)
            )
        }

        return AppContainer(repository: repository, authRepository: PreviewAuthRepository())
    }
}
