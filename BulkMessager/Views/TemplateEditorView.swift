import SwiftUI

struct TemplateEditorView: View {
    @EnvironmentObject private var templateManager: TemplateManager
    @State private var selectedTemplate: MessageTemplate?
    @State private var showCreateSheet = false
    @State private var editingTemplate: MessageTemplate?

    var body: some View {
        HSplitView {
            // Template List
            List(selection: $selectedTemplate) {
                ForEach(templateManager.templates) { template in
                    // Custom row view instead of NavigationLink since we handle selection manually
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)
                                Spacer()
                                Text(template.lastModified, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Text(template.content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                Image(systemName: "curlybraces")
                                    .font(.caption2)
                                Text("\(template.variables.count) variables")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle()) // Make entire row tappable
                    }
                    .tag(template) // Important for List selection
                }
                .onDelete(perform: deleteTemplates)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250, maxWidth: 300)
            
            // Detail View
            if let template = selectedTemplate {
                TemplateDetailView(
                    template: template,
                    templateManager: templateManager,
                    onEdit: { editingTemplate = template }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a template")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showCreateSheet = true }) {
                    Label("New Template", systemImage: "plus")
                }
                .help("Create a new message template")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            TemplateEditSheet(
                templateManager: templateManager,
                onSave: { name, content in
                    templateManager.addTemplate(name: name, content: content)
                    showCreateSheet = false
                }
            )
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditSheet(
                templateManager: templateManager,
                existingTemplate: template,
                onSave: { name, content in
                    templateManager.updateTemplate(template, name: name, content: content)
                    editingTemplate = nil
                }
            )
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            let template = templateManager.templates[index]
            templateManager.deleteTemplate(template)
        }
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    let template: MessageTemplate
    let templateManager: TemplateManager
    let onEdit: () -> Void

    @State private var previewContact: String = "John Doe"
    @State private var customFieldValues: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title2.bold())
                    Text("Last modified \(template.lastModified, style: .date) at \(template.lastModified, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .overlay(Divider(), alignment: .bottom)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive, action: {
                        templateManager.deleteTemplate(template)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Template Content Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Content", systemImage: "doc.text")
                            .font(.headline)
                        
                        Text(template.content)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }

                    // Variables Section
                    if !template.variables.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Variables", systemImage: "curlybraces")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(template.variables, id: \.self) { variable in
                                        Text(variable)
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(1) // Avoid clipping shadows/strokes
                            }
                        }
                    }

                    // Preview Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Preview", systemImage: "eye")
                            .font(.headline)
                        
                        GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                if !template.variables.isEmpty {
                                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                                        ForEach(template.variables, id: \.self) { variable in
                                            GridRow {
                                                Text(variable)
                                                    .font(.caption.bold())
                                                    .foregroundColor(.secondary)
                                                    .gridColumnAlignment(.trailing)
                                                
                                                TextField("Value", text: binding(for: variable))
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(maxWidth: 300) 
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Result:")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    
                                    Text(previewMessage())
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func binding(for variable: String) -> Binding<String> {
        Binding(
            get: { customFieldValues[variable.lowercased()] ?? "" },
            set: { customFieldValues[variable.lowercased()] = $0 }
        )
    }

    private func previewMessage() -> String {
        MessageTemplateEngine.substitute(template.content, with: customFieldValues)
    }
}

// MARK: - Template Edit Sheet

struct TemplateEditSheet: View {
    let templateManager: TemplateManager
    let existingTemplate: MessageTemplate?
    let onSave: (String, String) -> Void

    @State private var templateName: String = ""
    @State private var templateContent: String = ""
    @Environment(\.dismiss) private var dismiss

    init(templateManager: TemplateManager, existingTemplate: MessageTemplate? = nil, onSave: @escaping (String, String) -> Void) {
        self.templateManager = templateManager
        self.existingTemplate = existingTemplate
        self.onSave = onSave

        _templateName = State(initialValue: existingTemplate?.name ?? "")
        _templateContent = State(initialValue: existingTemplate?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g., Meeting Reminder", text: $templateName)
                }

                Section("Template Content") {
                    TextEditor(text: $templateContent)
                        .font(.body)
                        .frame(minHeight: 200)
                }

                Section("Available Variables") {
                    Text("Use these placeholders in your message:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                        ForEach(commonVariables, id: \.self) { variable in
                            Button(action: { insertVariable(variable) }) {
                                HStack {
                                    Text("{{\(variable)}}")
                                        .font(.system(.caption, design: .monospaced))
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.caption)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Text("Variables will be replaced with actual values when sending. CSV imports can provide custom variables.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(existingTemplate == nil ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(templateName, templateContent)
                    }
                    .disabled(templateName.isEmpty || templateContent.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 500)
    }

    private let commonVariables = ["name", "firstName", "lastName", "phone", "company", "email", "role"]

    private func insertVariable(_ variable: String) {
        templateContent += "{{\(variable)}}"
    }
}
