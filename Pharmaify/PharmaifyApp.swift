import SwiftUI
import SwiftData
import UserNotifications

@main
struct PharmaifyApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Pharmacy.self, Medication.self, RxOrder.self, OrderEvent.self, DoseReminder.self)
        } catch {
            fatalError("Pharmaify store failed to open: \(error)")
        }
        UNUserNotificationCenter.current().delegate = Notifier.delegate
        Seed.runIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.brand)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage(AppRole.key) private var roleRaw = ""

    var body: some View {
        Group {
            switch AppRole(rawValue: roleRaw) {
            case .customer: CustomerTabs()
            case .pharmacy: PharmacyTabs()
            case nil: RoleSelectView { roleRaw = $0.rawValue }
            }
        }
        .animation(.smooth, value: roleRaw)
        .task { await Notifier.requestAuthorization() }
    }
}
