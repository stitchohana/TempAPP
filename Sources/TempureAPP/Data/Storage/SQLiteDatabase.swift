import Foundation
import SQLite3

enum SQLiteError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
}

public final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let dbPath: String

    public init(filename: String = "tempure.sqlite3") throws {
        let dbURL = try Self.databaseURL(filename: filename)
        dbPath = dbURL.path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown open error"
            throw SQLiteError.openFailed(message)
        }

        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    static func databaseURL(filename: String) throws -> URL {
        let baseURL = try databaseDirectoryURL()
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        return baseURL.appendingPathComponent(filename)
    }

    private static func databaseDirectoryURL() throws -> URL {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("TempureAPP", isDirectory: true)
        }
        throw SQLiteError.openFailed("Could not resolve application support directory")
    }

    private func migrate() throws {
        try execute(sql: Migration.createBBTRecordsTable)
        try execute(sql: Migration.createUpdatedAtIndex)
        try execute(sql: Migration.createDailyTagsTable)
        try executeAllowingDuplicateColumn(sql: Migration.addIntercourseTimeColumn)
        try executeAllowingDuplicateColumn(sql: Migration.addMenstrualColorColumn)
        try executeAllowingDuplicateColumn(sql: Migration.addHasDysmenorrheaColumn)
        try execute(sql: Migration.createDailyTagsUpdatedAtIndex)
    }

    func execute(sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown execution error"
            throw SQLiteError.stepFailed(message)
        }
    }

    func prepare(sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown prepare error"
            throw SQLiteError.prepareFailed(message)
        }
        guard let statement else {
            throw SQLiteError.prepareFailed("Could not build SQLite statement")
        }
        return statement
    }

    func finalize(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    private func executeAllowingDuplicateColumn(sql: String) throws {
        do {
            try execute(sql: sql)
        } catch SQLiteError.stepFailed(let message) where message.localizedCaseInsensitiveContains("duplicate column name") {
            return
        } catch {
            throw error
        }
    }
}
