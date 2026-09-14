//
//  QuietformReport.swift
//  QuietformReport
//

import DeviceActivity
import SwiftUI
import ExtensionKit

@main
struct QuietformReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        RuleUsageReport()
    }
}
