import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLiteBBTRepository: BBTRepository, @unchecked Sendable {
    private let db: SQLiteDatabase
    private let dateService: DateService
    private let defaults: UserDefaults
    private let lock = NSLock()

    private let preferredUnitKey = "preferred_temperature_unit"

    public init(
        db: SQLiteDatabase,
        dateService: DateService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.db = db
        self.dateService = dateService
        self.defaults = defaults
    }

    public func saveTemperature(on date: Date, temperatureCelsius: Double) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        INSERT INTO bbt_records(date, temperature, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
        temperature = excluded.temperature,
        updated_at = excluded.updated_at;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        let dayKey = dateService.storageKey(for: date)
        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)
        sqlite3_bind_double(statement, 2, temperatureCelsius)
        sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))

        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteError.stepFailed("Could not upsert temperature")
        }
    }

    public func fetchTemperature(on date: Date) throws -> BBTRecord? {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, temperature, updated_at
        FROM bbt_records
        WHERE date = ?
        LIMIT 1;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        let dayKey = dateService.storageKey(for: date)
        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            return decodeRecord(from: statement)
        }
        return nil
    }

    public func fetchMonthlyRecords(containing date: Date) throws -> [BBTRecord] {
        lock.lock()
        defer { lock.unlock() }

        let range = dateService.monthRange(containing: date)
        let startKey = dateService.storageKey(for: range.start)
        let endKey = dateService.storageKey(for: range.end)

        let sql = """
        SELECT date, temperature, updated_at
        FROM bbt_records
        WHERE date >= ? AND date < ?
        ORDER BY date ASC;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        sqlite3_bind_text(statement, 1, (startKey as NSString).utf8String, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, (endKey as NSString).utf8String, -1, sqliteTransient)

        var records: [BBTRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeRecord(from: statement) {
                records.append(record)
            }
        }
        return records
    }

    public func fetchAllRecords() throws -> [BBTRecord] {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, temperature, updated_at
        FROM bbt_records
        ORDER BY date ASC;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        var records: [BBTRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeRecord(from: statement) {
                records.append(record)
            }
        }
        return records
    }

    public func saveTag(
        on date: Date,
        hasIntercourse: Bool,
        hasMenstruation: Bool,
        menstrualFlow: MenstrualFlow?
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let dayKey = dateService.storageKey(for: date)
        let normalizedFlow = hasMenstruation ? menstrualFlow : nil

        if !hasIntercourse, !hasMenstruation {
            let deleteSQL = "DELETE FROM daily_tags WHERE date = ?;"
            let deleteStatement = try db.prepare(sql: deleteSQL)
            defer { db.finalize(deleteStatement) }
            sqlite3_bind_text(deleteStatement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)
            if sqlite3_step(deleteStatement) != SQLITE_DONE {
                throw SQLiteError.stepFailed("Could not delete daily tag")
            }
            return
        }

        let upsertSQL = """
        INSERT INTO daily_tags(date, has_intercourse, has_menstruation, menstrual_flow, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
        has_intercourse = excluded.has_intercourse,
        has_menstruation = excluded.has_menstruation,
        menstrual_flow = excluded.menstrual_flow,
        updated_at = excluded.updated_at;
        """

        let statement = try db.prepare(sql: upsertSQL)
        defer { db.finalize(statement) }

        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, hasIntercourse ? 1 : 0)
        sqlite3_bind_int(statement, 3, hasMenstruation ? 1 : 0)

        if let normalizedFlow {
            sqlite3_bind_text(statement, 4, (normalizedFlow.rawValue as NSString).utf8String, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 4)
        }

        sqlite3_bind_int64(statement, 5, Int64(Date().timeIntervalSince1970))

        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteError.stepFailed("Could not upsert daily tag")
        }
    }

    public func fetchTag(on date: Date) throws -> DailyTag? {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, has_intercourse, has_menstruation, menstrual_flow, updated_at
        FROM daily_tags
        WHERE date = ?
        LIMIT 1;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        let dayKey = dateService.storageKey(for: date)
        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            return decodeTag(from: statement)
        }
        return nil
    }

    public func fetchMonthlyTags(containing date: Date) throws -> [DailyTag] {
        lock.lock()
        defer { lock.unlock() }

        let range = dateService.monthRange(containing: date)
        let startKey = dateService.storageKey(for: range.start)
        let endKey = dateService.storageKey(for: range.end)

        let sql = """
        SELECT date, has_intercourse, has_menstruation, menstrual_flow, updated_at
        FROM daily_tags
        WHERE date >= ? AND date < ?
        ORDER BY date ASC;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        sqlite3_bind_text(statement, 1, (startKey as NSString).utf8String, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, (endKey as NSString).utf8String, -1, sqliteTransient)

        var tags: [DailyTag] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let tag = decodeTag(from: statement) {
                tags.append(tag)
            }
        }
        return tags
    }

    public func fetchAllTags() throws -> [DailyTag] {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, has_intercourse, has_menstruation, menstrual_flow, updated_at
        FROM daily_tags
        ORDER BY date ASC;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        var tags: [DailyTag] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let tag = decodeTag(from: statement) {
                tags.append(tag)
            }
        }
        return tags
    }

    public func updatePreferredUnit(_ unit: TemperatureUnit) {
        defaults.set(unit.rawValue, forKey: preferredUnitKey)
    }

    public func preferredUnit() -> TemperatureUnit {
        guard
            let raw = defaults.string(forKey: preferredUnitKey),
            let unit = TemperatureUnit(rawValue: raw)
        else {
            return .celsius
        }
        return unit
    }

    private func decodeRecord(from statement: OpaquePointer?) -> BBTRecord? {
        guard
            let dateCString = sqlite3_column_text(statement, 0),
            let date = dateService.date(from: String(cString: dateCString))
        else {
            return nil
        }

        let temperature = sqlite3_column_double(statement, 1)
        guard temperature.isFinite else {
            return nil
        }
        let updatedAt = sqlite3_column_int64(statement, 2)
        return BBTRecord(date: date, temperatureCelsius: temperature, updatedAt: updatedAt)
    }

    private func decodeTag(from statement: OpaquePointer?) -> DailyTag? {
        guard
            let dateCString = sqlite3_column_text(statement, 0),
            let date = dateService.date(from: String(cString: dateCString))
        else {
            return nil
        }

        let hasIntercourse = sqlite3_column_int(statement, 1) == 1
        let hasMenstruation = sqlite3_column_int(statement, 2) == 1

        var flow: MenstrualFlow?
        if let flowCString = sqlite3_column_text(statement, 3) {
            flow = MenstrualFlow(rawValue: String(cString: flowCString))
        }
        if !hasMenstruation {
            flow = nil
        }

        let updatedAt = sqlite3_column_int64(statement, 4)
        return DailyTag(
            date: date,
            hasIntercourse: hasIntercourse,
            hasMenstruation: hasMenstruation,
            menstrualFlow: flow,
            updatedAt: updatedAt
        )
    }
}
