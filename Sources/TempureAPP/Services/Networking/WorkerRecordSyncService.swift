import Foundation

public struct WorkerRecordSyncService: Sendable {
    public struct TagsPayload: Codable, Sendable {
        public let hasIntercourse: Bool
        public let intercourseTime: String?
        public let hasMenstruation: Bool
        public let menstrualFlow: String?
        public let menstrualColor: String?
        public let hasDysmenorrhea: Bool

        public init(
            hasIntercourse: Bool,
            intercourseTime: String?,
            hasMenstruation: Bool,
            menstrualFlow: String?,
            menstrualColor: String?,
            hasDysmenorrhea: Bool
        ) {
            self.hasIntercourse = hasIntercourse
            self.intercourseTime = intercourseTime
            self.hasMenstruation = hasMenstruation
            self.menstrualFlow = menstrualFlow
            self.menstrualColor = menstrualColor
            self.hasDysmenorrhea = hasDysmenorrhea
        }
    }

    public struct SyncedRecord: Codable, Sendable {
        public let recordDate: String
        public let temperatureC: Double?
        public let weightKg: Double?
        public let tags: TagsPayload?
        public let updatedAt: Int64

        public init(
            recordDate: String,
            temperatureC: Double?,
            weightKg: Double?,
            tags: TagsPayload?,
            updatedAt: Int64
        ) {
            self.recordDate = recordDate
            self.temperatureC = temperatureC
            self.weightKg = weightKg
            self.tags = tags
            self.updatedAt = updatedAt
        }
    }

    private struct RecordPayload: Encodable {
        let recordDate: String
        let temperatureC: Double?
        let weightKg: Double?
        let tags: WorkerRecordSyncService.TagsPayload?
        let updatedAt: Int64
    }

    private struct BatchUpsertRequest: Encodable {
        let records: [RecordPayload]
    }

    private struct PullAllResponse: Decodable {
        let records: [SyncedRecord]
    }

    private let client: CloudflareWorkerClient
    private let dateService: DateService

    public init(client: CloudflareWorkerClient, dateService: DateService = .shared) {
        self.client = client
        self.dateService = dateService
    }

    public func batchUpsert(
        temperatureRecords: [BBTRecord],
        weightRecords: [WeightRecord],
        tags: [DailyTag],
        accessToken: String
    ) async throws {
        let tempMap = Dictionary(uniqueKeysWithValues: temperatureRecords.map { (dateService.storageKey(for: $0.date), $0) })
        let weightMap = Dictionary(uniqueKeysWithValues: weightRecords.map { (dateService.storageKey(for: $0.date), $0) })
        let tagMap = Dictionary(uniqueKeysWithValues: tags.map { (dateService.storageKey(for: $0.date), $0) })
        let allDates = Set(tempMap.keys).union(weightMap.keys).union(tagMap.keys).sorted()

        let payload = allDates.map { dateKey in
            let tagPayload: WorkerRecordSyncService.TagsPayload? = tagMap[dateKey].map {
                WorkerRecordSyncService.TagsPayload(
                    hasIntercourse: $0.hasIntercourse,
                    intercourseTime: $0.intercourseTime?.rawValue,
                    hasMenstruation: $0.hasMenstruation,
                    menstrualFlow: $0.menstrualFlow?.rawValue,
                    menstrualColor: $0.menstrualColor?.rawValue,
                    hasDysmenorrhea: $0.hasDysmenorrhea
                )
            }

            return RecordPayload(
                recordDate: dateKey,
                temperatureC: tempMap[dateKey]?.temperatureCelsius,
                weightKg: weightMap[dateKey]?.weightKg,
                tags: tagPayload,
                updatedAt: max(max(tempMap[dateKey]?.updatedAt ?? 0, weightMap[dateKey]?.updatedAt ?? 0), tagMap[dateKey]?.updatedAt ?? 0)
            )
        }

        guard payload.isEmpty == false else { return }
        try await client.post(path: "/records/batch-upsert", body: BatchUpsertRequest(records: payload), bearerToken: accessToken)
    }

    public func fetchAll(accessToken: String) async throws -> [SyncedRecord] {
        let response: PullAllResponse = try await client.get(path: "/records/all", bearerToken: accessToken)
        return response.records
    }
}
