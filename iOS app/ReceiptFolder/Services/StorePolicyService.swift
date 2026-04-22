import Foundation

@MainActor @Observable
final class StorePolicyService {
    static let shared = StorePolicyService()

    private var bundledPolicies: [StorePolicy] = []
    private(set) var customPolicies: [StorePolicy] = []

    nonisolated private static let customPoliciesKey = "customStorePolicies"
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private init() {
        loadBundledPolicies()
        loadCustomPolicies()
        observeCloudChanges()
    }

    private func loadBundledPolicies() {
        guard let url = Bundle.main.url(forResource: "StorePolicies", withExtension: "json") else {
            RFLogger.policy.error("StorePolicies.json not found in bundle")
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            RFLogger.policy.error("Failed to read StorePolicies.json: \(error)")
            return
        }

        do {
            let database = try JSONDecoder().decode(StorePolicyDatabase.self, from: data)
            bundledPolicies = database.stores
        } catch {
            RFLogger.policy.error("Failed to decode StorePolicies.json: \(error)")
        }
    }

    // MARK: - Custom Policy Persistence (iCloud + local fallback)

    private func loadCustomPolicies() {
        // Try iCloud first, fall back to local UserDefaults
        if let cloudData = cloudStore.data(forKey: Self.customPoliciesKey) {
            do {
                customPolicies = try JSONDecoder().decode([StorePolicy].self, from: cloudData)
                // Sync to local as cache
                UserDefaults.standard.set(cloudData, forKey: Self.customPoliciesKey)
                return
            } catch {
                RFLogger.policy.error("Failed to decode cloud custom policies: \(error)")
            }
        }

        // Fallback to local
        guard let data = UserDefaults.standard.data(forKey: Self.customPoliciesKey) else { return }
        do {
            customPolicies = try JSONDecoder().decode([StorePolicy].self, from: data)
            // Push local data to cloud
            cloudStore.set(data, forKey: Self.customPoliciesKey)
            cloudStore.synchronize()
        } catch {
            RFLogger.policy.error("Failed to decode custom policies: \(error)")
        }
    }

    private func saveCustomPolicies() {
        do {
            let data = try JSONEncoder().encode(customPolicies)
            // Save to both iCloud and local
            cloudStore.set(data, forKey: Self.customPoliciesKey)
            cloudStore.synchronize()
            UserDefaults.standard.set(data, forKey: Self.customPoliciesKey)
        } catch {
            RFLogger.policy.error("Failed to encode custom policies: \(error)")
        }
    }

    private func observeCloudChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let userInfo = notification.userInfo,
                  let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                  changedKeys.contains(Self.customPoliciesKey) else { return }

            Task { @MainActor in
                self.loadCustomPolicies()
            }
        }
        // Trigger initial sync
        cloudStore.synchronize()
    }

    func addCustomPolicy(_ policy: StorePolicy) {
        customPolicies.append(policy)
        saveCustomPolicies()
    }

    func removeCustomPolicy(id: String) {
        customPolicies.removeAll { $0.id == id }
        saveCustomPolicies()
    }

    func allPolicies() -> [StorePolicy] {
        bundledPolicies + customPolicies
    }

    func findPolicy(storeName: String) -> StorePolicy? {
        let normalized = normalize(storeName)
        guard !normalized.isEmpty else { return nil }

        // Exact alias match first
        for policy in allPolicies() {
            let allNames = [policy.name] + policy.aliases
            for alias in allNames {
                if normalize(alias) == normalized {
                    return policy
                }
            }
        }

        // Substring match — check if OCR text contains a store name
        for policy in allPolicies() {
            let allNames = [policy.name] + policy.aliases
            for alias in allNames {
                let normalizedAlias = normalize(alias)
                if normalized.contains(normalizedAlias) || normalizedAlias.contains(normalized) {
                    return policy
                }
            }
        }

        return nil
    }

    func findPolicyFromOCRText(_ ocrText: String) -> StorePolicy? {
        let lines = ocrText.components(separatedBy: .newlines)
        // Check first 5 lines — store name is usually at the top of receipts
        let headerLines = Array(lines.prefix(5))

        for line in headerLines {
            if let policy = findPolicy(storeName: line) {
                return policy
            }
        }

        // Try the full text as a fallback
        for policy in allPolicies() {
            let allNames = [policy.name] + policy.aliases
            for alias in allNames {
                let normalizedAlias = normalize(alias)
                if normalizedAlias.count >= 3, normalize(ocrText).contains(normalizedAlias) {
                    return policy
                }
            }
        }

        return nil
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }
}
