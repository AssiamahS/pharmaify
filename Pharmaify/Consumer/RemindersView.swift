import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\DoseReminder.hour), SortDescriptor(\DoseReminder.minute)]) private var reminders: [DoseReminder]
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders) { ReminderRow(reminder: $0) }
                    .onDelete { offsets in
                        for i in offsets {
                            Notifier.cancel(reminders[i])
                            context.delete(reminders[i])
                        }
                        try? context.save()
                    }
            }
            .overlay {
                if reminders.isEmpty {
                    ContentUnavailableView {
                        Label("No dose reminders", systemImage: "alarm")
                    } description: {
                        Text("Get a daily nudge for each medication you take.")
                    } actions: {
                        Button("Add reminder") { adding = true }.buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $adding) { NewReminderView() }
        }
    }
}

struct ReminderRow: View {
    @Bindable var reminder: DoseReminder

    var body: some View {
        Toggle(isOn: $reminder.isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.timeLabel).font(.title2.monospacedDigit().weight(.semibold))
                Text(reminder.dosage.isEmpty ? reminder.medicationName : "\(reminder.medicationName) · \(reminder.dosage)")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: reminder.isOn) { Notifier.sync(reminder) }
    }
}

struct NewReminderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var medication = ""
    @State private var dosage = ""
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                TextField("Medication", text: $medication).textInputAutocapitalization(.words)
                TextField("Dose, e.g. 1 tablet", text: $dosage)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            }
            .navigationTitle("New reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                        let reminder = DoseReminder(medicationName: medication, dosage: dosage, hour: c.hour ?? 8, minute: c.minute ?? 0)
                        context.insert(reminder)
                        try? context.save()
                        Notifier.sync(reminder)
                        dismiss()
                    }
                    .disabled(medication.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
