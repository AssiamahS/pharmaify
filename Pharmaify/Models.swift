import Foundation
import SwiftData

enum AppRole: String {
    case customer, pharmacy
    static let key = "pharmaify.role"
}

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case submitted, received, filling, ready, pickedUp, cancelled

    var id: String { rawValue }

    static let pipeline: [OrderStatus] = [.submitted, .received, .filling, .ready, .pickedUp]

    var title: String {
        switch self {
        case .submitted: "Submitted"
        case .received: "Received"
        case .filling: "Filling"
        case .ready: "Ready for pickup"
        case .pickedUp: "Picked up"
        case .cancelled: "Cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .submitted: "paperplane"
        case .received: "tray.and.arrow.down"
        case .filling: "pills"
        case .ready: "bag.badge.checkmark"
        case .pickedUp: "checkmark.seal"
        case .cancelled: "xmark.circle"
        }
    }

    var next: OrderStatus? {
        switch self {
        case .submitted: .received
        case .received: .filling
        case .filling: .ready
        case .ready: .pickedUp
        case .pickedUp, .cancelled: nil
        }
    }

    var isOpen: Bool { self != .pickedUp && self != .cancelled }

    var rank: Int { OrderStatus.pipeline.firstIndex(of: self) ?? -1 }
}

@Model
final class Pharmacy {
    var name: String
    var address: String
    var city: String
    var phone: String
    var hours: String
    var isMine: Bool
    @Relationship(deleteRule: .cascade, inverse: \Medication.pharmacy) var medications: [Medication] = []
    @Relationship(deleteRule: .cascade, inverse: \RxOrder.pharmacy) var orders: [RxOrder] = []

    init(name: String, address: String, city: String, phone: String, hours: String, isMine: Bool = false) {
        self.name = name
        self.address = address
        self.city = city
        self.phone = phone
        self.hours = hours
        self.isMine = isMine
    }

    var openOrders: [RxOrder] { orders.filter { $0.status.isOpen } }
    var lowStock: [Medication] { medications.filter { $0.isLow } }
}

@Model
final class Medication {
    var name: String
    var strength: String
    var form: String
    var price: Double
    var stock: Int
    var reorderPoint: Int
    var requiresPrescription: Bool
    var pharmacy: Pharmacy?

    init(name: String, strength: String, form: String, price: Double, stock: Int, reorderPoint: Int = 10, requiresPrescription: Bool = true, pharmacy: Pharmacy? = nil) {
        self.name = name
        self.strength = strength
        self.form = form
        self.price = price
        self.stock = stock
        self.reorderPoint = reorderPoint
        self.requiresPrescription = requiresPrescription
        self.pharmacy = pharmacy
    }

    var isLow: Bool { stock <= reorderPoint }
    var label: String { strength.isEmpty ? name : "\(name) \(strength)" }
}

@Model
final class RxOrder {
    var customerName: String
    var customerPhone: String
    var medicationName: String
    var quantity: Int
    var notes: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var refillsRemaining: Int
    @Attribute(.externalStorage) var photo: Data?
    var pharmacy: Pharmacy?
    @Relationship(deleteRule: .cascade, inverse: \OrderEvent.order) var events: [OrderEvent] = []

    init(customerName: String, customerPhone: String, medicationName: String, quantity: Int, notes: String = "", refillsRemaining: Int = 2, photo: Data? = nil, pharmacy: Pharmacy? = nil, createdAt: Date = .now) {
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.medicationName = medicationName
        self.quantity = quantity
        self.notes = notes
        self.statusRaw = OrderStatus.submitted.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.refillsRemaining = refillsRemaining
        self.photo = photo
        self.pharmacy = pharmacy
    }

    var status: OrderStatus {
        get { OrderStatus(rawValue: statusRaw) ?? .submitted }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
            events.append(OrderEvent(status: newValue))
        }
    }

    /// Moves the order one step down the pipeline. Returns the new status, or nil when it can't move.
    @discardableResult
    func advance() -> OrderStatus? {
        guard let next = status.next else { return nil }
        status = next
        return next
    }

    func cancel() {
        guard status.isOpen else { return }
        status = .cancelled
    }

    func reached(_ step: OrderStatus) -> Bool {
        status != .cancelled && status.rank >= step.rank
    }
}

@Model
final class OrderEvent {
    var statusRaw: String
    var at: Date
    var order: RxOrder?

    init(status: OrderStatus, at: Date = .now) {
        self.statusRaw = status.rawValue
        self.at = at
    }

    var status: OrderStatus { OrderStatus(rawValue: statusRaw) ?? .submitted }
}

@Model
final class DoseReminder {
    var medicationName: String
    var dosage: String
    var hour: Int
    var minute: Int
    var isOn: Bool
    var notificationID: String

    init(medicationName: String, dosage: String, hour: Int, minute: Int, isOn: Bool = true) {
        self.medicationName = medicationName
        self.dosage = dosage
        self.hour = hour
        self.minute = minute
        self.isOn = isOn
        self.notificationID = UUID().uuidString
    }

    var timeLabel: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

enum Seed {
    static func runIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Pharmacy>())) ?? 0
        guard count == 0 else { return }

        let mine = Pharmacy(name: "Bayshore Family Pharmacy", address: "726 N Beers St", city: "Holmdel, NJ", phone: "7327390100", hours: "Mon-Fri 9-7 · Sat 9-3", isMine: true)
        let keyport = Pharmacy(name: "Keyport Rx", address: "40 W Front St", city: "Keyport, NJ", phone: "7322640123", hours: "Mon-Sat 9-6")
        let hazlet = Pharmacy(name: "Hazlet Pharmacy & Wellness", address: "3012 NJ-35", city: "Hazlet, NJ", phone: "7328882200", hours: "Daily 8-9")
        for pharmacy in [mine, keyport, hazlet] { context.insert(pharmacy) }

        let catalog: [(String, String, String, Double, Int, Bool)] = [
            ("Lisinopril", "10 mg", "tablet", 9.99, 120, true),
            ("Metformin", "500 mg", "tablet", 7.49, 200, true),
            ("Atorvastatin", "20 mg", "tablet", 12.00, 80, true),
            ("Amoxicillin", "500 mg", "capsule", 14.50, 6, true),
            ("Albuterol", "90 mcg", "inhaler", 32.00, 14, true),
            ("Sertraline", "50 mg", "tablet", 11.25, 45, true),
            ("Omeprazole", "20 mg", "capsule", 8.75, 90, false),
            ("Ibuprofen", "200 mg", "tablet", 5.99, 300, false),
            ("Cetirizine", "10 mg", "tablet", 6.49, 9, false),
            ("Levothyroxine", "50 mcg", "tablet", 10.00, 60, true),
            ("Amlodipine", "5 mg", "tablet", 8.99, 75, true),
            ("Insulin glargine", "100 u/mL", "pen", 98.00, 4, true),
        ]
        for pharmacy in [mine, keyport, hazlet] {
            for (i, item) in catalog.enumerated() {
                let jitter = pharmacy === mine ? 0 : (i * 7) % 23
                let med = Medication(name: item.0, strength: item.1, form: item.2, price: item.3, stock: max(0, item.4 - jitter), requiresPrescription: item.5, pharmacy: pharmacy)
                context.insert(med)
            }
        }

        let sample1 = RxOrder(customerName: "Maria Lopez", customerPhone: "7325550101", medicationName: "Metformin 500 mg", quantity: 60, notes: "Monthly refill", pharmacy: mine, createdAt: .now.addingTimeInterval(-3600 * 5))
        let sample2 = RxOrder(customerName: "James Carter", customerPhone: "7325550144", medicationName: "Albuterol 90 mcg", quantity: 1, notes: "Needs it today if possible", pharmacy: mine, createdAt: .now.addingTimeInterval(-3600 * 1.5))
        context.insert(sample1)
        context.insert(sample2)
        sample1.events.append(OrderEvent(status: .submitted, at: sample1.createdAt))
        sample1.advance()
        sample1.advance()
        sample2.events.append(OrderEvent(status: .submitted, at: sample2.createdAt))
        try? context.save()
    }
}
