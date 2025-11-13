import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: AppStore
    @State private var date = Date()

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select", selection: $date, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()

                List {
                    ForEach(store.tasks.filter { Calendar.current.isDate($0.dueAt, inSameDayAs: date) }) { task in
                        HStack {
                            Image(systemName: task.type == .turn ? "arrow.2.circlepath" : "bell")
                            Text(task.type.title)
                            Spacer()
                            Text(task.status == .done ? "Done" : "Pending")
                                .foregroundColor(task.status == .done ? .green : .orange)
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarView()
}
