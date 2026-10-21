import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var context
    let store: Pharmacy
    @State private var search = ""
    @State private var lowOnly = false
    @State private var editing: Medication?

    private var items: [Medication] {
        store.medications
            .filter { !lowOnly || $0.isLow }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle("Low stock only (\(store.lowStock.count))", isOn: $lowOnly)
                ForEach(items) { med in
                    Button { editing = med } label: { ShelfRow(med: med) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("+30") { med.stock += 30 }.tint(.brand)
                        }
                }
                .onDelete { offsets in
                    let current = items
                    for i in offsets { context.delete(current[i]) }
                }
            }
            .searchable(text: $search, prompt: "Search inventory")
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let med = Medication(name: "", strength: "", form: "tablet", price: 0, stock: 0, pharmacy: store)
                        context.insert(med)
                        editing = med
                    } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(item: $editing, onDismiss: dropBlank) { EditMedicationView(med: $0) }
        }
    }

    private func dropBlank() {
        for med in store.medications where med.name.trimmingCharacters(in: .whitespaces).isEmpty {
            context.delete(med)
        }
        try? context.save()
    }
}

struct EditMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var med: Medication

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $med.name).textInputAutocapitalization(.words)
                    TextField("Strength, e.g. 20 mg", text: $med.strength)
                    TextField("Form", text: $med.form)
                    Toggle("Prescription required", isOn: $med.requiresPrescription)
                }
                Section("Stock") {
                    Stepper("On hand: \(med.stock)", value: $med.stock, in: 0...10_000)
                    Stepper("Reorder at: \(med.reorderPoint)", value: $med.reorderPoint, in: 0...1_000)
                    TextField("Price", value: $med.price, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(med.name.isEmpty ? "New item" : med.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
