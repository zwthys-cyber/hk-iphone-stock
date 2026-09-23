import Combine
import Foundation
import UIKit
import UserNotifications

struct SKU: Identifiable, Hashable {
    let part: String
    let storage: String
    let color: String
    let price: Int
    let storageSlug: String
    let colorSlug: String

    var id: String { part }
    var title: String { "\(storage) \(color)" }
    var priceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let amount = formatter.string(from: NSNumber(value: price)) ?? "\(price)"
        return "HK$\(amount)"
    }

    var productURL: URL {
        URL(string: "https://www.apple.com/hk/shop/buy-iphone/iphone-18-pro/6.9-inch-display-\(storageSlug)-\(colorSlug)")!
    }
}

struct AppleStore: Identifiable, Hashable {
    let id: String
    let name: String
    let area: String
    let place: String
}

struct StockHit: Identifiable, Hashable {
    let part: String
    let title: String
    let storeID: String
    let storeName: String
    let display: String
    let quote: String

    var id: String { part + "|" + storeID }
    var inStock: Bool { display == "available" }

    var statusText: String {
        if inStock { return "有货" }
        if display == "unavailable" { return "无货" }
        if quote.isEmpty { return "未知" }
        return quote
    }

    var detailQuote: String? {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !inStock && trimmed.localizedCaseInsensitiveContains("unavailable") { return nil }
        return trimmed
    }
}

struct StockEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let storeName: String
    let title: String
    let inStock: Bool
}

enum Catalog {
    static let skus: [SKU] = [
        SKU(part: "MJXQ4ZA/A", storage: "256GB", color: "勃艮第红", price: 11499, storageSlug: "256gb", colorSlug: "burgundy"),
        SKU(part: "MJXN4ZA/A", storage: "256GB", color: "黑色", price: 11499, storageSlug: "256gb", colorSlug: "black"),
        SKU(part: "MJXP4ZA/A", storage: "256GB", color: "银色", price: 11499, storageSlug: "256gb", colorSlug: "silver"),
        SKU(part: "MJXR4ZA/A", storage: "256GB", color: "冰川色", price: 11499, storageSlug: "256gb", colorSlug: "glacier"),
        SKU(part: "MJXV4ZA/A", storage: "512GB", color: "勃艮第红", price: 13299, storageSlug: "512gb", colorSlug: "burgundy"),
        SKU(part: "MJXT4ZA/A", storage: "512GB", color: "黑色", price: 13299, storageSlug: "512gb", colorSlug: "black"),
        SKU(part: "MJXU4ZA/A", storage: "512GB", color: "银色", price: 13299, storageSlug: "512gb", colorSlug: "silver"),
        SKU(part: "MJXW4ZA/A", storage: "512GB", color: "冰川色", price: 13299, storageSlug: "512gb", colorSlug: "glacier"),
        SKU(part: "MJY04ZA/A", storage: "1TB", color: "勃艮第红", price: 16799, storageSlug: "1tb", colorSlug: "burgundy"),
        SKU(part: "MJXX4ZA/A", storage: "1TB", color: "黑色", price: 16799, storageSlug: "1tb", colorSlug: "black"),
        SKU(part: "MJXY4ZA/A", storage: "1TB", color: "银色", price: 16799, storageSlug: "1tb", colorSlug: "silver"),
        SKU(part: "MJY14ZA/A", storage: "1TB", color: "冰川色", price: 16799, storageSlug: "1tb", colorSlug: "glacier"),
        SKU(part: "MJY44ZA/A", storage: "2TB", color: "勃艮第红", price: 21999, storageSlug: "2tb", colorSlug: "burgundy"),
        SKU(part: "MJY24ZA/A", storage: "2TB", color: "黑色", price: 21999, storageSlug: "2tb", colorSlug: "black"),
        SKU(part: "MJY34ZA/A", storage: "2TB", color: "银色", price: 21999, storageSlug: "2tb", colorSlug: "silver"),
        SKU(part: "MJY54ZA/A", storage: "2TB", color: "冰川色", price: 21999, storageSlug: "2tb", colorSlug: "glacier"),
    ]

    static let stores: [AppleStore] = [
        AppleStore(id: "R409", name: "铜锣湾", area: "港岛", place: "希慎广场"),
        AppleStore(id: "R428", name: "ifc mall", area: "港岛", place: "中环"),
        AppleStore(id: "R499", name: "广东道", area: "九龙", place: "尖沙咀"),
        AppleStore(id: "R673", name: "apm", area: "九龙", place: "观塘"),
        AppleStore(id: "R485", name: "又一城", area: "九龙", place: "九龙塘"),
        AppleStore(id: "R610", name: "新城市广场", area: "新界", place: "沙田"),
    ]

    static let areas = ["港岛", "九龙", "新界"]
    static let storages = ["256GB", "512GB", "1TB", "2TB"]
    static let storeNames: [String: String] = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0.name) })

    static func sku(part: String) -> SKU? {
        skus.first { $0.part == part }
    }

    static func stores(in area: String) -> [AppleStore] {
        stores.filter { $0.area == area }
    }
}

enum StockError: LocalizedError {
    case blocked
    case empty
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .blocked:
            return "苹果暂时拒绝了查询，下一轮会再试。"
        case .empty:
            return "没有返回门店数据。"
        case .badStatus(let code):
            return "查询失败（HTTP \(code)）。"
        }
    }
}

enum StockClient {
    static func fetch(part: String) async throws -> [StockHit] {
        var components = URLComponents(string: "https://www.apple.com/hk/shop/retail/pickup-message")!
        components.queryItems = [
            URLQueryItem(name: "pl", value: "true"),
            URLQueryItem(name: "parts.0", value: part),
            URLQueryItem(name: "location", value: "香港"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 25
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-HK,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.apple.com/hk/shop/buy-iphone/iphone-18-pro", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw StockError.badStatus(http.statusCode)
        }
        guard let first = data.first, first == UInt8(ascii: "{") else {
            throw StockError.blocked
        }
        let decoded = try JSONDecoder().decode(PickupEnvelope.self, from: data)
        guard !decoded.body.stores.isEmpty else { throw StockError.empty }
        let known = Catalog.sku(part: part)
        return decoded.body.stores.map { store in
            let partInfo = store.partsAvailability[part]
            let quote = partInfo?.messageTypes?.regular?.storePickupQuote
                ?? partInfo?.pickupSearchQuote
                ?? ""
            let title = partInfo?.messageTypes?.regular?.storePickupProductTitle
                ?? known.map { "iPhone 18 Pro Max \($0.title)" }
                ?? part
            return StockHit(
                part: part,
                title: title,
                storeID: store.storeNumber,
                storeName: Catalog.storeNames[store.storeNumber] ?? store.storeName,
                display: partInfo?.pickupDisplay ?? "",
                quote: quote
            )
        }
    }
}

private struct PickupEnvelope: Decodable {
    struct Body: Decodable { let stores: [StoreJSON] }
    let body: Body
}

private struct StoreJSON: Decodable {
    let storeNumber: String
    let storeName: String
    let partsAvailability: [String: PartJSON]
}

private struct PartJSON: Decodable {
    let pickupDisplay: String?
    let pickupSearchQuote: String?
    let messageTypes: MessageTypes?

    struct MessageTypes: Decodable {
        struct Regular: Decodable {
            let storePickupQuote: String?
            let storePickupProductTitle: String?
        }
        let regular: Regular?
    }
}

@MainActor
final class MonitorModel: ObservableObject {
    @Published var selectedParts: Set<String>
    @Published var selectedStores: Set<String>
    @Published var interval: Int
    @Published var running = false
    @Published var checking = false
    @Published var progress = ""
    @Published var errorText = ""
    @Published var updatedAt: Date?
    @Published var hits: [StockHit] = []
    @Published var events: [StockEvent] = []
    @Published var customPart = ""
    @Published var nextCheckAt: Date?

    private var loop: Task<Void, Never>?
    private var baseline: [String: String] = [:]
    private let allowedIntervals = [60, 90, 120, 180]

    init() {
        let defaults = UserDefaults.standard
        let savedParts = defaults.string(forKey: "parts") ?? "MJXQ4ZA/A"
        let savedStores = defaults.string(forKey: "stores") ?? Catalog.stores.map(\.id).joined(separator: ",")
        selectedParts = Set(savedParts.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        selectedStores = Set(savedStores.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        let savedInterval = defaults.integer(forKey: "interval")
        interval = allowedIntervals.contains(savedInterval) ? savedInterval : 60
        if let data = defaults.data(forKey: "events"),
           let decoded = try? JSONDecoder().decode([StockEvent].self, from: data) {
            events = decoded
        }
    }

    var selectedSKUs: [SKU] {
        Catalog.skus.filter { selectedParts.contains($0.part) }
    }

    var customParts: [String] {
        selectedParts.filter { Catalog.sku(part: $0) == nil }.sorted()
    }

    func boot() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func hit(part: String, store: String) -> StockHit? {
        hits.first { $0.part == part && $0.storeID == store }
    }

    func inStockCount(part: String?) -> Int {
        hits.filter { hit in
            hit.inStock
                && selectedStores.contains(hit.storeID)
                && selectedParts.contains(hit.part)
                && (part == nil || hit.part == part)
        }.count
    }

    func togglePart(_ part: String) {
        if selectedParts.contains(part) {
            selectedParts.remove(part)
        } else if selectedParts.count >= 6 {
            errorText = "一次最多盯 6 个型号。"
            return
        } else {
            selectedParts.insert(part)
            errorText = ""
        }
        persist()
    }

    func toggleStore(_ id: String) {
        if selectedStores.contains(id) {
            guard selectedStores.count > 1 else { return }
            selectedStores.remove(id)
        } else {
            selectedStores.insert(id)
        }
        persist()
    }

    func applyHot() {
        selectedParts = ["MJXQ4ZA/A"]
        errorText = ""
        persist()
    }

    func applyBurgundy() {
        selectedParts = Set(Catalog.skus.filter { $0.color == "勃艮第红" }.map(\.part))
        errorText = ""
        persist()
    }

    func selectStorage(_ storage: String) {
        selectedParts = Set(Catalog.skus.filter { $0.storage == storage }.map(\.part))
        errorText = ""
        persist()
    }

    func addCustomPart() {
        let part = customPart.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard part.range(of: #"^[A-Z0-9]{4,8}ZA/A$"#, options: .regularExpression) != nil else {
            errorText = "零件号要像 MJXQ4ZA/A，以 ZA/A 结尾。"
            return
        }
        guard selectedParts.count < 6 else {
            errorText = "一次最多盯 6 个型号。"
            return
        }
        selectedParts.insert(part)
        customPart = ""
        errorText = ""
        persist()
    }

    func setInterval(_ value: Int) {
        guard allowedIntervals.contains(value) else { return }
        interval = value
        persist()
    }

    func clearEvents() {
        events = []
        UserDefaults.standard.removeObject(forKey: "events")
    }

    func start() {
        guard !selectedParts.isEmpty, !selectedStores.isEmpty else {
            errorText = "先勾选型号和门店。"
            return
        }
        errorText = ""
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        baseline = [:]
        nextCheckAt = nil
        loop?.cancel()
        loop = Task { [weak self] in
            guard let self else { return }
            var primed = false
            while !Task.isCancelled {
                await self.checkOnce(notify: primed)
                primed = true
                let seconds = self.interval
                self.nextCheckAt = Date().addingTimeInterval(TimeInterval(seconds))
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            }
        }
    }

    func stop() {
        running = false
        loop?.cancel()
        loop = nil
        nextCheckAt = nil
        progress = ""
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func checkOnce(notify: Bool) async {
        let parts = selectedParts.sorted()
        guard !parts.isEmpty, !checking else { return }
        checking = true
        defer {
            checking = false
            progress = ""
        }
        var next = hits
        for (index, part) in parts.enumerated() {
            if Task.isCancelled { return }
            progress = "正在查 \(index + 1)/\(parts.count)"
            if index > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            do {
                let rows = try await StockClient.fetch(part: part)
                next.removeAll { $0.part == part }
                next.append(contentsOf: rows)
                errorText = ""
            } catch {
                errorText = error.localizedDescription
            }
        }
        if Task.isCancelled { return }
        hits = next
        updatedAt = Date()
        for hit in next where parts.contains(hit.part) && selectedStores.contains(hit.storeID) {
            let previous = baseline[hit.id]
            baseline[hit.id] = hit.display
            guard notify, let previous, previous != hit.display else { continue }
            guard hit.display == "available" || hit.display == "unavailable" else { continue }
            appendEvent(hit)
            if hit.inStock {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                postNotification(hit)
            }
        }
    }

    func countdown(at date: Date) -> String {
        guard running else { return "未在盯货" }
        if checking { return progress.isEmpty ? "正在查询" : progress }
        guard let nextCheckAt else { return "正在查询" }
        let seconds = max(0, Int(nextCheckAt.timeIntervalSince(date).rounded(.up)))
        return "\(seconds) 秒后再查 · 屏幕保持常亮"
    }

    private func appendEvent(_ hit: StockHit) {
        events.insert(
            StockEvent(
                id: UUID(),
                date: Date(),
                storeName: hit.storeName,
                title: hit.title,
                inStock: hit.inStock
            ),
            at: 0
        )
        if events.count > 40 {
            events.removeLast(events.count - 40)
        }
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: "events")
        }
    }

    private func postNotification(_ hit: StockHit) {
        let content = UNMutableNotificationContent()
        content.title = "有货 · \(hit.storeName)"
        content.body = hit.title
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: hit.id + "-" + UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(selectedParts.sorted().joined(separator: ","), forKey: "parts")
        defaults.set(selectedStores.sorted().joined(separator: ","), forKey: "stores")
        defaults.set(interval, forKey: "interval")
    }
}
