import Foundation
import SQLite3

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
        sqlite3_bind_text(statement, 1, NSString(string: dayKey).utf8String, -1, nil)
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
        sqlite3_bind_text(statement, 1, NSString(string: dayKey).utf8String, -1, nil)

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

        sqlite3_bind_text(statement, 1, NSString(string: startKey).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, NSString(string: endKey).utf8String, -1, nil)

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
        let updatedAt = sqlite3_column_int64(statement, 2)
        return BBTRecord(date: date, temperatureCelsius: temperature, updatedAt: updatedAt)
    }
}
