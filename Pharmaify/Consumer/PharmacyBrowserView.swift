import SwiftUI
import SwiftData

struct PharmacyBrowserView: View {
    @Query(sort: \Pharmacy.name) private var pharmacies: [Pharmacy]
    @State private var search = ""

    private var results: [Pharmacy] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return pharmacies }
        return pharmacies.filter { p in
            p.name.localizedCaseInsensitiveContains(q) || p.city.localizedCaseInsensitiveContains(q)
                || p.medications.contains { $0.name.localizedCaseInsensitiveContains(q) && $0.stock > 0 }
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { pharmacy in
                NavigationLink { PharmacyDetailView(pharmacy: pharmacy, search: search) } label: {
                    PharmacyRow(pharmacy: pharmacy, search: search)
                }
            }
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .searchable(text: $search, prompt: "Pharmacy, town, or medication")
            .navigationTitle("Pharmacies")
        }
    }
}

struct PharmacyRow: View {
    let pharmacy: Pharmacy
    let search: String

    private var match: Medication? {
        guard !search.isEmpty else { return nil }
        return pharmacy.medications.first { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "cross.case.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.brand.gradient, in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(pharmacy.name).font(.headline)
                Text(pharmacy.city).font(.subheadline).foregroundStyle(.secondary)
                if let match {
                    Text(match.stock > 0 ? "\(match.label) in stock · $\(match.price, specifier: "%.2f")" : "\(match.label) out of stock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(match.stock > 0 ? Color.brand : Color.red)
                } else {
                    Text(pharmacy.hours).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct PharmacyDetailView: View {
    let pharmacy: Pharmacy
    @State var search: String
    @State private var ordering: Medication?
    @State private var showBlankOrder = false

    private var shelf: [Medication] {
        let sorted = pharmacy.medications.sorted { $0.name < $1.name }
        guard !search.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Section {
                Label("\(pharmacy.address), \(pharmacy.city)", systemImage: "mappin.and.ellipse")
                Label(pharmacy.hours, systemImage: "clock")
                if let url = Phone.url(pharmacy.phone) {
                    Link(destination: url) { Label(Phone.display(pharmacy.phone), systemImage: "phone") }
                }
                Button { showBlankOrder = true } label: {
                    Label("Request a refill here", systemImage: "plus.circle.fill")
                }
            }
            Section("On the shelf") {
                ForEach(shelf) { med in
                    Button { ordering = med } label: { ShelfRow(med: med) }
                        .buttonStyle(.plain)
                        .disabled(med.stock == 0)
                }
            }
        }
        .searchable(text: $search, prompt: "Search this pharmacy")
        .navigationTitle(pharmacy.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $ordering) { med in NewOrderView(pharmacy: pharmacy, medicationName: med.label) }
        .sheet(isPresented: $showBlankOrder) { NewOrderView(pharmacy: pharmacy) }
    }
}

struct ShelfRow: View {
    let med: Medication

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(med.label).font(.body.weight(.medium))
                Text(med.requiresPrescription ? "\(med.form) · Rx" : "\(med.form) · over the counter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(med.price, specifier: "%.2f")").font(.body.monospacedDigit())
                Text(med.stock == 0 ? "Out of stock" : med.isLow ? "Low stock" : "In stock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(med.stock == 0 ? Color.red : med.isLow ? Color.orange : Color.brand)
            }
        }
        .contentShape(.rect)
    }
}
