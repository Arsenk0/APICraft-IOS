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
                        "No Environments",
                        systemImage: "slider.horizontal.3",
                        description: Text("Add environments (e.g. Development, Staging, Production) to switch dynamic variables like {{base_url}}.")
                    )
                } else {
                    ForEach(environments) { env in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(env.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text("\(env.variables.count) \(env.variables.count == 1 ? "variable" : "variables")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if env.isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            for e in environments { e.isSelected = false }
                            env.isSelected = true
                            try? modelContext.save()
                        }
                    }
                    .onDelete(perform: deleteEnv)
                }
            }
            .navigationTitle("Environments")
            .toolbar {
                Button {
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .alert("New Environment", isPresented: $showingAddAlert) {
                TextField("Name (e.g. Development)", text: $newEnvName)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                Button("Create") {
                    let trimmed = newEnvName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let env = SDEnvironment(name: trimmed, isSelected: environments.isEmpty)
                        let variable = SDEnvironmentVariable(key: "base_url", value: "https://jsonplaceholder.typicode.com")
                        variable.environment = env
                        env.variables.append(variable)
                        modelContext.insert(env)
                        try? modelContext.save()
                        newEnvName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newEnvName = ""
                }
            }
        }
    }
    
    private func deleteEnv(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(environments[index])
        }
        try? modelContext.save()
    }
}
