//
//  VersionManager.swift
//  BhittePatroApp
//
//  Created by Pranab Kc on 09/04/2026.
//

import Foundation
import Combine

struct VersionInfo: Codable {
    let version: String
    let message: String?
    let link: String?
}

class VersionManager: ObservableObject {
    static let shared = VersionManager()

    private let versionURL = URL(string: "https://calendar.pranabkca321.workers.dev/version.json")!
    private let lastCheckKey = "VersionLastCheck"
    private let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    @Published var isChecking = false
    @Published var hasUpdate = false
    @Published var latestVersion = ""
    @Published var updateMessage: String?
    @Published var updateLink: URL?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private init() {}

    func checkForUpdate() async {
        // Skip if checked recently
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? Date.distantPast
        if Date().timeIntervalSince(lastCheck) < checkInterval && hasUpdate {
            return
        }

        await MainActor.run { isChecking = true }

        do {
            let (data, response) = try await URLSession.shared.data(from: versionURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let info = try JSONDecoder().decode(VersionInfo.self, from: data)

            let hasNewVersion = compareVersions(info.version, currentVersion) > 0

            await MainActor.run {
                self.hasUpdate = hasNewVersion
                self.latestVersion = info.version
                self.updateMessage = info.message
                if let link = info.link {
                    self.updateLink = URL(string: link)
                }
                self.isChecking = false
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            }
        } catch {
            await MainActor.run {
                self.isChecking = false
            }
        }
    }

    // Returns: 1 if a > b, -1 if a < b, 0 if equal
    private func compareVersions(_ a: String, _ b: String) -> Int {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)

        for i in 0..<count {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal > bVal { return 1 }
            if aVal < bVal { return -1 }
        }
        return 0
    }
}
