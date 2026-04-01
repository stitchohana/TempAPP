import Foundation

public struct AppContainer: Sendable {
    public let repository: BBTRepository
    public let authRepository: AuthRepository
    public let dateService: DateService
    public let haptics: HapticsService

    public init(
        repository: BBTRepository,
        authRepository: AuthRepository,
        dateService: DateService = .shared,
        haptics: HapticsService = SystemHapticsService()
    ) {
        self.repository = repository
        self.authRepository = authRepository
        self.dateService = dateService
        self.haptics = haptics
    }

    public static func bootstrap() throws -> AppContainer {
        let db = try SQLiteDatabase()
        let repository = SQLiteBBTRepository(db: db)

        if let endpoint = ProcessInfo.processInfo.environment["WORKER_BASE_URL"],
           let url = URL(string: endpoint)
        {
            let client = CloudflareWorkerClient(baseURL: url)
            return AppContainer(repository: repository, authRepository: WorkerAuthRepository(client: client))
        }

        return AppContainer(repository: repository, authRepository: PreviewAuthRepository())
    }
}
