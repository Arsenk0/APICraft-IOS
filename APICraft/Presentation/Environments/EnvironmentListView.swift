import SwiftUI
import SwiftData

public struct EnvironmentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDEnvironment.name) private var environments: [SDEnvironment]
    
    @State private var showingAddAlert = false
    @State private var newEnvName = ""
    @State private var environmentToEdit: SDEnvironment?
    
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
                                        activateEnvironment(env)
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteSingleEnv(env)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        environmentToEdit = env
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        activateEnvironment(env)
                                    } label: {
                                        Label(env.isSelected ? "Active" : "Activate", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                                .contextMenu {
                                    Button {
                                        environmentToEdit = env
                                    } label: {
                                        Label("Edit Environment", systemImage: "pencil")
                                    }
                                    
                                    Button {
                                        activateEnvironment(env)
                                    } label: {
                                        Label(env.isSelected ? "Deactivate" : "Set as Active", systemImage: env.isSelected ? "checkmark.circle.fill" : "checkmark.circle")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        deleteSingleEnv(env)
                                    } label: {
                                        Label("Delete Environment", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete(perform: deleteEnv)
                        } footer: {
                            Text("Tap the circle or swipe right to activate. Swipe left to edit or delete.")
                                .font(.caption2)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Environments")
            .sheet(item: $environmentToEdit) { env in
                EditEnvironmentSheet(environment: env)
            }
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
                    .textInputAutocapitalization(.never)
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
    
    private func activateEnvironment(_ env: SDEnvironment) {
        if env.isSelected {
            env.isSelected = false
        } else {
            for e in environments { e.isSelected = false }
            env.isSelected = true
        }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Failed to save new environment: \(error)")
        }
        newEnvName = ""
    }
    
    private func deleteSingleEnv(_ env: SDEnvironment) {
        modelContext.delete(env)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func deleteEnv(offsets: IndexSet) {
        for index in offsets {
            if environments.indices.contains(index) {
                modelContext.delete(environments[index])
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Edit Environment Sheet
struct EditEnvironmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allEnvironments: [SDEnvironment]
    let environment: SDEnvironment
    
    @State private var name: String
    @State private var isActive: Bool
    
    init(environment: SDEnvironment) {
        self.environment = environment
        _name = State(initialValue: environment.name)
        _isActive = State(initialValue: environment.isSelected)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Environment Details") {
                    TextField("Environment Name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    
                    Toggle("Active Environment", isOn: $isActive)
                        .tint(.green)
                }
            }
            .navigationTitle("Edit Environment")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            environment.name = trimmed
                        }
                        if isActive {
                            for e in allEnvironments { e.isSelected = false }
                            environment.isSelected = true
                        } else if environment.isSelected && !isActive {
                            environment.isSelected = false
                        }
                        try? modelContext.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.headline)
                }
            }
        }
    }
}

// MARK: - Environment Detail View (Variables Editor)
struct EnvironmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEnvironments: [SDEnvironment]
    @Bindable var environment: SDEnvironment
    @State private var showingEditSheet = false
    
    init(environment: SDEnvironment) {
        self.environment = environment
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(environment.name)
                            .font(.title3.bold())
                            .lineLimit(2)
                        Spacer()
                        if environment.isSelected {
                            Text("Active")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(environment.variables.count) \(environment.variables.count == 1 ? "variable" : "variables") defined")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditEnvironmentSheet(environment: environment)
        }
    }
    
    private func deleteVariables(offsets: IndexSet) {
        for index in offsets {
            if environment.variables.indices.contains(index) {
                let v = environment.variables[index]
                modelContext.delete(v)
            }
        }
        environment.variables.remove(atOffsets: offsets)
        try? modelContext.save()
    }
}
