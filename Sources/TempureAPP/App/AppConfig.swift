import Foundation

public enum AppConfig {
    private static let defaultWorkerBaseURLString = "https://234575.xyz"

    public static var workerBaseURL: URL? {
        if let envValue = ProcessInfo.processInfo.environment["WORKER_BASE_URL"],
           let envURL = URL(string: envValue)
        {
            return envURL
        }

        return URL(string: defaultWorkerBaseURLString)
    }
}
