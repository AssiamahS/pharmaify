import SwiftUI

extension Color {
    static let brand = Color(red: 0.078, green: 0.722, blue: 0.620)
    static let brandDeep = Color(red: 0.059, green: 0.463, blue: 0.431)
}

enum Profile {
    static let nameKey = "pharmaify.customer.name"
    static let phoneKey = "pharmaify.customer.phone"
}

enum Phone {
    static func digits(_ raw: String) -> String { raw.filter(\.isNumber) }

    static func display(_ raw: String) -> String {
        let d = digits(raw)
        guard d.count == 10 else { return raw }
        let a = d.prefix(3), b = d.dropFirst(3).prefix(3), c = d.suffix(4)
        return "(\(a)) \(b)-\(c)"
    }

    static func url(_ raw: String) -> URL? { URL(string: "tel:\(digits(raw))") }
}

extension OrderStatus {
    var shortTitle: String {
        switch self {
        case .submitted: "Sent"
        case .received: "Received"
        case .filling: "Filling"
        case .ready: "Ready"
        case .pickedUp: "Done"
        case .cancelled: "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .submitted: .blue
        case .received: .indigo
        case .filling: .orange
        case .ready: .brand
        case .pickedUp: .gray
        case .cancelled: .red
        }
    }

    /// Verb shown on the pharmacy's advance button.
    var actionTitle: String {
        switch self {
        case .received: "Accept"
        case .filling: "Start filling"
        case .ready: "Mark ready"
        case .pickedUp: "Picked up"
        default: title
        }
    }
}

struct StatusPill: View {
    let status: OrderStatus

    var body: some View {
        Label(status.shortTitle, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.14), in: Capsule())
    }
}

struct StatusTracker: View {
    let order: RxOrder

    var body: some View {
        if order.status == .cancelled {
            Label("This request was cancelled", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(OrderStatus.pipeline) { step in
                    let done = order.reached(step)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(done ? Color.brand : Color.secondary.opacity(0.18))
                                .frame(width: 32, height: 32)
                            Image(systemName: step.systemImage)
                                .font(.caption.bold())
                                .foregroundStyle(done ? Color.white : Color.secondary)
                        }
                        Text(step.shortTitle)
                            .font(.caption2.weight(order.status == step ? .bold : .regular))
                            .foregroundStyle(done ? Color.primary : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct OrderTimeline: View {
    let order: RxOrder

    var body: some View {
        ForEach(order.events.sorted { $0.at < $1.at }) { event in
            HStack {
                Image(systemName: event.status.systemImage)
                    .foregroundStyle(event.status.color)
                    .frame(width: 24)
                Text(event.status.title)
                Spacer()
                Text(event.at.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RoleSelectView: View {
    let choose: (AppRole) -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [.brandDeep, .brand], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "pills.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                VStack(spacing: 8) {
                    Text("Pharmaify")
                        .font(.largeTitle.bold())
                    Text("Refills without the phone tag.")
                        .font(.title3)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                Spacer()
                VStack(spacing: 14) {
                    roleCard(.customer, title: "I need a refill", subtitle: "Order from a local pharmacy and track it to pickup.", icon: "person.fill")
                    roleCard(.pharmacy, title: "I run a pharmacy", subtitle: "Work the refill queue and keep stock in check.", icon: "cross.case.fill")
                }
                Text("You can switch sides any time.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
        }
    }

    private func roleCard(_ role: AppRole, title: String, subtitle: String, icon: String) -> some View {
        Button { choose(role) } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

struct SwitchSideButton: View {
    @AppStorage(AppRole.key) private var roleRaw = ""
    let to: AppRole

    var body: some View {
        Button {
            roleRaw = to.rawValue
        } label: {
            Label(to == .pharmacy ? "Switch to pharmacy side" : "Switch to customer side",
                  systemImage: "arrow.left.arrow.right")
        }
    }
}
