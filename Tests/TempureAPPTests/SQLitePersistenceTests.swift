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

    @Test("Saved tags should survive repository restart")
    func tagsPersistAcrossLaunches() throws {
        let filename = "tempure-tag-test-\(UUID().uuidString).sqlite3"
        let dbURL = try SQLiteDatabase.databaseURL(filename: filename)
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dateService = DateService()
        let date = dateService.dayStart(for: Date(timeIntervalSince1970: 1_711_111_111))

        do {
            let db = try SQLiteDatabase(filename: filename)
            let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)
            try repository.saveTag(
                on: date,
                hasIntercourse: true,
                intercourseTime: .evening,
                hasMenstruation: true,
                menstrualFlow: .heavy,
                menstrualColor: .darkRed,
                hasDysmenorrhea: true
            )
        }

        do {
            let db = try SQLiteDatabase(filename: filename)
            let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)
            let tag = try repository.fetchTag(on: date)
            #expect(tag != nil)
            #expect(tag?.hasIntercourse == true)
            #expect(tag?.intercourseTime == .evening)
            #expect(tag?.hasMenstruation == true)
            #expect(tag?.menstrualFlow == .heavy)
            #expect(tag?.menstrualColor == .darkRed)
            #expect(tag?.hasDysmenorrhea == true)
        }
    }

    @Test("Saved weights should survive repository restart")
    func weightsPersistAcrossLaunches() throws {
        let filename = "tempure-weight-test-\(UUID().uuidString).sqlite3"
        let dbURL = try SQLiteDatabase.databaseURL(filename: filename)
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dateService = DateService()
        let date = dateService.dayStart(for: Date(timeIntervalSince1970: 1_713_333_333))

        do {
            let db = try SQLiteDatabase(filename: filename)
            let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)
            try repository.saveWeight(on: date, weightKg: 58.2)
        }

        do {
            let db = try SQLiteDatabase(filename: filename)
            let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)
            let record = try repository.fetchWeight(on: date)
            #expect(record != nil)
            #expect(record?.weightKg == 58.2)
        }
    }

    @Test("Saving empty tag payload should clear existing tag")
    func clearTagWhenNothingSelected() throws {
        let filename = "tempure-tag-clear-\(UUID().uuidString).sqlite3"
        let dbURL = try SQLiteDatabase.databaseURL(filename: filename)
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dateService = DateService()
        let date = dateService.dayStart(for: Date(timeIntervalSince1970: 1_712_222_222))

        let db = try SQLiteDatabase(filename: filename)
        let repository = SQLiteBBTRepository(db: db, dateService: dateService, defaults: .standard)

        try repository.saveTag(
            on: date,
            hasIntercourse: true,
            intercourseTime: .night,
            hasMenstruation: false,
            menstrualFlow: nil,
            menstrualColor: nil,
            hasDysmenorrhea: false
        )
        #expect(try repository.fetchTag(on: date) != nil)

        try repository.saveTag(
            on: date,
            hasIntercourse: false,
            intercourseTime: nil,
            hasMenstruation: false,
            menstrualFlow: nil,
            menstrualColor: nil,
            hasDysmenorrhea: false
        )
        #expect(try repository.fetchTag(on: date) == nil)
    }
}
