import Foundation
import Contacts
import Combine

@MainActor
class ContactsManager: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var filteredContacts: [Contact] = []
    @Published var searchText: String = "" {
        didSet {
            filterContacts()
        }
    }
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let store = CNContactStore()

    var selectedContacts: [Contact] {
        contacts.filter { $0.isSelected }
    }

    var selectedCount: Int {
        selectedContacts.count
    }

    var totalCount: Int {
        contacts.count
    }

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            authorizationStatus = granted ? .authorized : .denied
            if granted {
                await loadContacts()
            }
        } catch {
            errorMessage = "Failed to request contacts access: \(error.localizedDescription)"
            authorizationStatus = .denied
        }
    }

    // MARK: - Load Contacts

    func loadContacts() async {
        isLoading = true
        errorMessage = nil

        do {
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            request.sortOrder = .givenName

            var fetchedContacts: [Contact] = []

            try store.enumerateContacts(with: request) { cnContact, _ in
                let phoneNumbers = cnContact.phoneNumbers.map { phoneNumber in
                    PhoneNumber(
                        label: phoneNumber.label ?? "",
                        number: phoneNumber.value.stringValue
                    )
                }

                // Only include contacts that have at least one phone number
                guard !phoneNumbers.isEmpty else { return }

                let contact = Contact(
                    id: cnContact.identifier,
                    firstName: cnContact.givenName,
                    lastName: cnContact.familyName,
                    phoneNumbers: phoneNumbers
                )

                fetchedContacts.append(contact)
            }

            contacts = fetchedContacts
            filterContacts()
            isLoading = false
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Selection

    func toggleSelection(for contactId: String) {
        if let index = contacts.firstIndex(where: { $0.id == contactId }) {
            contacts[index].isSelected.toggle()
            filterContacts()
        }
    }

    func selectAll() {
        for index in contacts.indices {
            contacts[index].isSelected = true
        }
        filterContacts()
    }

    func deselectAll() {
        for index in contacts.indices {
            contacts[index].isSelected = false
        }
        filterContacts()
    }

    func selectFiltered() {
        let filteredIds = Set(filteredContacts.map { $0.id })
        for index in contacts.indices {
            if filteredIds.contains(contacts[index].id) {
                contacts[index].isSelected = true
            }
        }
        filterContacts()
    }

    func deselectFiltered() {
        let filteredIds = Set(filteredContacts.map { $0.id })
        for index in contacts.indices {
            if filteredIds.contains(contacts[index].id) {
                contacts[index].isSelected = false
            }
        }
        filterContacts()
    }

    // MARK: - Phone Number Selection

    func setSelectedPhoneIndex(for contactId: String, index: Int) {
        if let contactIndex = contacts.firstIndex(where: { $0.id == contactId }) {
            contacts[contactIndex].selectedPhoneIndex = index
            filterContacts()
        }
    }

    // MARK: - Filtering

    private func filterContacts() {
        if searchText.isEmpty {
            filteredContacts = contacts
        } else {
            let query = searchText.lowercased()
            filteredContacts = contacts.filter { contact in
                contact.fullName.lowercased().contains(query) ||
                contact.phoneNumbers.contains { $0.number.contains(query) }
            }
        }
    }
}
