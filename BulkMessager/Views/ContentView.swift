import SwiftUI

struct ContentView: View {
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var messageSender = MessageSender()
    @State private var messageText: String = "Hey! I changed my phone number. My new number is: [YOUR NEW NUMBER]. Please save it! 😊"
    @State private var showSendConfirmation: Bool = false
    @State private var selectedTab: Tab? = .contacts

    enum Tab: String, CaseIterable {
        case contacts = "Contacts"
        case selected = "Selected"
        case send = "Send"
        case results = "Results"
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: iconForTab(tab))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("BulkMessager")
        } detail: {
            if let tab = selectedTab {
                switch tab {
                case .contacts:
                    contactsListView
                case .selected:
                    selectedContactsView
                case .send:
                    composeView
                case .results:
                    resultsView
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
        case .selected: return "checkmark.circle"
        case .send: return "paperplane"
        case .results: return "list.bullet.clipboard"
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
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text(contactsManager.searchText.isEmpty ? "No contacts with phone numbers found" : "No contacts match your search")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
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
            if contactsManager.selectedContacts.isEmpty {
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
                    ForEach(contactsManager.selectedContacts) { contact in
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
                }
                .listStyle(.inset)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Deselect All") {
                            contactsManager.deselectAll()
                        }
                    }
                    ToolbarItem(placement: .status) {
                        Text("\(contactsManager.selectedCount) contacts selected")
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

    // MARK: - Compose View

    private var composeView: some View {
        Form {
            Section("Recipients") {
                HStack {
                    Label("\(contactsManager.selectedCount) contacts selected", systemImage: "person.2.fill")
                    Spacer()
                    Button("Edit Recipients") {
                        selectedTab = .selected
                    }
                    .buttonStyle(.link)
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
                        Button("Reset Template") {
                            messageText = "Hey! I changed my phone number. My new number is: [YOUR NEW NUMBER]. Please save it! 😊"
                        }
                        .controlSize(.small)
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
                .disabled(contactsManager.selectedCount == 0 || messageText.isEmpty || messageSender.isSending)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Confirm Sending", isPresented: $showSendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Send") {
                selectedTab = .results
                Task {
                    await messageSender.sendMessages(
                        to: contactsManager.selectedContacts,
                        message: messageText
                    )
                }
            }
        } message: {
            Text("Ready to send to \(contactsManager.selectedCount) contacts?\n\nMessages will be sent via iMessage or SMS automatically.")
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
