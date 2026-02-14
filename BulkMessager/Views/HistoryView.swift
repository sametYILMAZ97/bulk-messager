import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var historyManager: MessageHistoryManager
    @State private var searchText = ""
    @State private var selectedStatus: HistoryStatus?
    @State private var showExportSheet = false
    @State private var expandedEntryId: UUID?

    var filteredHistory: [MessageHistory] {
        historyManager.filterHistory(
            searchText: searchText,
            status: selectedStatus
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Statistics Panel
            statisticsPanel

            Divider()

            // Filter Bar
            filterBar

            Divider()

            // History List
            if filteredHistory.isEmpty {
                emptyStateView
            } else {
                historyListView
            }
        }
        .navigationTitle("Message History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: exportHistory) {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive, action: { historyManager.clearHistory() }) {
                        Label("Clear All History", systemImage: "trash")
                    }
                    Button(action: { historyManager.clearOlderThan(days: 30) }) {
                        Label("Clear History Older Than 30 Days", systemImage: "calendar")
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileExporter(
            isPresented: $showExportSheet,
            document: CSVDocument(content: historyManager.exportToCSV()),
            contentType: .commaSeparatedText,
            defaultFilename: "message_history_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        ) { result in
            // Handle export result if needed
        }
    }

    // MARK: - Statistics Panel

    private var statisticsPanel: some View {
        let stats = historyManager.getStatistics()
        let successRate = historyManager.getSuccessRate()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Messages",
                    value: "\(stats.total)",
                    color: .blue,
                    icon: "envelope.fill"
                )

                StatCard(
                    title: "Sent Successfully",
                    value: "\(stats.sent)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )

                StatCard(
                    title: "Failed Delivery",
                    value: "\(stats.failed)",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )

                StatCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", successRate),
                    color: successRate > 80 ? .green : (successRate > 50 ? .orange : .red),
                    icon: "chart.bar.fill"
                )
            }
            .padding()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 0) {
            // Search
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(8)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Status Filter
            Picker("", selection: $selectedStatus) {
                Text("All").tag(nil as HistoryStatus?)
                Text("Sent").tag(HistoryStatus.sent as HistoryStatus?)
                Text("Failed").tag(HistoryStatus.failed as HistoryStatus?)
                Text("Cancelled").tag(HistoryStatus.cancelled as HistoryStatus?)
            }
            .labelsHidden()
            .frame(width: 120)
            .padding(.trailing, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - History List

    private var historyListView: some View {
        List {
            ForEach(filteredHistory) { entry in
                HistoryEntryRow(
                    entry: entry,
                    isExpanded: expandedEntryId == entry.id,
                    onToggleExpand: {
                        withAnimation {
                            expandedEntryId = expandedEntryId == entry.id ? nil : entry.id
                        }
                    }
                )
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchText.isEmpty ? "No Message History" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                 "Your message history will appear here after sending messages." :
                 "Try adjusting your search or filters.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func exportHistory() {
        showExportSheet = true
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 160)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: MessageHistory
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(spacing: 12) {
                // Status Icon
                Image(systemName: entry.statusIcon)
                    .foregroundColor(Color(entry.statusColor))
                    .font(.title3)

                // Contact Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.recipientName)
                        .font(.body.weight(.medium))
                    Text(entry.recipientPhone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Template Badge
                if let template = entry.templateUsed {
                    Text(template)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }

                // Timestamp
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Expand Button
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Expanded Content
            if isExpanded && !entry.messageContent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Text("Message:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(entry.messageContent)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)

                    if !entry.metadata.isEmpty {
                        Text("Additional Info:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        ForEach(Array(entry.metadata.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key + ":")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(entry.metadata[key] ?? "")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CSV Document

struct CSVDocument: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText]

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(decoding: data, as: UTF8.self)
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}
