import SwiftUI

struct ContentView: View {
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var messageSender = MessageSender()
    @StateObject private var csvImportService = CSVImportService()
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var historyManager = MessageHistoryManager()
    @State private var messageText: String = "Hey! I changed my phone number. My new number is: [YOUR NEW NUMBER]. Please save it! 😊"
    @State private var showSendConfirmation: Bool = false
    @State private var selectedTab: Tab? = .contacts
    @State private var selectedTemplate: MessageTemplate?

    enum Tab: String, CaseIterable {
        case contacts = "Contacts"
        case imported = "Imported"
        case selected = "Selected"
        case templates = "Templates"
        case send = "Send"
        case results = "Results"
        case history = "History"
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Manage") {
                    NavigationLink(value: Tab.contacts) {
                        Label("Contacts", systemImage: "person.2")
                    }
                    NavigationLink(value: Tab.imported) {
                        Label("Imported", systemImage: "doc.text")
                    }
                    NavigationLink(value: Tab.selected) {
                        Label("Selected", systemImage: "checkmark.circle")
                    }
                    NavigationLink(value: Tab.templates) {
                        Label("Templates", systemImage: "text.badge.star")
                    }
                }
                
                Section("Actions") {
                    NavigationLink(value: Tab.send) {
                        Label("Compose & Send", systemImage: "paperplane")
                    }
                    NavigationLink(value: Tab.results) {
                        Label("Results", systemImage: "list.bullet.clipboard")
                    }
                    NavigationLink(value: Tab.history) {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("BulkMessager")
        } detail: {
            if let tab = selectedTab {
                switch tab {
                case .contacts:
                    contactsListView
                case .imported:
                    importedContactsView
                case .selected:
                    selectedContactsView
                case .templates:
                    templatesView
                case .send:
                    composeView
                case .results:
                    resultsView
                case .history:
                    historyView
                }
            } else {
                Text("Select a tab")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(selectedTab?.rawValue ?? "")
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            Task {
                if contactsManager.authorizationStatus == .notDetermined {
                    await contactsManager.requestAccess()
                } else if contactsManager.authorizationStatus == .authorized {
                    await contactsManager.loadContacts()
                }
            }
        }
    }

    // MARK: - Navigation Helpers

    private func iconForTab(_ tab: Tab) -> String {
        switch tab {
        case .contacts: return "person.2"
        case .imported: return "doc.text"
        case .selected: return "checkmark.circle"
        case .templates: return "text.badge.star"
        case .send: return "paperplane"
        case .results: return "list.bullet.clipboard"
        case .history: return "clock.arrow.circlepath"
        }
    }

    // MARK: - Contacts List View

    private var contactsListView: some View {
        VStack(spacing: 0) {
            if contactsManager.authorizationStatus != .authorized {
                authorizationView
            } else {
                List {
                    if contactsManager.isLoading {
                        ProgressView("Loading contacts…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                    } else if contactsManager.filteredContacts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(contactsManager.searchText.isEmpty ? "No contacts found" : "No matches")
                                .font(.title2.bold())
                            if contactsManager.searchText.isEmpty {
                                Text("Contacts with phone numbers will appear here.")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Try adjusting your search query.")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                    } else {
                        ForEach(contactsManager.filteredContacts) { contact in
                            ContactRow(
                                contact: contact,
                                onToggle: {
                                    contactsManager.toggleSelection(for: contact.id)
                                },
                                onPhoneSelected: { index in
                                    contactsManager.setSelectedPhoneIndex(for: contact.id, index: index)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowSeparator(.visible)
                        }
                    }
                }
                .listStyle(.inset)
                .searchable(text: $contactsManager.searchText, prompt: "Search contacts")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Select All") { contactsManager.selectAll() }
                            Button("Deselect All") { contactsManager.deselectAll() }
                            Divider()
                            Button("Select Filtered") { contactsManager.selectFiltered() }
                            Button("Deselect Filtered") { contactsManager.deselectFiltered() }
                            Divider()
                            Button(action: { Task { await contactsManager.loadContacts() } }) {
                                Label("Refresh Contacts", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                    }

                    ToolbarItem(placement: .status) {
                        Text("\(contactsManager.selectedCount) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Authorization View

    private var authorizationView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Contacts Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This app needs access to your contacts to display phone numbers for messaging.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if contactsManager.authorizationStatus == .denied || contactsManager.authorizationStatus == .restricted {
                Text("Please grant access in System Settings > Privacy & Security > Contacts")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Grant Access") {
                    Task {
                        await contactsManager.requestAccess()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Selected Contacts View

    private var selectedContactsView: some View {
        VStack(spacing: 0) {
            let allSelectedContacts = contactsManager.selectedContacts.count + csvImportService.importedContacts.filter { $0.isSelected }.count

            if allSelectedContacts == 0 {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.badge.xmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No contacts selected")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Button("Go to Contacts") {
                        selectedTab = .contacts
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // System Contacts
                    if !contactsManager.selectedContacts.isEmpty {
                        Section("System Contacts") {
                            ForEach(contactsManager.selectedContacts) { contact in
                                systemContactRow(contact)
                            }
                        }
                    }

                    // Imported Contacts
                    if !csvImportService.importedContacts.filter({ $0.isSelected }).isEmpty {
                        Section("Imported Contacts") {
                            ForEach(csvImportService.importedContacts.filter { $0.isSelected }) { contact in
                                importedContactRow(contact)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Deselect All") {
                            contactsManager.deselectAll()
                            csvImportService.deselectAll()
                        }
                    }
                    ToolbarItem(placement: .status) {
                        Text("\(allSelectedContacts) contacts selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }

                // Bottom action bar
                HStack {
                    Spacer()
                    Button(action: { selectedTab = .send }) {
                        Label("Next: Compose Message", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Helper Row Functions

    private func systemContactRow(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(contact.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.headline)
                if let phone = contact.selectedPhoneNumber {
                    Text(phone.number)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                contactsManager.toggleSelection(for: contact.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func importedContactRow(_ contact: ImportedContact) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(contact.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.headline)
                Text(contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "doc.text")
                .foregroundColor(.orange)
                .font(.caption)

            Button(action: {
                csvImportService.toggleSelection(for: contact.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Imported Contacts View

    private var importedContactsView: some View {
        CSVImportView()
            .environmentObject(csvImportService)
    }

    // MARK: - Templates View

    private var templatesView: some View {
        TemplateEditorView()
            .environmentObject(templateManager)
    }

    // MARK: - History View

    private var historyView: some View {
        HistoryView()
            .environmentObject(historyManager)
    }

    // MARK: - Compose View

    private var composeView: some View {
        let totalSelectedCount = contactsManager.selectedCount + csvImportService.importedContacts.filter { $0.isSelected }.count

        return Form {
            Section("Recipients") {
                HStack {
                    Label("\(totalSelectedCount) contacts selected", systemImage: "person.2.fill")
                    Spacer()
                    Button("Edit Recipients") {
                        selectedTab = .selected
                    }
                    .buttonStyle(.link)
                }
            }

            Section("Template") {
                Picker("Select Template", selection: $selectedTemplate) {
                    Text("None (Custom Message)").tag(nil as MessageTemplate?)
                    ForEach(templateManager.templates) { template in
                        Text(template.name).tag(template as MessageTemplate?)
                    }
                }
                .onChange(of: selectedTemplate) { _, newTemplate in
                    if let template = newTemplate {
                        messageText = template.content
                    }
                }

                if selectedTemplate != nil {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Variables like {{name}}, {{company}} will be automatically replaced for each contact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Message Content") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $messageText)
                        .font(.body)
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))

                    HStack {
                        Text("\(messageText.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()

                        if selectedTemplate != nil {
                            Button("Edit Template") {
                                selectedTab = .templates
                            }
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 4)

                if messageText.contains("[YOUR NEW NUMBER]") {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Update Placeholder")
                                .font(.headline)
                            Text("Replace [YOUR NEW NUMBER] with your actual number.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Section("Preview") {
                if MessageTemplateEngine.extractVariables(from: messageText).isEmpty {
                    // Simple preview without variables
                    HStack {
                        Spacer()
                        Text(messageText.isEmpty ? "Message preview..." : messageText)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .frame(maxWidth: 300, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                } else {
                    // Preview with variables for first contact
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview with first contact:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let firstContact = contactsManager.selectedContacts.first {
                            let preview = MessageTemplateEngine.substitute(messageText, with: firstContact.customFields)
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(firstContact.fullName)
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(preview)
                                        .padding(12)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                        .frame(maxWidth: 300, alignment: .trailing)
                                }
                            }
                        } else if let firstImported = csvImportService.importedContacts.first(where: { $0.isSelected }) {
                            let preview = MessageTemplateEngine.substitute(messageText, with: firstImported.customFields)
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(firstImported.fullName)
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(preview)
                                        .padding(12)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                        .frame(maxWidth: 300, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section("Settings") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Delay: \(messageSender.delayBetweenMessages, specifier: "%.1f")s")
                        Slider(value: $messageSender.delayBetweenMessages, in: 0.5...5.0, step: 0.5)
                    }
                    Text("Higher delay reduces risk of being flagged as spam.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: { showSendConfirmation = true }) {
                    HStack {
                        Spacer()
                        Label("Send Messages", systemImage: "paperplane.fill")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(totalSelectedCount == 0 || messageText.isEmpty || messageSender.isSending)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Confirm Sending", isPresented: $showSendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Send") {
                selectedTab = .results
                Task {
                    await sendMessagesToAllSelectedContacts()
                }
            }
        } message: {
            Text("Ready to send to \(totalSelectedCount) contacts?\n\nMessages will be sent via iMessage or SMS automatically.")
        }
    }

    // MARK: - Send Messages Helper

    private func sendMessagesToAllSelectedContacts() async {
        // Combine system and imported contacts
        var allContactsToSend: [(name: String, phone: String, fields: [String: String])] = []

        // Add system contacts
        for contact in contactsManager.selectedContacts {
            if let phone = contact.selectedPhoneNumber {
                allContactsToSend.append((
                    name: contact.fullName,
                    phone: phone.number,
                    fields: contact.customFields
                ))
            }
        }

        // Add imported contacts
        for contact in csvImportService.importedContacts.filter({ $0.isSelected }) {
            allContactsToSend.append((
                name: contact.fullName,
                phone: contact.phoneNumber,
                fields: contact.customFields
            ))
        }

        // Send messages with template substitution
        await messageSender.sendMessagesWithTemplates(
            to: allContactsToSend,
            template: messageText,
            templateName: selectedTemplate?.name
        )

        // Save to history
        for result in messageSender.results {
            let status: HistoryStatus = result.status.isSuccess ? .sent : (result.status.isFailed ? .failed : .cancelled)
            let messageContent = MessageTemplateEngine.substitute(messageText, with: result.contact.customFields)

            let historyEntry = MessageHistory(
                recipientName: result.contact.fullName,
                recipientPhone: result.phoneNumber,
                messageContent: messageContent,
                status: status,
                templateUsed: selectedTemplate?.name
            )
            historyManager.addHistory(historyEntry)
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            if messageSender.results.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No messages sent yet")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Button("Start Composing") {
                        selectedTab = .send
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Header with Progress
                VStack(spacing: 16) {
                    if messageSender.isSending {
                        VStack(spacing: 8) {
                            ProgressView(value: messageSender.progress)
                                .progressViewStyle(.linear)
                            Text("Sending... \(Int(messageSender.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 32) {
                        summaryBadge(count: messageSender.summary.sent, label: "Sent", color: .green)
                        summaryBadge(count: messageSender.summary.failed, label: "Failed", color: .red)
                        summaryBadge(count: messageSender.summary.pending, label: "Pending", color: .orange)

                        Divider()
                            .frame(height: 30)

                        if messageSender.isSending {
                            Button("Cancel Sending") {
                                messageSender.cancel()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        } else {
                            if messageSender.summary.failed > 0 {
                                Button("Retry Failed") {
                                    Task {
                                        await messageSender.retryFailed(message: messageText)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Button("Clear Results") {
                                messageSender.reset()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.1)), alignment: .bottom)

                // Results List
                List {
                    ForEach(messageSender.results) { result in
                        HStack(spacing: 12) {
                            Image(systemName: result.status.iconName)
                                .foregroundColor(colorForStatus(result.status))
                                .font(.title3)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.contact.fullName)
                                    .font(.headline)
                                Text(result.phoneNumber)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if case .failed(let reason) = result.status {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            Text(result.status.description)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colorForStatus(result.status).opacity(0.1))
                                .foregroundColor(colorForStatus(result.status))
                                .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Helpers

    private func summaryBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func colorForStatus(_ status: SendStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .sending: return .blue
        case .sent: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: Contact
    let onToggle: () -> Void
    let onPhoneSelected: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: contact.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(contact.isSelected ? .accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Avatar
            ZStack {
                Circle()
                    .fill(contact.isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(contact.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(contact.isSelected ? .accentColor : .secondary)
            }

            // Name and phone
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.headline)
                    .foregroundColor(.primary)

                if contact.phoneNumbers.count == 1 {
                    if let phone = contact.phoneNumbers.first {
                        Text("\(phone.formattedLabel): \(phone.number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Phone number picker (if multiple)
            if contact.phoneNumbers.count > 1 {
                Picker("", selection: Binding(
                    get: { contact.selectedPhoneIndex },
                    set: { onPhoneSelected($0) }
                )) {
                    ForEach(Array(contact.phoneNumbers.enumerated()), id: \.offset) { index, phone in
                        Text("\(phone.formattedLabel): \(phone.number)")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

#Preview {
    ContentView()
}
