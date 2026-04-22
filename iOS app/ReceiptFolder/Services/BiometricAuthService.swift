import Foundation
import LocalAuthentication

@MainActor
@Observable
final class BiometricAuthService {
    static let shared = BiometricAuthService()

    var isUnlocked = false
    var biometricType: LABiometryType = .none

    private init() {
        checkBiometricType()
    }

    var isAppLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "appLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "appLockEnabled") }
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }

    func authenticate() async -> Bool {
        guard isAppLockEnabled else {
            isUnlocked = true
            return true
        }

        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Receipt Folder to view your receipts"
            )
            isUnlocked = success
            return success
        } catch {
            // Always explicitly mark locked on error so a throwing auth
            // call can never leave a stale `isUnlocked = true`.
            isUnlocked = false
            return false
        }
    }

    func lock() {
        if isAppLockEnabled {
            isUnlocked = false
        }
    }
}
