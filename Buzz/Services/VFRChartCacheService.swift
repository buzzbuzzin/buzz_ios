//
//  VFRChartCacheService.swift
//  Buzz
//
//  Manages disk caching for FAA VFR Sectional Chart tiles with
//  automatic invalidation when FAA publishes new chart editions.
//  FAA charts follow a 56-day publication cycle.
//

import Foundation

class VFRChartCacheService {
    static let shared = VFRChartCacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataURL = "https://tiles.arcgis.com/tiles/ssFJjBXIUyZDrSYZ/arcgis/rest/services/VFR_Sectional/MapServer?f=json"

    // UserDefaults keys
    private let lastEditionKey = "VFRChart_LastEditionTimestamp"
    private let lastCheckKey = "VFRChart_LastCheckTimestamp"
    private let editionLabelKey = "VFRChart_EditionLabel"

    // Check for updates at most once per 24 hours
    private let checkInterval: TimeInterval = 86400

    // Published state for UI
    private(set) var lastEditionLabel: String? {
        get { UserDefaults.standard.string(forKey: editionLabelKey) }
        set { UserDefaults.standard.set(newValue, forKey: editionLabelKey) }
    }

    var isCachePopulated: Bool {
        fileManager.fileExists(atPath: cacheDirectory.path) &&
        (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path))?.isEmpty == false
    }

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("VFRChartTiles", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Tile Cache Operations

    func cachedTile(z: Int, y: Int, x: Int) -> Data? {
        let path = tilePath(z: z, y: y, x: x)
        return fileManager.contents(atPath: path.path)
    }

    func cacheTile(data: Data, z: Int, y: Int, x: Int) {
        let path = tilePath(z: z, y: y, x: x)
        let dir = path.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: path)
    }

    private func tilePath(z: Int, y: Int, x: Int) -> URL {
        cacheDirectory.appendingPathComponent("\(z)/\(y)/\(x).png")
    }

    // MARK: - Edition Update Check

    /// Checks the ArcGIS MapServer metadata for new FAA chart editions.
    /// If a new edition is detected, the tile cache is cleared so fresh tiles are fetched.
    /// Returns true if the cache was invalidated (new edition found).
    @discardableResult
    func checkForUpdates() async -> Bool {
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let now = Date().timeIntervalSince1970

        guard now - lastCheck > checkInterval else { return false }

        guard let url = URL(string: metadataURL) else { return false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }

            // Extract last edit date from ArcGIS metadata (epoch in milliseconds)
            var editionTimestamp: Double = 0
            if let editingInfo = json["editingInfo"] as? [String: Any],
               let lastEditDate = editingInfo["lastEditDate"] as? Double {
                editionTimestamp = lastEditDate
            }

            // Extract edition description if available
            if let description = json["description"] as? String, !description.isEmpty {
                lastEditionLabel = description
            } else if let name = json["mapName"] as? String, !name.isEmpty {
                lastEditionLabel = name
            }

            let storedEdition = UserDefaults.standard.double(forKey: lastEditionKey)
            var didInvalidate = false

            if editionTimestamp > 0 && storedEdition > 0 && editionTimestamp > storedEdition {
                // New edition detected — clear tile cache
                clearTileCache()
                didInvalidate = true
                print("VFR Chart: New edition detected, cache cleared")
            }

            if editionTimestamp > 0 {
                UserDefaults.standard.set(editionTimestamp, forKey: lastEditionKey)
            }
            UserDefaults.standard.set(now, forKey: lastCheckKey)

            return didInvalidate
        } catch {
            print("VFR chart update check failed: \(error.localizedDescription)")
            return false
        }
    }

    func clearTileCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    var cacheSizeDescription: String {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "Empty"
        }
        var totalSize: Int64 = 0
        var fileCount = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
                fileCount += 1
            }
        }
        if fileCount == 0 { return "Empty" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(fileCount) tiles (\(formatter.string(fromByteCount: totalSize)))"
    }
}
