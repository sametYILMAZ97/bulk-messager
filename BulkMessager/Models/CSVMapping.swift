import Foundation

struct CSVMapping: Codable {
    var nameColumnIndex: Int?
    var firstNameColumnIndex: Int?
    var lastNameColumnIndex: Int?
    var phoneColumnIndex: Int
    var customFieldMappings: [Int: String]

    init(phoneColumnIndex: Int, nameColumnIndex: Int? = nil, firstNameColumnIndex: Int? = nil, lastNameColumnIndex: Int? = nil, customFieldMappings: [Int: String] = [:]) {
        self.phoneColumnIndex = phoneColumnIndex
        self.nameColumnIndex = nameColumnIndex
        self.firstNameColumnIndex = firstNameColumnIndex
        self.lastNameColumnIndex = lastNameColumnIndex
        self.customFieldMappings = customFieldMappings
    }

    func isValid() -> Bool {
        guard phoneColumnIndex >= 0 else { return false }
        let hasNameColumn = nameColumnIndex != nil
        let hasFullNameColumns = firstNameColumnIndex != nil && lastNameColumnIndex != nil
        return hasNameColumn || hasFullNameColumns
    }

    func hasNameConflict() -> Bool {
        return nameColumnIndex != nil && (firstNameColumnIndex != nil || lastNameColumnIndex != nil)
    }
}
