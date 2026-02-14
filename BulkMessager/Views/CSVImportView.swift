import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @EnvironmentObject private var csvImportService: CSVImportService
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var mapping = CSVMapping(phoneColumnIndex: 0)
    @State private var showMappingSheet = false
    @State private var showSuccessAlert = false
    @State private var customFieldMappings: [(index: Int, name: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            if csvImportService.importedContacts.isEmpty {
                emptyStateView
            } else {
                importedContactsList
            }
        }
        .navigationTitle("Import Contacts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showFilePicker = true }) {
                    Label("Import CSV", systemImage: "doc.badge.plus")
                }
            }

            if !csvImportService.importedContacts.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Select All") { csvImportService.selectAll() }
                        Button("Deselect All") { csvImportService.deselectAll() }
                        Divider()
                        Button(role: .destructive, action: { csvImportService.clearImported() }) {
                            Label("Clear Imported", systemImage: "trash")
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, UTType(filenameExtension: "csv")!],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showMappingSheet) {
            if let url = selectedFileURL {
                MappingConfigurationView(
                    csvService: csvImportService,
                    fileURL: url,
                    onComplete: handleImportComplete
                )
            }
        }
        .alert("Import Successful", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully imported \(csvImportService.importedContacts.count) contacts")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Imported Contacts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Import contacts from a CSV file to use custom fields and variable substitution in your messages.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Button(action: { showFilePicker = true }) {
                Label("Import CSV File", systemImage: "doc.badge.plus")
            }
            .controlSize(.large)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Imported Contacts List

    private var importedContactsList: some View {
        List {
            Section {
                ForEach(csvImportService.importedContacts) { contact in
                    ImportedContactRow(
                        contact: contact,
                        onToggle: { csvImportService.toggleSelection(for: contact.id) }
                    )
                }
            } header: {
                HStack {
                    Text("\(csvImportService.importedContacts.count) contacts")
                    Spacer()
                    Text("\(csvImportService.importedContacts.filter { $0.isSelected }.count) selected")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .padding(.vertical, 4)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            Task {
                do {
                    try await csvImportService.loadPreview(from: url)
                    showMappingSheet = true
                } catch {
                    csvImportService.errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            csvImportService.errorMessage = error.localizedDescription
        }
    }

    private func handleImportComplete() {
        showMappingSheet = false
        showSuccessAlert = true
    }
}

// MARK: - Mapping Configuration View

struct MappingConfigurationView: View {
    @ObservedObject var csvService: CSVImportService
    let fileURL: URL
    let onComplete: () -> Void

    @State private var phoneColumnIndex: Int = 0
    @State private var nameColumnIndex: Int?
    @State private var firstNameColumnIndex: Int?
    @State private var lastNameColumnIndex: Int?
    @State private var useFullName: Bool = true
    @State private var customFieldMappings: [Int: String] = [:]
    @State private var isImporting = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // CSV Preview Header
                if !csvService.previewRows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("CSV Preview", systemImage: "eye.square")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                                // Header Row
                                GridRow {
                                    ForEach(csvService.csvHeaders.indices, id: \.self) { index in
                                        Text(csvService.csvHeaders[index])
                                            .font(.caption.bold())
                                            .padding(6)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Divider()
                                
                                // Data Rows
                                ForEach(csvService.previewRows.prefix(5).indices, id: \.self) { rowIndex in
                                    GridRow {
                                        ForEach(csvService.previewRows[rowIndex].indices, id: \.self) { colIndex in
                                            Text(csvService.previewRows[rowIndex][colIndex])
                                                .font(.caption)
                                                .padding(6)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 150)
                        
                        Divider()
                    }
                    .padding(.vertical)
                    .background(Color(nsColor: .windowBackgroundColor))
                }

                Form {
                    Section("Required Mapping") {
                        Picker("Phone Number", selection: $phoneColumnIndex) {
                            ForEach(csvService.csvHeaders.indices, id: \.self) { index in
                                Text(csvService.csvHeaders[index]).tag(index)
                            }
                        }

                        Toggle("Use Full Name Column", isOn: $useFullName)

                        if useFullName {
                            Picker("Full Name", selection: $nameColumnIndex) {
                                Text("None").tag(nil as Int?)
                                ForEach(csvService.csvHeaders.indices, id: \.self) { index in
                                    Text(csvService.csvHeaders[index]).tag(index as Int?)
                                }
                            }
                        } else {
                            Picker("First Name", selection: $firstNameColumnIndex) {
                                Text("None").tag(nil as Int?)
                                ForEach(csvService.csvHeaders.indices, id: \.self) { index in
                                    Text(csvService.csvHeaders[index]).tag(index as Int?)
                                }
                            }

                            Picker("Last Name", selection: $lastNameColumnIndex) {
                                Text("None").tag(nil as Int?)
                                ForEach(csvService.csvHeaders.indices, id: \.self) { index in
                                    Text(csvService.csvHeaders[index]).tag(index as Int?)
                                }
                            }
                        }
                    }

                    Section("Custom Fields (Variables)") {
                        ForEach(csvService.csvHeaders.indices, id: \.self) { index in
                            if !isReservedColumn(index) {
                                LabeledContent(csvService.csvHeaders[index]) {
                                    TextField("Variable name", text: binding(for: index))
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .formStyle(.grouped)
            }
            .navigationTitle("Map Columns")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valid & Import") {
                        performImport()
                    }
                    .disabled(isImporting)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func isReservedColumn(_ index: Int) -> Bool {
        return index == phoneColumnIndex ||
               index == nameColumnIndex ||
               index == firstNameColumnIndex ||
               index == lastNameColumnIndex
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { customFieldMappings[index] ?? suggestFieldName(for: index) },
            set: { customFieldMappings[index] = $0 }
        )
    }

    private func suggestFieldName(for index: Int) -> String {
        csvService.csvHeaders[index]
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
    }

    private func performImport() {
        let mapping = CSVMapping(
            phoneColumnIndex: phoneColumnIndex,
            nameColumnIndex: useFullName ? nameColumnIndex : nil,
            firstNameColumnIndex: useFullName ? nil : firstNameColumnIndex,
            lastNameColumnIndex: useFullName ? nil : lastNameColumnIndex,
            customFieldMappings: customFieldMappings
        )

        guard mapping.isValid() else {
            errorMessage = "Please select required columns (phone and name)"
            return
        }

        isImporting = true
        Task {
            do {
                try await csvService.importContacts(from: fileURL, mapping: mapping)
                await MainActor.run {
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Imported Contact Row

struct ImportedContactRow: View {
    let contact: ImportedContact
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: contact.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(contact.isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(contact.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !contact.customFields.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(contact.customFields.keys.prefix(3)), id: \.self) { key in
                            Text(key)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "doc.text")
                .foregroundColor(.orange)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
