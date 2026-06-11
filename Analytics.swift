import Foundation
import CloudKit

class Analytics {
    static let shared = Analytics()

    // We lazily initialize the database connection so it doesn't block app launch
    private lazy var database: CKDatabase = {
        return CKContainer.default().publicCloudDatabase
    }()

    private init() {}

    /// Logs a simple string event to the CloudKit Public Database asynchronously.
    func logEvent(_ name: String) {
        // Run on background thread to ensure no UI blocking
        Task.detached(priority: .background) {
            let record = CKRecord(recordType: "TelemetryEvent")
            record["eventName"] = name
            record["timestamp"] = Date()

            do {
                try await self.database.save(record)
                // Successfully logged to CloudKit
            } catch {
                // Silently fail. Analytics should never crash the app or alert the user.
                print("Analytics failed to log '\(name)': \(error.localizedDescription)")
            }
        }
    }

    /// Logs an error event with context to CloudKit for funnel diagnostics.
    func logError(_ error: Error, context: String) {
        Task.detached(priority: .background) {
            let record = CKRecord(recordType: "TelemetryEvent")
            record["eventName"] = "Error"
            record["errorContext"] = context
            record["errorDescription"] = error.localizedDescription
            record["timestamp"] = Date()

            do {
                try await self.database.save(record)
            } catch {
                print("Analytics failed to log error [\(context)]: \(error.localizedDescription)")
            }
        }
    }

    /// Logs a latency measurement (in milliseconds) for a named operation.
    func logLatency(_ operation: String, durationMs: Int) {
        Task.detached(priority: .background) {
            let record = CKRecord(recordType: "TelemetryEvent")
            record["eventName"] = "Latency"
            record["operation"] = operation
            record["durationMs"] = durationMs
            record["timestamp"] = Date()

            do {
                try await self.database.save(record)
            } catch {
                print("Analytics failed to log latency [\(operation)]: \(error.localizedDescription)")
            }
        }
    }

    /// Measures the wall-clock duration of an async operation, logs it, and returns the result.
    func measure<T>(_ operation: String, block: () async throws -> T) async throws -> T {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let result = try await block()
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            logLatency(operation, durationMs: elapsed)
            return result
        } catch {
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            logLatency(operation, durationMs: elapsed)
            logError(error, context: operation)
            throw error
        }
    }
}
