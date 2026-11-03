import SwiftUI
import SwiftData

public struct EnvironmentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDEnvironment.name) private var environments: [SDEnvironment]
    
    @State private var showingAddAlert = false
    @State private var newEnvName = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if environments.isEmpty {
                    ContentUnavailableView(
                        "Немає середовищ",
                        systemImage: "slider.horizontal.3",
                        description: Text("Додайте середовища (Dev, Staging, Prod) для використання змінних {{base_url}}.")
                    )
                } else {
                    ForEach(environments) { env in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(env.name)
                                    .font(.headline)
                                Text("\(env.variables.count) змінних")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if env.isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            for e in environments { e.isSelected = false }
                            env.isSelected = true
                        }
                    }
                    .onDelete(perform: deleteEnv)
                }
            }
            .navigationTitle("Середовища")
            .toolbar {
                Button {
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .alert("Нове середовище", isPresented: $showingAddAlert) {
                TextField("Назва (напр. Development)", text: $newEnvName)
                Button("Створити") {
                    if !newEnvName.isEmpty {
                        let env = SDEnvironment(name: newEnvName, isSelected: environments.isEmpty)
                        // Add sample base_url
                        let variable = SDEnvironmentVariable(key: "base_url", value: "https://jsonplaceholder.typicode.com")
                        variable.environment = env
                        env.variables.append(variable)
                        modelContext.insert(env)
                        newEnvName = ""
                    }
                }
                Button("Скасувати", role: .cancel) {}
            }
        }
    }
    
    private func deleteEnv(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(environments[index])
        }
    }
}
