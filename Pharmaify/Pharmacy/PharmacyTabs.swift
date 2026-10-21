import SwiftUI
import SwiftData

struct PharmacyTabs: View {
    @Query(filter: #Predicate<Pharmacy> { $0.isMine == true }) private var mine: [Pharmacy]

    var body: some View {
        if let store = mine.first {
            TabView {
                Tab("Queue", systemImage: "tray.full") { QueueView(store: store) }
                    .badge(store.orders.filter { $0.status == .submitted }.count)
                Tab("Inventory", systemImage: "shippingbox") { InventoryView(store: store) }
                    .badge(store.lowStock.count)
                Tab("Store", systemImage: "storefront") { StoreView(store: store) }
            }
        } else {
            ProgressView()
        }
    }
}

enum QueueFilter: String, CaseIterable, Identifiable {
    case new = "New", working = "Working", ready = "Ready", done = "Done"
    var id: String { rawValue }

    func matches(_ status: OrderStatus) -> Bool {
        switch self {
        case .new: status == .submitted
        case .working: status == .received || status == .filling
        case .ready: status == .ready
        case .done: !status.isOpen
        }
    }
}

struct QueueView: View {
    let store: Pharmacy
    @State private var filter: QueueFilter = .new

    private var orders: [RxOrder] {
        store.orders
            .filter { filter.matches($0.status) }
            .sorted { filter == .done ? $0.updatedAt > $1.updatedAt : $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $filter) {
                    ForEach(QueueFilter.allCases) { f in
                        Text("\(f.rawValue) \(store.orders.filter { f.matches($0.status) }.count)").tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(orders) { order in
                    NavigationLink { QueueOrderDetail(order: order) } label: { QueueRow(order: order) }
                        .swipeActions(edge: .trailing) {
                            if order.status.isOpen {
                                Button("Cancel", role: .destructive) { order.cancel() }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if let next = order.status.next {
                                Button(next.actionTitle) { Queue.advance(order) }.tint(next.color)
                            }
                        }
                }
            }
            .overlay {
                if orders.isEmpty {
                    ContentUnavailableView("Nothing \(filter.rawValue.lowercased())", systemImage: "tray",
                                           description: Text("Refill requests from customers land here."))
                }
            }
            .navigationTitle("Refill queue")
        }
    }
}

enum Queue {
    static func advance(_ order: RxOrder) {
        guard let next = order.advance() else { return }
        if next == .filling { order.pharmacy?.dispense(order) }
        try? order.modelContext?.save()
        Notifier.orderUpdated(order)
    }
}

struct QueueRow: View {
    let order: RxOrder

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(order.medicationName).font(.headline)
                Text("\(order.customerName) · qty \(order.quantity)").font(.subheadline)
                Text("Sent \(order.createdAt, style: .relative) ago").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                StatusPill(status: order.status)
                if order.photo != nil {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct QueueOrderDetail: View {
    let order: RxOrder

    var body: some View {
        List {
            Section {
                StatusTracker(order: order).padding(.vertical, 8)
                if let next = order.status.next {
                    Button { withAnimation { Queue.advance(order) } } label: {
                        Label(next.actionTitle, systemImage: next.systemImage)
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.glassProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            Section("Customer") {
                LabeledContent("Name", value: order.customerName)
                if let url = Phone.url(order.customerPhone) {
                    Link(destination: url) { Label(Phone.display(order.customerPhone), systemImage: "phone") }
                }
            }
            Section("Prescription") {
                LabeledContent("Medication", value: order.medicationName)
                LabeledContent("Quantity", value: "\(order.quantity)")
                LabeledContent("Refills left", value: "\(order.refillsRemaining)")
                if !order.notes.isEmpty { Text(order.notes).foregroundStyle(.secondary) }
                if let data = order.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 12))
                }
                if let shelf = order.pharmacy?.medications.first(where: { $0.label.caseInsensitiveCompare(order.medicationName) == .orderedSame }) {
                    LabeledContent("On hand", value: "\(shelf.stock)")
                        .foregroundStyle(shelf.stock < order.quantity ? Color.red : Color.primary)
                }
            }
            Section("Timeline") { OrderTimeline(order: order) }
            if order.status.isOpen {
                Section {
                    Button("Cancel request", role: .destructive) { order.cancel() }
                }
            }
        }
        .navigationTitle(order.customerName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
