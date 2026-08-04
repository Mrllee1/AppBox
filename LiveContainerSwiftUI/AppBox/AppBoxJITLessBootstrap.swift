import Foundation

enum AppBoxJITLessBootstrap {
    private static let certificateFileName = "AppBox-JITLess-6TQJ3XWC45.p12"
    private static let configurationFileName = "AppBox-JITLess-6TQJ3XWC45.plist"

    static func importSeedCertificateIfNeeded() {
        guard LCSharedUtils.certificatePassword() == nil,
              let appGroupID = LCSharedUtils.appGroupID(),
              let expectedTeamID = LCSharedUtils.teamIdentifier(),
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
              ) else {
            return
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let certificateURL = documentsURL.appendingPathComponent(certificateFileName)
        let configurationURL = documentsURL.appendingPathComponent(configurationFileName)

        guard let certificateData = try? Data(contentsOf: certificateURL),
              let configurationData = try? Data(contentsOf: configurationURL),
              let configuration = try? PropertyListSerialization.propertyList(
                from: configurationData,
                format: nil
              ) as? [String: Any],
              let password = configuration["password"] as? String,
              !password.isEmpty,
              let certificateTeamID = LCUtils.getCertTeamId(
                withKeyData: certificateData,
                password: password
              ),
              certificateTeamID == expectedTeamID else {
            return
        }

        let defaults = LCUtils.appGroupUserDefault
        defaults.set(certificateData, forKey: "LCCertificateData")
        defaults.set(password, forKey: "LCCertificatePassword")
        defaults.set(Date(), forKey: "LCCertificateUpdateDate")
        defaults.synchronize()
        UserDefaults.standard.set(appGroupID, forKey: "LCAppGroupID")

        try? FileManager.default.removeItem(at: certificateURL)
        try? FileManager.default.removeItem(at: configurationURL)
    }
}
