import SwiftUI
import UIKit
import UserNotifications

@main
struct HKStockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

struct SKU: Identifiable, Hashable {
    let part: String
    let storage: String
    let color: String
    let price: Int
    let storageSlug: String
    let colorSlug: String
    var id: String { part }
    var title: String { "\(storage) \(color)" }
    var priceText: String { "HK$\(price)" }
    var productURL: URL {
        URL(string: "https://www.apple.com/hk/shop/buy-iphone/iphone-18-pro/6.9-inch-display-\(storageSlug)-\(colorSlug)")!
    }
}

struct AppleStore: Identifiable, Hashable {
    let id: String
    let name: String
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
        AppleStore(id: "R409", name: "铜锣湾"),
        AppleStore(id: "R428", name: "ifc mall"),
        AppleStore(id: "R499", name: "广东道"),
        AppleStore(id: "R673", name: "apm"),
        AppleStore(id: "R485", name: "又一城"),
        AppleStore(id: "R610", name: "新城市广场"),
    ]

    static let storeNames: [String: String] = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0.name) })

    static func sku(part: String) -> SKU? {
        skus.first { $0.part == part }
    }
}

enum StockError: LocalizedError {
    case blocked
    case empty
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .blocked:
            return "苹果暂时拒绝了查询，下一轮会再试。间隔不要短于 1 分钟。"
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
    @Published var customPart = ""

    private var loop: Task<Void, Never>?
    private var baseline: [String: String] = [:]
    private let intervals = [60, 90, 120, 180]

    init() {
        let defaults = UserDefaults.standard
        let savedParts = defaults.string(forKey: "parts") ?? "MJXQ4ZA/A"
        let savedStores = defaults.string(forKey: "stores") ?? Catalog.stores.map(\.id).joined(separator: ",")
        selectedParts = Set(savedParts.split(separator: ",").map(String.init))
        selectedStores = Set(savedStores.split(separator: ",").map(String.init))
        let savedInterval = defaults.integer(forKey: "interval")
        interval = intervals.contains(savedInterval) ? savedInterval : 60
    }

    func boot() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var visibleHits: [StockHit] {
        hits
            .filter { selectedParts.contains($0.part) && selectedStores.contains($0.storeID) }
            .sorted { lhs, rhs in
                if lhs.inStock != rhs.inStock { return lhs.inStock && !rhs.inStock }
                if lhs.title != rhs.title { return lhs.title < rhs.title }
                return lhs.storeName < rhs.storeName
            }
    }

    var inStockCount: Int { visibleHits.filter(\.inStock).count }

    func togglePart(_ part: String) {
        if selectedParts.contains(part) {
            selectedParts.remove(part)
        } else if selectedParts.count >= 6 {
            errorText = "一次最多盯 6 个型号，避免查得太密被苹果挡住。"
            return
        } else {
            selectedParts.insert(part)
            errorText = ""
        }
        persist()
    }

    func toggleStore(_ id: String) {
        if selectedStores.contains(id) {
            selectedStores.remove(id)
        } else {
            selectedStores.insert(id)
        }
        persist()
    }

    func addCustomPart() {
        let part = customPart.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard part.range(of: #"^[A-Z0-9]{4,8}ZA/A$"#, options: .regularExpression) != nil else {
            errorText = "零件号要像 MJXQ4ZA/A 这样，以 ZA/A 结尾。"
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
        interval = value
        persist()
    }

    func start() {
        guard !selectedParts.isEmpty, !selectedStores.isEmpty else {
            errorText = "先勾选型号和门店。"
            return
        }
        errorText = ""
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        baseline = [:]
        loop?.cancel()
        loop = Task { [weak self] in
            guard let self else { return }
            var primed = false
            while !Task.isCancelled {
                await self.checkOnce(notify: primed)
                primed = true
                let seconds = self.interval
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            }
        }
    }

    func stop() {
        running = false
        loop?.cancel()
        loop = nil
        UIApplication.shared.isIdleTimerDisabled = false
        progress = ""
    }

    func checkOnce(notify: Bool) async {
        let parts = selectedParts.sorted()
        guard !parts.isEmpty else { return }
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
            let key = hit.id
            let previous = baseline[key]
            baseline[key] = hit.display
            if notify, hit.inStock, let previous, previous != "available" {
                notifyInStock(hit)
            }
        }
    }

    private func notifyInStock(_ hit: StockHit) {
        let content = UNMutableNotificationContent()
        content.title = "有货 · \(hit.storeName)"
        content.body = hit.title
        content.sound = .default
        let request = UNNotificationRequest(identifier: hit.id + "-" + UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(selectedParts.sorted().joined(separator: ","), forKey: "parts")
        defaults.set(selectedStores.sorted().joined(separator: ","), forKey: "stores")
        defaults.set(interval, forKey: "interval")
    }
}

struct ContentView: View {
    @StateObject private var model = MonitorModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.inStockCount > 0 ? "\(model.inStockCount) 家门店有货" : "目前没有可取货的门店")
                            .font(.title3.weight(.semibold))
                        Text(statusLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !model.progress.isEmpty {
                            Text(model.progress)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if !model.errorText.isEmpty {
                            Text(model.errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("盯货") {
                    Button(model.running ? "停止盯货" : "开始盯货") {
                        model.running ? model.stop() : model.start()
                    }
                    .font(.body.weight(.semibold))
                    Button("立即查一次") {
                        Task { await model.checkOnce(notify: false) }
                    }
                    .disabled(model.checking)
                    Picker("间隔", selection: Binding(
                        get: { model.interval },
                        set: { model.setInterval($0) }
                    )) {
                        Text("1 分钟").tag(60)
                        Text("1.5 分钟").tag(90)
                        Text("2 分钟").tag(120)
                        Text("3 分钟").tag(180)
                    }
                }

                Section("iPhone 18 Pro Max 港版") {
                    ForEach(modelGroups, id: \.0) { storage, items in
                        Text(storage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(items) { sku in
                            Button {
                                model.togglePart(sku.part)
                            } label: {
                                HStack {
                                    Image(systemName: model.selectedParts.contains(sku.part) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(model.selectedParts.contains(sku.part) ? Color.accentColor : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sku.color).foregroundStyle(.primary)
                                        Text("\(sku.part) · \(sku.priceText)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("其他 ZA/A 零件号", text: $model.customPart)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button("加入") { model.addCustomPart() }
                    }
                    ForEach(customSelected, id: \.self) { part in
                        Button {
                            model.togglePart(part)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text(part).foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                }

                Section("香港门店") {
                    ForEach(Catalog.stores) { store in
                        Button {
                            model.toggleStore(store.id)
                        } label: {
                            HStack {
                                Image(systemName: model.selectedStores.contains(store.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.selectedStores.contains(store.id) ? Color.accentColor : .secondary)
                                Text(store.name).foregroundStyle(.primary)
                                Spacer()
                                Text(store.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("查询结果") {
                    if model.visibleHits.isEmpty {
                        Text("还没有结果。勾好型号和门店后点「立即查一次」。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.visibleHits) { hit in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(hit.inStock ? "有货" : hit.statusText)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(hit.inStock ? Color.green : Color.secondary)
                                    Text(hit.storeName)
                                    Spacer()
                                }
                                Text(hit.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if hit.inStock {
                                    Link("打开香港购买页", destination: buyURL(for: hit))
                                        .font(.footnote)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("港行库存")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { model.boot() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.stop()
            }
        }
    }

    private var customSelected: [String] {
        model.selectedParts.filter { Catalog.sku(part: $0) == nil }.sorted()
    }

    private func buyURL(for hit: StockHit) -> URL {
        if let sku = Catalog.sku(part: hit.part) {
            return sku.productURL
        }
        return URL(string: "https://www.apple.com/hk/shop/product/\(hit.part)")!
    }

    private var modelGroups: [(String, [SKU])] {
        let order = ["256GB", "512GB", "1TB", "2TB"]
        return order.compactMap { storage in
            let items = Catalog.skus.filter { $0.storage == storage }
            return items.isEmpty ? nil : (storage, items)
        }
    }

    private var statusLine: String {
        let when: String
        if let updatedAt = model.updatedAt {
            when = updatedAt.formatted(date: .omitted, time: .standard)
        } else {
            when = "尚未查询"
        }
        if model.running {
            return "盯货中 · 屏幕保持常亮 · 上次 \(when)"
        }
        return "未在盯货 · 上次 \(when)。锁屏或退出后会停止查询。"
    }
}
