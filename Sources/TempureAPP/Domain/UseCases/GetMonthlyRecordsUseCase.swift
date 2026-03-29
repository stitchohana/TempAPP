import Foundation

public struct GetMonthlyRecordsUseCase: Sendable {
    private let repository: BBTRepository

    public init(repository: BBTRepository) {
        self.repository = repository
    }

    public func execute(containing date: Date) throws -> [BBTRecord] {
        try repository.fetchMonthlyRecords(containing: date)
    }
}
