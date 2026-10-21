import SwiftUI
import SwiftData

struct StoreView: View {
    @Bindable var store: Pharmacy

    private var filledToday: Int {
        store.orders.filter { $0.status == .pickedUp && Calendar.current.isDateInToday($0.updatedAt) }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        stat("New", store.orders.filter { $0.status == .submitted }.count, .blue)
                        stat("Ready", store.orders.filter { $0.status == .ready }.count, .brand)
                        stat("Low stock", store.lowStock.count, .orange)
                        stat("Done today", filledToday, .gray)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("Store profile") {
                    TextField("Name", text: $store.name)
                    TextField("Street address", text: $store.address)
                    TextField("City, state", text: $store.city)
                    TextField("Phone", text: $store.phone).keyboardType(.phonePad)
                    TextField("Hours", text: $store.hours)
                }
                Section { SwitchSideButton(to: .customer) }
            }
            .navigationTitle("Store")
        }
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title2.bold().monospacedDigit()).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}
