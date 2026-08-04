import Foundation

enum AppBoxJITLessBootstrap {
    private static let certificateFileName = "AppBox-JITLess-6TQJ3XWC45.p12"
    private static let configurationFileName = "AppBox-JITLess-6TQJ3XWC45.plist"

    private struct SeedCertificate {
        let data: Data
        let password: String
        let removableURLs: [URL]
    }

    static func configure() {
        importSeedCertificateIfNeeded()
        validateConfigurationIfNeeded()
    }

    private static func importSeedCertificateIfNeeded() {
        guard LCSharedUtils.certificatePassword() == nil,
              let appGroupID = LCSharedUtils.appGroupID(),
              let expectedTeamID = LCSharedUtils.teamIdentifier(),
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
              ) else {
            return
        }

        guard let seed = loadSeedCertificate(
            containerURL: containerURL,
            expectedTeamID: expectedTeamID
        ) else {
            return
        }

        let defaults = LCUtils.appGroupUserDefault
        defaults.set(seed.data, forKey: "LCCertificateData")
        defaults.set(seed.password, forKey: "LCCertificatePassword")
        defaults.set(Date(), forKey: "LCCertificateUpdateDate")
        defaults.synchronize()
        UserDefaults.standard.set(appGroupID, forKey: "LCAppGroupID")

        seed.removableURLs.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private static func loadSeedCertificate(
        containerURL: URL,
        expectedTeamID: String
    ) -> SeedCertificate? {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let locations: [(url: URL, isRemovable: Bool)] = [
            (documentsURL, true),
            (Bundle.main.resourceURL ?? Bundle.main.bundleURL, false)
        ]

        for location in locations {
            let certificateURL = location.url.appendingPathComponent(certificateFileName)
            let configurationURL = location.url.appendingPathComponent(configurationFileName)

            guard let certificateData = try? Data(contentsOf: certificateURL),
                  let configurationData = try? Data(contentsOf: configurationURL),
                  let configuration = try? PropertyListSerialization.propertyList(
                    from: configurationData,
                    format: nil
                  ) as? [String: Any],
                  let password = configuration["password"] as? String,
                  !password.isEmpty,
                  LCUtils.getCertTeamId(withKeyData: certificateData, password: password) == expectedTeamID else {
                continue
            }

            return SeedCertificate(
                data: certificateData,
                password: password,
                removableURLs: location.isRemovable ? [certificateURL, configurationURL] : []
            )
        }

        return nil
    }

    private static func validateConfigurationIfNeeded() {
        let defaults = LCUtils.appGroupUserDefault
        guard LCSharedUtils.certificatePassword() != nil,
              let updateDate = defaults.object(forKey: "LCCertificateUpdateDate") as? Date else {
            return
        }

        let validatedDate = defaults.object(forKey: "AppBoxJITLessValidatedDate") as? Date
        guard validatedDate != updateDate else { return }

        LCUtils.validateJITLessSetup { success, error in
            defaults.set(success, forKey: "AppBoxJITLessValidationSucceeded")
            defaults.set(error?.localizedDescription, forKey: "AppBoxJITLessValidationError")
            defaults.set(updateDate, forKey: "AppBoxJITLessValidatedDate")
            defaults.synchronize()
        }
    }
}
