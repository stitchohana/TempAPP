import Foundation

public struct WorkerRecordSyncService: Sendable {
    private struct RecordPayload: Encodable {
        let recordDate: String
        let temperatureC: Double?
        let weightKg: Double?
        let tags: TagsPayload?
        let updatedAt: Int64

        struct TagsPayload: Encodable {
            let hasIntercourse: Bool
            let intercourseTime: String?
            let hasMenstruation: Bool
            let menstrualFlow: String?
            let menstrualColor: String?
            let hasDysmenorrhea: Bool
        }
    }

    private struct BatchUpsertRequest: Encodable {
        let records: [RecordPayload]
    }

    private let client: CloudflareWorkerClient

    public init(client: CloudflareWorkerClient) {
        self.client = client
    }

    public func batchUpsert(
        temperatureRecords: [BBTRecord],
        weightRecords: [WeightRecord],
        tags: [DailyTag],
        accessToken: String
    ) async throws {
        let tempMap = Dictionary(uniqueKeysWithValues: temperatureRecords.map { ($0.id, $0) })
        let weightMap = Dictionary(uniqueKeysWithValues: weightRecords.map { ($0.id, $0) })
        let tagMap = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        let allDates = Set(tempMap.keys).union(weightMap.keys).union(tagMap.keys).sorted()

        let payload = allDates.map { dateKey in
            let tagPayload: RecordPayload.TagsPayload? = tagMap[dateKey].map {
                RecordPayload.TagsPayload(
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

        try await client.post(path: "/records/batch-upsert", body: BatchUpsertRequest(records: payload), bearerToken: accessToken)
    }

}
