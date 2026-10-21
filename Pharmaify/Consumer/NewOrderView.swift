import SwiftUI
import SwiftData
import PhotosUI

struct NewOrderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pharmacy.name) private var pharmacies: [Pharmacy]
    @AppStorage(Profile.nameKey) private var savedName = ""
    @AppStorage(Profile.phoneKey) private var savedPhone = ""

    @State private var pharmacy: Pharmacy?
    @State private var medicationName: String
    @State private var quantity = 30
    @State private var notes = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?

    init(pharmacy: Pharmacy? = nil, medicationName: String = "") {
        _pharmacy = State(initialValue: pharmacy)
        _medicationName = State(initialValue: medicationName)
    }

    private var suggestions: [Medication] {
        guard let pharmacy, !medicationName.isEmpty else { return [] }
        return pharmacy.medications
            .filter { $0.name.localizedCaseInsensitiveContains(medicationName) && $0.label != medicationName }
            .sorted { $0.name < $1.name }
            .prefix(4)
            .map { $0 }
    }

    private var canSend: Bool {
        pharmacy != nil && !medicationName.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty && Phone.digits(phone).count >= 10
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pharmacy") {
                    Picker("Send to", selection: $pharmacy) {
                        Text("Choose…").tag(Pharmacy?.none)
                        ForEach(pharmacies) { p in Text(p.name).tag(Optional(p)) }
                    }
                }
                Section("Medication") {
                    TextField("Name and strength, e.g. Metformin 500 mg", text: $medicationName)
                        .textInputAutocapitalization(.words)
                    ForEach(suggestions) { med in
                        Button { medicationName = med.label } label: {
                            Label(med.label, systemImage: "text.badge.plus")
                        }
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...360, step: quantity < 30 ? 1 : 30)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photo == nil ? "Attach prescription label photo" : "Photo attached", systemImage: photo == nil ? "camera" : "checkmark.circle.fill")
                    }
                    TextField("Notes for the pharmacist", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Your details") {
                    TextField("Full name", text: $name).textContentType(.name)
                    TextField("Mobile number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
            }
            .navigationTitle("Request a refill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: send).disabled(!canSend)
                }
            }
            .onAppear {
                if name.isEmpty { name = savedName }
                if phone.isEmpty { phone = savedPhone }
            }
            .onChange(of: photoItem) { _, item in
                Task { photo = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    private func send() {
        guard let pharmacy else { return }
        savedName = name
        savedPhone = phone
        let order = RxOrder(customerName: name.trimmingCharacters(in: .whitespaces),
                            customerPhone: Phone.digits(phone),
                            medicationName: medicationName.trimmingCharacters(in: .whitespaces),
                            quantity: quantity,
                            notes: notes,
                            photo: photo,
                            pharmacy: pharmacy)
        context.insert(order)
        order.events.append(OrderEvent(status: .submitted))
        try? context.save()
        dismiss()
    }
}
