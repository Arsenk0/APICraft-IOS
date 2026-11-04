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
            Group {
                if environments.isEmpty {
                    ContentUnavailableView(
                        "No Environments",
                        systemImage: "slider.horizontal.3",
                        description: Text("Tap the + button in the top right to create an environment (e.g. Development, Production).")
                    )
                } else {
                    List {
                        Section {
                            ForEach(environments) { env in
                                HStack(spacing: 12) {
                                    // Radio button for activating environment
                                    Button {
                                        for e in environments { e.isSelected = false }
                                        env.isSelected = true
                                        try? modelContext.save()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Image(systemName: env.isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(env.isSelected ? Color.green : Color.secondary.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Row navigates to variables editor
                                    NavigationLink {
                                        EnvironmentDetailView(environment: env)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(env.name)
                                                    .font(.headline)
                                                    .lineLimit(1)
                                                
                                                if env.isSelected {
                                                    Text("Active")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.green.opacity(0.15))
                                                        .foregroundStyle(.green)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            
                                            Text("\(env.variables.count) \(env.variables.count == 1 ? "variable" : "variables")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .onDelete(perform: deleteEnv)
                        } footer: {
                            Text("Tap the circle to activate an environment, or tap the row to view and edit its variables.")
                                .font(.caption2)
                        }
                    }
                }
            }
            .navigationTitle("Environments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newEnvName = ""
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Environment", isPresented: $showingAddAlert) {
                TextField("Name (e.g. Development, Production)", text: $newEnvName)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                
                Button("Create") {
                    createEnvironment()
                }
                
                Button("Cancel", role: .cancel) {
                    newEnvName = ""
                }
            } message: {
                Text("Enter a name for the new environment.")
            }
        }
    }
    
    private func createEnvironment() {
        let trimmed = newEnvName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let isFirst = environments.isEmpty
        let env = SDEnvironment(name: trimmed, isSelected: isFirst)
        
        let defaultURL = trimmed.lowercased().contains("prod") 
            ? "https://api.example.com" 
            : "https://jsonplaceholder.typicode.com"
        let variable = SDEnvironmentVariable(key: "base_url", value: defaultURL)
        variable.environment = env
        env.variables.append(variable)
        
        modelContext.insert(env)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new environment: \(error)")
        }
        newEnvName = ""
    }
    
    private func deleteEnv(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(environments[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Environment Detail View (Variables Editor)
struct EnvironmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEnvironments: [SDEnvironment]
    @Bindable var environment: SDEnvironment
    
    init(environment: SDEnvironment) {
        self.environment = environment
    }
    
    var body: some View {
        Form {
            Section("Environment Info") {
                TextField("Environment Name", text: $environment.name)
                    .font(.body.bold())
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .onChange(of: environment.name) {
                        try? modelContext.save()
                    }
                
                Toggle("Active Environment", isOn: Binding(
                    get: { environment.isSelected },
                    set: { newValue in
                        if newValue {
                            for e in allEnvironments { e.isSelected = false }
                            environment.isSelected = true
                        } else {
                            environment.isSelected = false
                        }
                        try? modelContext.save()
                    }
                ))
                .tint(.green)
            }
            
            Section {
                if environment.variables.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "curlybraces")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Variables Defined")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text("Add variables like base_url, api_token, user_id.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(environment.variables) { variable in
                        @Bindable var bindableVar = variable
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("{{\(variable.key.isEmpty ? "key" : variable.key)}}")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Spacer()
                                Button {
                                    withAnimation {
                                        environment.variables.removeAll(where: { $0.id == variable.id })
                                        modelContext.delete(variable)
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack(spacing: 8) {
                                TextField("Key (e.g. base_url)", text: $bindableVar.key)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                    .onChange(of: bindableVar.key) { try? modelContext.save() }
                                
                                TextField("Value", text: $bindableVar.value)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                    .onChange(of: bindableVar.value) { try? modelContext.save() }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteVariables)
                }
                
                Button {
                    withAnimation {
                        let newVar = SDEnvironmentVariable(key: "new_key", value: "value")
                        newVar.environment = environment
                        environment.variables.append(newVar)
                        modelContext.insert(newVar)
                        try? modelContext.save()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Variable")
                            .bold()
                    }
                    .foregroundStyle(.blue)
                }
            } header: {
                Text("Variables (\(environment.variables.count))")
            } footer: {
                Text("Use {{key}} anywhere in your URLs, Headers, Params, or Body (for example {{base_url}}/todos/1). APICraft will automatically substitute it with this environment's value.")
                    .font(.caption2)
            }
        }
        .navigationTitle(environment.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteVariables(offsets: IndexSet) {
        for index in offsets {
            let v = environment.variables[index]
            modelContext.delete(v)
        }
        environment.variables.remove(atOffsets: offsets)
        try? modelContext.save()
    }
}
