import Foundation
import UIKit
import UserNotifications

@MainActor
/// Coordinates mobile analytics ingestion and APNs token sync for Qeid+.
final class MobileBackendManager {

    static let shared = MobileBackendManager()

    private let defaults: UserDefaults
    private let backendClient: MobileBackendClient
    private let appInstanceID: String
    private let queue: OfflineQueue

    private var activeSessionID: String?
    private var activeSessionStartedAt: Date?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appInstanceID = Self.loadOrCreateInstanceID(defaults: defaults)
        self.backendClient = MobileBackendClient()
        self.queue = OfflineQueue(filename: "qeidplus_offline_queue.json")
    }

    // MARK: - Bootstrap Config

    private(set) var forceUpdateRequired: Bool = false
    private(set) var forceUpdateMode: String = "off"   // "off" | "soft" | "hard"
    private(set) var forceUpdateMessage: String? = nil
    private(set) var appStoreURL: URL? = nil
    private var lastBootstrapRefreshAt: Date?
    private let bootstrapRefreshInterval: TimeInterval = 300

    // MARK: - Public API

    /// Registers/refreshes instance data and syncs stored device token on launch.
    func performLaunchSync() async {
        await drainQueue()
        await refreshBootstrapConfig(force: true)
        await registerInstance()
        await beginSession()
        await syncStoredDeviceToken(optedIn: await currentOptIn())
    }

    /// Fetches bootstrap config (force update policy + runtime settings).
    func refreshBootstrapConfig(force: Bool = false) async {
        if !force,
           let last = lastBootstrapRefreshAt,
           Date().timeIntervalSince(last) < bootstrapRefreshInterval { return }
        lastBootstrapRefreshAt = Date()
        do {
            let response = try await backendClient.bootstrapConfig(appVersion: Self.marketingVersion)
            forceUpdateMode = response.data.forceUpdate.mode
            forceUpdateRequired = response.data.forceUpdate.required
            forceUpdateMessage = response.data.forceUpdate.message
            if let raw = response.data.forceUpdate.appStoreUrl,
               let url = URL(string: raw) {
                appStoreURL = url
            }
            debugLog("bootstrap-config fetched (mode=\(forceUpdateMode), required=\(forceUpdateRequired))")
        } catch {
            debugLog("bootstrap-config fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Support Tickets

    /// Submits a support, suggestion, or feature request ticket.
    func submitSupportTicket(type: String, message: String) async throws {
        _ = try await backendClient.submitSupportTicket(instanceID: appInstanceID, type: type, message: message)
        debugLog("support-ticket submitted (type=\(type))")
    }

    /// Fetches tickets submitted from this device.
    func fetchMyTickets() async throws -> [SupportTicket] {
        let tickets = try await backendClient.listSupportTickets(instanceID: appInstanceID)
        debugLog("support-tickets fetched (count=\(tickets.count))")
        return tickets
    }

    /// Ends the active session (call when app enters background).
    func endSession() async {
        guard let sessionID = activeSessionID else { return }
        let endedAt = Date()
        let payload: [String: Any] = [
            "instance_id": appInstanceID,
            "session_id": sessionID,
            "ended_at": Self.iso8601DateString(endedAt),
            "metadata": [:],
        ]
        do {
            try await backendClient.sessionEnd(
                instanceID: appInstanceID,
                sessionID: sessionID,
                endedAt: endedAt
            )
        } catch {
            queue.enqueue(path: "session/end", body: payload)
            debugLog("session/end queued for retry")
        }
        activeSessionID = nil
        activeSessionStartedAt = nil
    }

    /// Called when iOS delivers an APNs device token.
    func handleDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        await upsertDeviceToken(token: token, optedIn: await currentOptIn())
    }

    /// Called when the user toggles notification permission on/off.
    func handleOptInChange(_ optedIn: Bool) async {
        await syncStoredDeviceToken(optedIn: optedIn)
    }

    // MARK: - Offline queue drain

    /// Replays all queued requests in order. Stops on first failure to preserve ordering.
    private func drainQueue() async {
        let items = queue.all()
        guard !items.isEmpty else { return }
        debugLog("draining \(items.count) queued request(s)")

        for item in items {
            do {
                try await backendClient.fire(path: item.path, body: item.body)
                queue.remove(id: item.id)
                debugLog("queue replay success: \(item.path)")
            } catch {
                debugLog("queue replay failed (\(item.path)), stopping drain: \(error.localizedDescription)")
                break // backend still down — stop and retry next launch
            }
        }
    }

    // MARK: - Private

    private func beginSession() async {
        guard activeSessionID == nil else { return }
        let sessionID = UUID().uuidString.lowercased()
        let startedAt = Date()
        activeSessionID = sessionID
        activeSessionStartedAt = startedAt
        let payload: [String: Any] = [
            "instance_id": appInstanceID,
            "session_id": sessionID,
            "started_at": Self.iso8601DateString(startedAt),
            "metadata": [:],
        ]
        do {
            try await backendClient.sessionStart(
                instanceID: appInstanceID,
                sessionID: sessionID,
                startedAt: startedAt
            )
        } catch {
            queue.enqueue(path: "session/start", body: payload)
            debugLog("session/start queued for retry")
        }
    }

    private func registerInstance() async {
        let payload: [String: Any] = [
            "instance_id": appInstanceID,
            "platform": "ios",
            "language": Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en",
            "locale": Locale.autoupdatingCurrent.identifier,
            "timezone": TimeZone.autoupdatingCurrent.identifier,
            "device_model": Self.deviceModelIdentifier(),
            "os_version": UIDevice.current.systemVersion,
            "app_version": Self.marketingVersion,
            "metadata": [
                "build": Self.buildNumber,
                "bundle_id": Bundle.main.bundleIdentifier ?? "",
                "environment": Self.appEnvironment,
            ],
        ]
        do {
            _ = try await backendClient.registerInstance(
                instanceID: appInstanceID,
                platform: "ios",
                language: Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en",
                locale: Locale.autoupdatingCurrent.identifier,
                timezone: TimeZone.autoupdatingCurrent.identifier,
                country: nil,
                deviceModel: Self.deviceModelIdentifier(),
                osVersion: UIDevice.current.systemVersion,
                appVersion: Self.marketingVersion,
                metadata: [
                    "build": Self.buildNumber,
                    "bundle_id": Bundle.main.bundleIdentifier ?? "",
                    "environment": Self.appEnvironment,
                ]
            )
            debugLog("register-instance success")
        } catch {
            queue.enqueue(path: "register-instance", body: payload)
            debugLog("register-instance queued for retry")
        }
    }

    private func syncStoredDeviceToken(optedIn: Bool) async {
        guard let token = defaults.string(forKey: StorageKey.lastDeviceToken), !token.isEmpty else {
            return
        }
        await upsertDeviceToken(token: token, optedIn: optedIn)
    }

    private func upsertDeviceToken(token: String, optedIn: Bool) async {
        let lastToken = defaults.string(forKey: StorageKey.lastDeviceToken) ?? ""
        let lastOptIn = defaults.object(forKey: StorageKey.lastSyncedOptIn) as? Bool

        guard token != lastToken || lastOptIn != optedIn else {
            debugLog("upsert-device-token skipped (no change)")
            return
        }

        do {
            try await backendClient.upsertDeviceToken(
                instanceID: appInstanceID,
                token: token,
                optedIn: optedIn
            )
            defaults.set(token, forKey: StorageKey.lastDeviceToken)
            defaults.set(optedIn, forKey: StorageKey.lastSyncedOptIn)
            debugLog("upsert-device-token success (opted_in=\(optedIn))")
        } catch {
            // Don't queue upsert-device-token — it is retried on next launch via
            // syncStoredDeviceToken, which re-reads the token from defaults.
            debugLog("upsert-device-token failed: \(error.localizedDescription)")
        }
    }

    /// Reads the current notification authorization status without prompting.
    private func currentOptIn() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Static helpers

    private static func loadOrCreateInstanceID(defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: StorageKey.appInstanceID),
           UUID(uuidString: existing) != nil {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: StorageKey.appInstanceID)
        return created
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }

    private static var marketingVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    private static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }

    private static var appEnvironment: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "production"
        #endif
    }

    private static func iso8601DateString(_ date: Date) -> String {
        sharedFormatter.string(from: date)
    }

    private static let sharedFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[QeidPlusManager] \(message)")
        #endif
    }

    // MARK: - Storage keys

    private enum StorageKey {
        static let appInstanceID    = "qeidplus.mobile.instance-id"
        static let lastDeviceToken  = "qeidplus.mobile.last-device-token"
        static let lastSyncedOptIn  = "qeidplus.mobile.last-synced-token-opt-in"
    }
}

// MARK: - Offline queue

/// Persists failed API requests to disk and replays them in order on the next launch.
private final class OfflineQueue {

    struct Item: Codable {
        let id: String
        let path: String
        let body: [String: JSONValue]
        let enqueuedAt: Date
    }

    private let fileURL: URL
    private var items: [Item] = []

    init(filename: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)
        self.items = (try? JSONDecoder().decode([Item].self, from: Data(contentsOf: fileURL))) ?? []
    }

    func all() -> [Item] { items }

    func enqueue(path: String, body: [String: Any]) {
        let encoded = body.compactMapValues { JSONValue(any: $0) }
        let item = Item(id: UUID().uuidString, path: path, body: encoded, enqueuedAt: Date())
        items.append(item)
        persist()
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        try? JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
    }
}

/// A JSON-encodable wrapper for heterogeneous `[String: Any]` dictionaries.
private enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init?(any value: Any) {
        switch value {
        case let v as String:  self = .string(v)
        case let v as Int:     self = .int(v)
        case let v as Double:  self = .double(v)
        case let v as Bool:    self = .bool(v)
        case let v as [String: Any]:
            let mapped = v.compactMapValues { JSONValue(any: $0) }
            self = .object(mapped)
        case let v as [Any]:
            let mapped = v.compactMap { JSONValue(any: $0) }
            self = .array(mapped)
        case is NSNull: self = .null
        default: return nil
        }
    }

    var asAny: Any {
        switch self {
        case .string(let v):  return v
        case .int(let v):     return v
        case .double(let v):  return v
        case .bool(let v):    return v
        case .object(let v):  return v.mapValues { $0.asAny }
        case .array(let v):   return v.map { $0.asAny }
        case .null:           return NSNull()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self)              { self = .string(v); return }
        if let v = try? c.decode(Bool.self)                { self = .bool(v);   return }
        if let v = try? c.decode(Int.self)                 { self = .int(v);    return }
        if let v = try? c.decode(Double.self)              { self = .double(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([JSONValue].self)         { self = .array(v);  return }
        if c.decodeNil()                                   { self = .null;      return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown JSON type")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v):  try c.encode(v)
        case .int(let v):     try c.encode(v)
        case .double(let v):  try c.encode(v)
        case .bool(let v):    try c.encode(v)
        case .object(let v):  try c.encode(v)
        case .array(let v):   try c.encode(v)
        case .null:           try c.encodeNil()
        }
    }
}

// MARK: - Backend client (private)

private final class MobileBackendClient {
    private let session: URLSession
    private let baseURL: URL
    private let mobileAPIKey: String?

    init(session: URLSession = .shared) {
        self.session = session
        self.baseURL = Self.resolvedBaseURL()
        self.mobileAPIKey = Self.resolvedMobileAPIKey()
    }

    /// Generic fire method used by the offline queue drain.
    func fire(path: String, body: [String: JSONValue]) async throws {
        let rawBody = body.mapValues { $0.asAny }
        _ = try await request(path: path, method: "POST", body: rawBody, idempotent: true) as EmptyDataEnvelope
    }

    func registerInstance(
        instanceID: String,
        platform: String,
        language: String,
        locale: String,
        timezone: String,
        country: String?,
        deviceModel: String,
        osVersion: String,
        appVersion: String,
        metadata: [String: String]
    ) async throws -> RegisterInstanceResponse {
        var payload: [String: Any] = [
            "instance_id": instanceID,
            "platform": platform,
            "language": language,
            "locale": locale,
            "timezone": timezone,
            "device_model": deviceModel,
            "os_version": osVersion,
            "app_version": appVersion,
            "metadata": metadata,
        ]
        if let country { payload["country"] = country }
        return try await request(path: "register-instance", method: "POST", body: payload, idempotent: true)
    }

    func upsertDeviceToken(instanceID: String, token: String, optedIn: Bool) async throws {
        _ = try await request(
            path: "upsert-device-token",
            method: "POST",
            body: [
                "instance_id": instanceID,
                "token": token,
                "opted_in": optedIn,
            ],
            idempotent: true
        ) as EmptyDataEnvelope
    }

    func sessionStart(instanceID: String, sessionID: String, startedAt: Date) async throws {
        _ = try await request(
            path: "session/start",
            method: "POST",
            body: [
                "instance_id": instanceID,
                "session_id": sessionID,
                "started_at": Self.iso8601DateString(startedAt),
                "metadata": [:],
            ],
            idempotent: true
        ) as EmptyDataEnvelope
    }

    func sessionEnd(instanceID: String, sessionID: String, endedAt: Date) async throws {
        _ = try await request(
            path: "session/end",
            method: "POST",
            body: [
                "instance_id": instanceID,
                "session_id": sessionID,
                "ended_at": Self.iso8601DateString(endedAt),
                "metadata": [:],
            ],
            idempotent: true
        ) as EmptyDataEnvelope
    }

    func bootstrapConfig(appVersion: String) async throws -> BootstrapConfigResponse {
        return try await request(
            path: "bootstrap-config",
            method: "GET",
            query: [URLQueryItem(name: "app_version", value: appVersion)],
            body: nil,
            idempotent: false
        )
    }

    func submitSupportTicket(instanceID: String, type: String, message: String) async throws -> SubmitTicketResponse {
        return try await request(
            path: "support-tickets",
            method: "POST",
            body: [
                "instance_id": instanceID,
                "type": type,
                "message": message,
            ],
            idempotent: false
        )
    }

    func listSupportTickets(instanceID: String) async throws -> [SupportTicket] {
        let envelope: SupportTicketListEnvelope = try await request(
            path: "support-tickets",
            method: "GET",
            query: [URLQueryItem(name: "instance_id", value: instanceID)],
            body: nil,
            idempotent: false
        )
        return envelope.data
    }

    // MARK: - Request engine

    private func request<Response: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: [String: Any]?,
        idempotent: Bool
    ) async throws -> Response {
        let endpoint = baseURL.appending(path: path)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw ClientError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let mobileAPIKey, !mobileAPIKey.isEmpty {
            urlRequest.setValue(mobileAPIKey, forHTTPHeaderField: "X-Mobile-Key")
        }
        if idempotent {
            urlRequest.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "Idempotency-Key")
        }
        if method != "GET" {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let body {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            }
        }

        debugLog("→ \(method) \(url.absoluteString)")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        debugLog("← \(httpResponse.statusCode) \(method) \(path)")

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ClientError.api(
                    code: apiError.error.code,
                    message: apiError.error.message,
                    details: apiError.error.details
                )
            }
            throw ClientError.statusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    // MARK: - URL / Key resolution

    private static func resolvedBaseURL() -> URL {
        let infoKey = "QeidPlusMobileApiBaseURL"
        if let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
            if !sanitized.isEmpty, let url = URL(string: sanitized) { return url }
        }
        return URL(string: fallbackBaseURL)!
    }

    private static func resolvedMobileAPIKey() -> String? {
        let infoKey = "QeidPlusMobileApiKey"
        if let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return fallbackMobileAPIKey
    }

    private static func iso8601DateString(_ date: Date) -> String {
        sharedFormatter.string(from: date)
    }

    private static let sharedFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackBaseURL = "https://almazyad.laravel.cloud/api/qaidplus/mobile/v1"
    private static let fallbackMobileAPIKey = "nUfpI0SnN7UkUwASRy05mXJ8hpGIzYuieXx0iF4soOg1FWCNtxxOptsSZjTAiDTP"

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[QeidPlusAPI] \(message)")
        #endif
    }
}

// MARK: - Error + response types (private)

private enum ClientError: Error {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case api(code: String, message: String, details: [String: [String]])
    case decoding(Error)
}

private struct APIErrorEnvelope: Decodable {
    let error: APIErrorBody
}
private struct APIErrorBody: Decodable {
    let code: String
    let message: String
    let details: [String: [String]]
}
private struct DataEnvelope<T: Decodable>: Decodable { let data: T }
private struct EmptyPayload: Decodable {}
private typealias EmptyDataEnvelope = DataEnvelope<EmptyPayload>

private struct RegisterInstanceResponse: Decodable {
    struct RegisterInstanceData: Decodable {
        let instanceId: String
        let country: String?
        let countrySource: String?
    }
    let data: RegisterInstanceData
}

// MARK: Bootstrap Config types

private struct BootstrapConfigResponse: Decodable {
    let data: BootstrapConfigData
}
private struct BootstrapConfigData: Decodable {
    let forceUpdate: ForceUpdatePayload
    let runtime: RuntimePayload
}
private struct ForceUpdatePayload: Decodable {
    let mode: String
    let required: Bool
    let minVersion: String?
    let message: String?
    let appStoreUrl: String?
}
private struct RuntimePayload: Decodable {
    let sessionMinSeconds: Int?
}

// MARK: Support Ticket types

struct SupportTicket: Decodable, Identifiable {
    let id: Int
    let type: String
    let message: String
    let status: String
    let adminReply: String?
    let repliedAt: String?
    let createdAt: String
}

private struct SupportTicketListEnvelope: Decodable {
    let data: [SupportTicket]
}

private struct SubmitTicketResponse: Decodable {
    struct SubmitTicketData: Decodable {
        let id: Int
        let type: String
        let status: String
        let createdAt: String
    }
    let data: SubmitTicketData
}
