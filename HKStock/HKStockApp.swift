import SwiftUI
import UIKit
import UserNotifications

@main
struct HKStockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
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

struct RootView: View {
    @StateObject private var model = MonitorModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showModels = false
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            DashboardView(model: model)
                .navigationTitle("港行库存")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("记录") { showLog = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("型号 \(model.selectedParts.count)") { showModels = true }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    WatchBar(model: model)
                }
        }
        .sheet(isPresented: $showModels) {
            ModelSheet(model: model)
        }
        .sheet(isPresented: $showLog) {
            LogSheet(model: model)
        }
        .onAppear { model.boot() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.stop()
            }
        }
        .tint(Color.accentColor)
    }
}

struct DashboardView: View {
    @ObservedObject var model: MonitorModel
    @State private var showAll = false
    @State private var focusPart: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                if model.selectedParts.count > 1 {
                    partChips
                }
                storeBoard
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await model.checkOnce(notify: model.running)
        }
    }

    private var activePart: String? {
        if showAll { return nil }
        if let focusPart, model.selectedParts.contains(focusPart) { return focusPart }
        return model.selectedParts.sorted().first
    }

    private var hero: some View {
        let part = activePart
        let count = model.inStockCount(part: part)
        let checked = model.updatedAt != nil
        return VStack(alignment: .leading, spacing: 10) {
            Text("iPhone 18 Pro Max · 香港")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(heroTitle)
                .font(.title2.weight(.semibold))
            HStack(alignment: .firstTextBaseline) {
                StatusPill(
                    text: !checked ? "尚未查询" : (count > 0 ? "\(count) 处有货" : "暂无现货"),
                    positive: checked && count > 0
                )
                Spacer(minLength: 12)
                if let price = singlePrice {
                    Text(price)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let updatedAt = model.updatedAt {
                Text("上次 \(updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !model.errorText.isEmpty {
                Text(model.errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var heroTitle: String {
        if let part = activePart, let sku = Catalog.sku(part: part) {
            return sku.title
        }
        if model.selectedParts.count <= 1, let only = model.customParts.first, model.selectedSKUs.isEmpty {
            return only
        }
        return "\(model.selectedParts.count) 个型号"
    }

    private var singlePrice: String? {
        guard let part = activePart, let sku = Catalog.sku(part: part) else { return nil }
        return sku.priceText
    }

    private var partChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("全部", selected: showAll) {
                    showAll = true
                }
                ForEach(model.selectedSKUs) { sku in
                    chip(sku.title, selected: !showAll && activePart == sku.part) {
                        showAll = false
                        focusPart = sku.part
                    }
                }
                ForEach(model.customParts, id: \.self) { part in
                    chip(part, selected: !showAll && activePart == part) {
                        showAll = false
                        focusPart = part
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var storeBoard: some View {
        let parts = boardParts
        return VStack(alignment: .leading, spacing: 18) {
            if parts.count > 1 && activePart == nil {
                ForEach(parts, id: \.self) { part in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(partTitle(part))
                            .font(.headline)
                        rows(for: part, grouped: false)
                    }
                }
            } else if let part = parts.first {
                rows(for: part, grouped: true)
            } else {
                Text("还没有型号。点右上角「型号」选一台。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var boardParts: [String] {
        if let activePart { return [activePart] }
        return model.selectedParts.sorted()
    }

    @ViewBuilder
    private func rows(for part: String, grouped: Bool) -> some View {
        if grouped {
            ForEach(Catalog.areas, id: \.self) { area in
                let stores = Catalog.stores(in: area).filter { model.selectedStores.contains($0.id) }
                if !stores.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(area)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        ForEach(stores) { store in
                            StoreCard(store: store, hit: model.hit(part: part, store: store.id), part: part)
                        }
                    }
                }
            }
        } else {
            ForEach(Catalog.stores.filter { model.selectedStores.contains($0.id) }) { store in
                StoreCard(store: store, hit: model.hit(part: part, store: store.id), part: part)
            }
        }
    }

    private func partTitle(_ part: String) -> String {
        Catalog.sku(part: part)?.title ?? part
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(SnapButtonStyle())
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

struct StoreCard: View {
    let store: AppleStore
    let hit: StockHit?
    let part: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.body.weight(.semibold))
                Text("\(store.place)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let quote = hit?.detailQuote {
                    Text(quote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                StatusPill(text: hit?.statusText ?? "待查询", positive: hit?.inStock == true)
                if hit?.inStock == true {
                    Link("购买", destination: buyURL)
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(hit?.inStock == true ? Color.green.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    private var buyURL: URL {
        if let sku = Catalog.sku(part: part) { return sku.productURL }
        return URL(string: "https://www.apple.com/hk/shop/product/\(part)")!
    }
}

struct StatusPill: View {
    let text: String
    let positive: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(positive ? Color.green : Color.secondary)
            .background(
                (positive ? Color.green : Color.secondary).opacity(0.14),
                in: Capsule()
            )
    }
}

struct WatchBar: View {
    @ObservedObject var model: MonitorModel

    var body: some View {
        VStack(spacing: 8) {
            if model.running {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(model.countdown(at: context.date))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("锁屏或离开 App 后会停止查询")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                model.running ? model.stop() : model.start()
            } label: {
                Text(model.running ? "停止盯货" : "开始盯货")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        model.running ? Color(.systemGray) : Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(SnapButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

struct ModelSheet: View {
    @ObservedObject var model: MonitorModel
    @Environment(\.dismiss) private var dismiss
    @State private var storage = "256GB"

    var body: some View {
        NavigationStack {
            List {
                Section("快捷") {
                    Button("256GB 勃艮第红") { model.applyHot() }
                    Button("四个容量的勃艮第红") { model.applyBurgundy() }
                }
                Section {
                    Picker("容量", selection: $storage) {
                        ForEach(Catalog.storages, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                    ForEach(Catalog.skus.filter { $0.storage == storage }) { sku in
                        Button {
                            model.togglePart(sku.part)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(swatch(sku.color))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sku.color).foregroundStyle(.primary)
                                    Text(sku.priceText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.selectedParts.contains(sku.part) {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                    Button("盯这个容量的四种颜色") { model.selectStorage(storage) }
                } header: {
                    Text("iPhone 18 Pro Max")
                } footer: {
                    Text("已选 \(model.selectedParts.count)/6。查询间隔里，每个型号之间会停 2 秒。")
                }
                if !model.customParts.isEmpty {
                    Section("已加的零件号") {
                        ForEach(model.customParts, id: \.self) { part in
                            Button {
                                model.togglePart(part)
                            } label: {
                                HStack {
                                    Text(part).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                Section("其他港版零件号") {
                    HStack {
                        TextField("例如 MJXQ4ZA/A", text: $model.customPart)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button("加入") { model.addCustomPart() }
                    }
                }
                Section("香港门店") {
                    ForEach(Catalog.stores) { store in
                        Button {
                            model.toggleStore(store.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.name).foregroundStyle(.primary)
                                    Text("\(store.area) · \(store.place)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.selectedStores.contains(store.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                Section("查询间隔") {
                    Picker("间隔", selection: Binding(
                        get: { model.interval },
                        set: { model.setInterval($0) }
                    )) {
                        Text("1分").tag(60)
                        Text("1.5").tag(90)
                        Text("2分").tag(120)
                        Text("3分").tag(180)
                    }
                    .pickerStyle(.segmented)
                }
                if !model.errorText.isEmpty {
                    Section {
                        Text(model.errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("盯哪些")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func swatch(_ color: String) -> Color {
        switch color {
        case "勃艮第红":
            return Color(red: 0.55, green: 0.15, blue: 0.20)
        case "黑色":
            return Color(white: 0.16)
        case "银色":
            return Color(white: 0.78)
        case "冰川色":
            return Color(red: 0.70, green: 0.84, blue: 0.90)
        default:
            return Color.secondary
        }
    }
}

struct LogSheet: View {
    @ObservedObject var model: MonitorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.events.isEmpty {
                    VStack(spacing: 8) {
                        Text("还没有记录")
                            .font(.title3.weight(.semibold))
                        Text("开始盯货之后，只有从无货变成有货、或从有货变成无货才会记下来。第一次查询只用来认底。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(model.events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(event.inStock ? Color.green : Color.secondary.opacity(0.45))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.inStock ? "有货" : "无货")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(event.storeName) · \(event.title)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(event.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("到货记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("清空") { model.clearEvents() }
                        .disabled(model.events.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("港行库存 1.1 · 香港官网到店取货")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SnapButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
