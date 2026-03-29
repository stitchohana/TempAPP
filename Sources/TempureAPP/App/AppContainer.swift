import Foundation

public struct AppContainer: Sendable {
    public let repository: BBTRepository
    public let dateService: DateService
    public let haptics: HapticsService

    public init(
        repository: BBTRepository,
        dateService: DateService = .shared,
        haptics: HapticsService = SystemHapticsService()
    ) {
        self.repository = repository
        self.dateService = dateService
        self.haptics = haptics
    }

    public static func bootstrap() throws -> AppContainer {
        let db = try SQLiteDatabase()
        let repository = SQLiteBBTRepository(db: db)
        return AppContainer(repository: repository)
    }
}
