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

    public func saveWeight(on date: Date, weightKg: Double) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        INSERT INTO weight_records(date, weight_kg, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
        weight_kg = excluded.weight_kg,
        updated_at = excluded.updated_at;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        let dayKey = dateService.storageKey(for: date)
        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)
        sqlite3_bind_double(statement, 2, weightKg)
        sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))

        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteError.stepFailed("Could not upsert weight")
        }
    }

    public func fetchWeight(on date: Date) throws -> WeightRecord? {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, weight_kg, updated_at
        FROM weight_records
        WHERE date = ?
        LIMIT 1;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        let dayKey = dateService.storageKey(for: date)
        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            return decodeWeight(from: statement)
        }
        return nil
    }

    public func fetchAllWeights() throws -> [WeightRecord] {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, weight_kg, updated_at
        FROM weight_records
        ORDER BY date ASC;
        """

        let statement = try db.prepare(sql: sql)
        defer { db.finalize(statement) }

        var records: [WeightRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeWeight(from: statement) {
                records.append(record)
            }
        }
        return records
    }

    public func saveTag(
        on date: Date,
        hasIntercourse: Bool,
        intercourseTime: IntercourseTime?,
        hasMenstruation: Bool,
        menstrualFlow: MenstrualFlow?,
        menstrualColor: MenstrualColor?,
        hasDysmenorrhea: Bool
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let dayKey = dateService.storageKey(for: date)
        let normalizedIntercourseTime = hasIntercourse ? intercourseTime : nil
        let normalizedFlow = hasMenstruation ? menstrualFlow : nil
        let normalizedColor = hasMenstruation ? menstrualColor : nil
        let normalizedDysmenorrhea = hasMenstruation ? hasDysmenorrhea : false

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
        INSERT INTO daily_tags(
            date,
            has_intercourse,
            intercourse_time,
            has_menstruation,
            menstrual_flow,
            menstrual_color,
            has_dysmenorrhea,
            updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
        has_intercourse = excluded.has_intercourse,
        intercourse_time = excluded.intercourse_time,
        has_menstruation = excluded.has_menstruation,
        menstrual_flow = excluded.menstrual_flow,
        menstrual_color = excluded.menstrual_color,
        has_dysmenorrhea = excluded.has_dysmenorrhea,
        updated_at = excluded.updated_at;
        """

        let statement = try db.prepare(sql: upsertSQL)
        defer { db.finalize(statement) }

        sqlite3_bind_text(statement, 1, (dayKey as NSString).utf8String, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, hasIntercourse ? 1 : 0)
        if let normalizedIntercourseTime {
            sqlite3_bind_text(statement, 3, (normalizedIntercourseTime.rawValue as NSString).utf8String, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 3)
        }

        sqlite3_bind_int(statement, 4, hasMenstruation ? 1 : 0)

        if let normalizedFlow {
            sqlite3_bind_text(statement, 5, (normalizedFlow.rawValue as NSString).utf8String, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let normalizedColor {
            sqlite3_bind_text(statement, 6, (normalizedColor.rawValue as NSString).utf8String, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        sqlite3_bind_int(statement, 7, normalizedDysmenorrhea ? 1 : 0)
        sqlite3_bind_int64(statement, 8, Int64(Date().timeIntervalSince1970))

        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteError.stepFailed("Could not upsert daily tag")
        }
    }

    public func fetchTag(on date: Date) throws -> DailyTag? {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
        SELECT date, has_intercourse, intercourse_time, has_menstruation, menstrual_flow, menstrual_color, has_dysmenorrhea, updated_at
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
        SELECT date, has_intercourse, intercourse_time, has_menstruation, menstrual_flow, menstrual_color, has_dysmenorrhea, updated_at
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
        SELECT date, has_intercourse, intercourse_time, has_menstruation, menstrual_flow, menstrual_color, has_dysmenorrhea, updated_at
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
        var intercourseTime: IntercourseTime?
        if let intercourseTimeCString = sqlite3_column_text(statement, 2) {
            intercourseTime = IntercourseTime(rawValue: String(cString: intercourseTimeCString))
        }
        if !hasIntercourse {
            intercourseTime = nil
        }

        let hasMenstruation = sqlite3_column_int(statement, 3) == 1

        var flow: MenstrualFlow?
        if let flowCString = sqlite3_column_text(statement, 4) {
            flow = MenstrualFlow(rawValue: String(cString: flowCString))
        }
        if !hasMenstruation {
            flow = nil
        }

        var color: MenstrualColor?
        if let colorCString = sqlite3_column_text(statement, 5) {
            color = MenstrualColor(rawValue: String(cString: colorCString))
        }
        if !hasMenstruation {
            color = nil
        }

        let hasDysmenorrhea = hasMenstruation ? (sqlite3_column_int(statement, 6) == 1) : false
        let updatedAt = sqlite3_column_int64(statement, 7)
        return DailyTag(
            date: date,
            hasIntercourse: hasIntercourse,
            intercourseTime: intercourseTime,
            hasMenstruation: hasMenstruation,
            menstrualFlow: flow,
            menstrualColor: color,
            hasDysmenorrhea: hasDysmenorrhea,
            updatedAt: updatedAt
        )
    }

    private func decodeWeight(from statement: OpaquePointer?) -> WeightRecord? {
        guard
            let dateCString = sqlite3_column_text(statement, 0),
            let date = dateService.date(from: String(cString: dateCString))
        else {
            return nil
        }

        let weight = sqlite3_column_double(statement, 1)
        guard weight.isFinite else {
            return nil
        }
        let updatedAt = sqlite3_column_int64(statement, 2)
        return WeightRecord(date: date, weightKg: weight, updatedAt: updatedAt)
    }
}
