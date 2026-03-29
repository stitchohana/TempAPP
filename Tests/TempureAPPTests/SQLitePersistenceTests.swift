import Foundation
import Testing
@testable import TempureAPP

@Suite("SQLite Persistence")
struct SQLitePersistenceTests {
    @Test("Saved records should survive repository restart")
    func recordsPersistAcrossLaunches() throws {
        let filename = "tempure-test-\(UUID().uuidString).sqlite3"
        let dbURL = try SQLiteDatabase.databaseURL(filename: filename)
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dateService = DateService()
        let date = dateService.dayStart(for: Date(timeIntervalSince1970: 1_710_000_000))

        do {
            let db = try SQLiteDatabase(filename: filename)
            let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)
            try repository.saveTemperature(on: date, temperatureCelsius: 36.6)
        }

        do {
            let db = try SQLiteDatabase(filename: filename)
            let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)
            let record = try repository.fetchTemperature(on: date)
            #expect(record != nil)
            #expect(record?.temperatureCelsius == 36.6)
        }
    }
}
