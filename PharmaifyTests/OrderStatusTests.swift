import XCTest
import SwiftData

final class OrderStatusTests: XCTestCase {
    func testPipelineWalksSubmittedToPickedUp() {
        var status = OrderStatus.submitted
        var walked = [status]
        while let next = status.next {
            status = next
            walked.append(status)
        }
        XCTAssertEqual(walked, OrderStatus.pipeline)
        XCTAssertNil(OrderStatus.pickedUp.next)
        XCTAssertNil(OrderStatus.cancelled.next)
    }

    func testOpenStatuses() {
        XCTAssertTrue(OrderStatus.submitted.isOpen)
        XCTAssertTrue(OrderStatus.ready.isOpen)
        XCTAssertFalse(OrderStatus.pickedUp.isOpen)
        XCTAssertFalse(OrderStatus.cancelled.isOpen)
    }

    @MainActor
    func testAdvanceRecordsEventsAndStopsAtPickedUp() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Pharmacy.self, Medication.self, RxOrder.self, OrderEvent.self, DoseReminder.self, configurations: config)
        let context = container.mainContext
        let order = RxOrder(customerName: "Test", customerPhone: "0", medicationName: "Lisinopril 10 mg", quantity: 30)
        context.insert(order)

        XCTAssertEqual(order.advance(), .received)
        XCTAssertEqual(order.advance(), .filling)
        XCTAssertEqual(order.advance(), .ready)
        XCTAssertTrue(order.reached(.filling))
        XCTAssertFalse(order.reached(.pickedUp))
        XCTAssertEqual(order.advance(), .pickedUp)
        XCTAssertNil(order.advance())
        XCTAssertEqual(order.events.count, 4)

        order.cancel()
        XCTAssertEqual(order.status, .pickedUp, "a picked-up order can't be cancelled")
    }

    @MainActor
    func testCancelFromOpenState() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Pharmacy.self, Medication.self, RxOrder.self, OrderEvent.self, DoseReminder.self, configurations: config)
        let order = RxOrder(customerName: "Test", customerPhone: "0", medicationName: "x", quantity: 1)
        container.mainContext.insert(order)
        order.cancel()
        XCTAssertEqual(order.status, .cancelled)
        XCTAssertFalse(order.reached(.submitted))
    }

    @MainActor
    func testSeedCreatesMyPharmacyWithInventoryAndQueue() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Pharmacy.self, Medication.self, RxOrder.self, OrderEvent.self, DoseReminder.self, configurations: config)
        let context = container.mainContext
        Seed.runIfNeeded(context)
        Seed.runIfNeeded(context)
        let pharmacies = try context.fetch(FetchDescriptor<Pharmacy>())
        XCTAssertEqual(pharmacies.count, 3)
        let mine = try XCTUnwrap(pharmacies.first { $0.isMine })
        XCTAssertEqual(mine.medications.count, 12)
        XCTAssertEqual(mine.openOrders.count, 2)
        XCTAssertFalse(mine.lowStock.isEmpty)
    }
}
