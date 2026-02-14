import Foundation

struct ImportedContact: Identifiable, Hashable, Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let phoneNumber: String
    private let storedCustomFields: [String: String]
    var isSelected: Bool

    var fullName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown" : name
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        let result = "\(first)\(last)"
        return result.isEmpty ? "?" : result
    }

    init(id: UUID = UUID(), firstName: String, lastName: String, phoneNumber: String, customFields: [String: String] = [:], isSelected: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.storedCustomFields = customFields
        self.isSelected = isSelected
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ImportedContact, rhs: ImportedContact) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, phoneNumber, isSelected
        case storedCustomFields = "customFields"
    }
}

protocol ContactRepresentable {
    var fullName: String { get }
    var phoneNumberForSending: String { get }
    var customFields: [String: String] { get }
    var isSelected: Bool { get }
}

extension Contact: ContactRepresentable {
    var phoneNumberForSending: String {
        selectedPhoneNumber?.number ?? ""
    }

    var customFields: [String: String] {
        ["firstName": firstName, "lastName": lastName, "fullName": fullName, "name": fullName]
    }
}

extension ImportedContact: ContactRepresentable {
    var phoneNumberForSending: String { phoneNumber }

    var customFields: [String: String] {
        var fields = storedCustomFields
        fields["firstName"] = firstName
        fields["lastName"] = lastName
        fields["fullName"] = fullName
        fields["name"] = fullName
        return fields
    }
}
