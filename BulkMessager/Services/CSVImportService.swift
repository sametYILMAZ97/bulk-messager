import Foundation
import SwiftUI

enum CSVImportError: LocalizedError {
    case fileReadError
    case invalidFormat
    case missingRequiredColumn(String)
    case invalidPhoneNumber(row: Int, phone: String)
    case emptyFile
    case invalidMapping

    var errorDescription: String? {
        switch self {
        case .fileReadError: return "Failed to read CSV file"
        case .invalidFormat: return "Invalid CSV format"
        case .missingRequiredColumn(let column): return "Missing required column: \(column)"
        case .invalidPhoneNumber(let row, let phone): return "Invalid phone number at row \(row): \(phone)"
        case .emptyFile: return "CSV file is empty"
        case .invalidMapping: return "Invalid column mapping"
        }
    }
}

@MainActor
class CSVImportService: ObservableObject {
    @Published var importedContacts: [ImportedContact] = []
    @Published var isImporting: Bool = false
    @Published var errorMessage: String?
    @Published var csvHeaders: [String] = []
    @Published var previewRows: [[String]] = []

    func loadPreview(from url: URL) async throws {
        isImporting = true
        defer { isImporting = false }

        let (rows, headers) = try await parseCSVFile(url)
        csvHeaders = headers
        previewRows = Array(rows.prefix(5))
    }

    func importContacts(from url: URL, mapping: CSVMapping) async throws {
        guard mapping.isValid() else {
            throw CSVImportError.invalidMapping
        }

        isImporting = true
        defer { isImporting = false }

        let (rows, _) = try await parseCSVFile(url)
        var contacts: [ImportedContact] = []

        for (rowIndex, row) in rows.enumerated() {
            guard rowIndex > 0 else { continue }
            guard !row.isEmpty else { continue }

            guard mapping.phoneColumnIndex < row.count else { continue }
            let phone = row[mapping.phoneColumnIndex].trimmingCharacters(in: .whitespaces)
            guard !phone.isEmpty else { continue }

            if !isValidPhoneNumber(phone) {
                throw CSVImportError.invalidPhoneNumber(row: rowIndex + 1, phone: phone)
            }

            var firstName = ""
            var lastName = ""

            if let nameIndex = mapping.nameColumnIndex, nameIndex < row.count {
                let fullName = row[nameIndex].trimmingCharacters(in: .whitespaces)
                let nameParts = fullName.split(separator: " ", maxSplits: 1)
                firstName = nameParts.first.map(String.init) ?? ""
                lastName = nameParts.count > 1 ? String(nameParts[1]) : ""
            } else {
                if let firstIndex = mapping.firstNameColumnIndex, firstIndex < row.count {
                    firstName = row[firstIndex].trimmingCharacters(in: .whitespaces)
                }
                if let lastIndex = mapping.lastNameColumnIndex, lastIndex < row.count {
                    lastName = row[lastIndex].trimmingCharacters(in: .whitespaces)
                }
            }

            var customFields: [String: String] = [:]
            for (columnIndex, fieldName) in mapping.customFieldMappings {
                if columnIndex < row.count {
                    let value = row[columnIndex].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        customFields[fieldName.lowercased()] = value
                    }
                }
            }

            let contact = ImportedContact(
                firstName: firstName,
                lastName: lastName,
                phoneNumber: phone,
                customFields: customFields,
                isSelected: false
            )
            contacts.append(contact)
        }

        importedContacts = contacts
    }

    func parseCSVFile(_ url: URL) async throws -> ([[String]], [String]) {
        guard url.startAccessingSecurityScopedResource() else {
            throw CSVImportError.fileReadError
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)

        guard let content = String(data: data, encoding: .utf8) ??
                            String(data: data, encoding: .utf16) ??
                            String(data: data, encoding: .isoLatin1) else {
            throw CSVImportError.fileReadError
        }

        let delimiter = detectDelimiter(in: content)
        let rows = parseCSVContent(content, delimiter: delimiter)

        guard !rows.isEmpty else {
            throw CSVImportError.emptyFile
        }

        let headers = rows.first ?? []
        return (rows, headers)
    }

    private func detectDelimiter(in content: String) -> String {
        let firstLine = content.split(separator: "\n").first ?? ""
        let commaCount = firstLine.filter { $0 == "," }.count
        let semicolonCount = firstLine.filter { $0 == ";" }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count

        if tabCount > commaCount && tabCount > semicolonCount {
            return "\t"
        } else if semicolonCount > commaCount {
            return ";"
        } else {
            return ","
        }
    }

    private func parseCSVContent(_ content: String, delimiter: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            var i = line.startIndex
            while i < line.endIndex {
                let char = line[i]

                if char == "\"" {
                    if insideQuotes {
                        let nextIndex = line.index(after: i)
                        if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                            currentField.append("\"")
                            i = nextIndex
                        } else {
                            insideQuotes = false
                        }
                    } else {
                        insideQuotes = true
                    }
                } else if String(char) == delimiter && !insideQuotes {
                    currentRow.append(currentField)
                    currentField = ""
                } else {
                    currentField.append(char)
                }

                i = line.index(after: i)
            }

            if !insideQuotes {
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            } else {
                currentField.append("\n")
            }
        }

        return rows
    }

    func discoverCustomFields(headers: [String], mapping: CSVMapping) -> [String] {
        let reservedIndices = Set([
            mapping.nameColumnIndex,
            mapping.firstNameColumnIndex,
            mapping.lastNameColumnIndex,
            mapping.phoneColumnIndex
        ].compactMap { $0 })

        var customFields: [String] = []
        for (index, header) in headers.enumerated() {
            if !reservedIndices.contains(index) {
                let fieldName = header
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: " ", with: "_")
                    .lowercased()
                customFields.append(fieldName)
            }
        }
        return customFields
    }

    private func isValidPhoneNumber(_ phone: String) -> Bool {
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return cleaned.count >= 10 && cleaned.count <= 15
    }

    func toggleSelection(for contactId: UUID) {
        if let index = importedContacts.firstIndex(where: { $0.id == contactId }) {
            importedContacts[index].isSelected.toggle()
        }
    }

    func selectAll() {
        for index in importedContacts.indices {
            importedContacts[index].isSelected = true
        }
    }

    func deselectAll() {
        for index in importedContacts.indices {
            importedContacts[index].isSelected = false
        }
    }

    func clearImported() {
        importedContacts = []
        csvHeaders = []
        previewRows = []
    }
}
