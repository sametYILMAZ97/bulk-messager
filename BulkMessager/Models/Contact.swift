import Foundation
import Contacts

struct Contact: Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let phoneNumbers: [PhoneNumber]
    var isSelected: Bool = false
    var selectedPhoneIndex: Int = 0

    var fullName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown" : name
    }

    var selectedPhoneNumber: PhoneNumber? {
        guard !phoneNumbers.isEmpty, selectedPhoneIndex < phoneNumbers.count else { return nil }
        return phoneNumbers[selectedPhoneIndex]
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        let result = "\(first)\(last)"
        return result.isEmpty ? "?" : result
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
}

struct PhoneNumber: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let number: String

    var formattedLabel: String {
        switch label {
        case CNLabelPhoneNumberMobile:
            return "Mobile"
        case CNLabelPhoneNumberiPhone:
            return "iPhone"
        case CNLabelHome:
            return "Home"
        case CNLabelWork:
            return "Work"
        case CNLabelPhoneNumberMain:
            return "Main"
        default:
            return label.isEmpty ? "Phone" : label
        }
    }
}
