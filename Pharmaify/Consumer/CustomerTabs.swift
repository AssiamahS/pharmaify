import SwiftUI
import SwiftData

struct CustomerTabs: View {
    var body: some View {
        TabView {
            Tab("Refills", systemImage: "bag") { MyOrdersView() }
            Tab("Pharmacies", systemImage: "cross.case") { PharmacyBrowserView() }
            Tab("Reminders", systemImage: "alarm") { RemindersView() }
            Tab("Account", systemImage: "person.crop.circle") { CustomerAccountView() }
        }
    }
}

struct MyOrdersView: View {
    @AppStorage(Profile.phoneKey) private var phone = ""
    @Query(sort: \RxOrder.createdAt, order: .reverse) private var orders: [RxOrder]
    @State private var showNew = false

    private var mine: [RxOrder] {
        let me = Phone.digits(phone)
        guard !me.isEmpty else { return [] }
        return orders.filter { Phone.digits($0.customerPhone) == me }
    }

    var body: some View {
        NavigationStack {
            Group {
                if mine.isEmpty {
                    ContentUnavailableView {
                        Label("No refills yet", systemImage: "pills")
                    } description: {
                        Text("Pick a pharmacy, snap your prescription label, and track it to pickup.")
                    } actions: {
                        Button("Request a refill") { showNew = true }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    List {
                        let active = mine.filter { $0.status.isOpen }
                        let past = mine.filter { !$0.status.isOpen }
                        if !active.isEmpty {
                            Section("In progress") {
                                ForEach(active) { order in
                                    NavigationLink { CustomerOrderDetail(order: order) } label: { CustomerOrderRow(order: order) }
                                }
                            }
                        }
                        if !past.isEmpty {
                            Section("History") {
                                ForEach(past) { order in
                                    NavigationLink { CustomerOrderDetail(order: order) } label: { CustomerOrderRow(order: order) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My refills")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNew = true } label: { Label("New refill", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showNew) { NewOrderView() }
        }
    }
}

struct CustomerOrderRow: View {
    let order: RxOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.medicationName).font(.headline)
                    Text(order.pharmacy?.name ?? "Pharmacy").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(status: order.status)
            }
            if order.status.isOpen {
                StatusTracker(order: order)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CustomerOrderDetail: View {
    @Environment(\.modelContext) private var context
    let order: RxOrder

    var body: some View {
        List {
            Section {
                StatusTracker(order: order).padding(.vertical, 8)
                if order.status == .ready, let pharmacy = order.pharmacy {
                    Label("Pick up at \(pharmacy.address), \(pharmacy.city)", systemImage: "mappin.and.ellipse")
                    Label(pharmacy.hours, systemImage: "clock")
                }
            }
            Section("Request") {
                LabeledContent("Medication", value: order.medicationName)
                LabeledContent("Quantity", value: "\(order.quantity)")
                LabeledContent("Refills left", value: "\(order.refillsRemaining)")
                if !order.notes.isEmpty { LabeledContent("Notes", value: order.notes) }
                if let data = order.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 12))
                }
            }
            Section("Timeline") { OrderTimeline(order: order) }
            if let pharmacy = order.pharmacy, let url = Phone.url(pharmacy.phone) {
                Section {
                    Link(destination: url) { Label("Call \(pharmacy.name)", systemImage: "phone") }
                }
            }
            if order.status == .submitted {
                Section {
                    Button("Cancel request", role: .destructive) {
                        order.cancel()
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle(order.medicationName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CustomerAccountView: View {
    @AppStorage(Profile.nameKey) private var name = ""
    @AppStorage(Profile.phoneKey) private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                    TextField("Mobile number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } header: {
                    Text("You")
                } footer: {
                    Text("Pharmacies match your refills by this number.")
                }
                Section { SwitchSideButton(to: .pharmacy) }
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                } footer: {
                    Text("Pharmaify is a demo build. Don't send real prescription details yet.")
                }
            }
            .navigationTitle("Account")
        }
    }
}
