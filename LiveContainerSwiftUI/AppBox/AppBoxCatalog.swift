import Foundation

enum AppBoxCatalog {
    static func filter(
        groups: [AppBoxCatalogGroup],
        seriesID: String?,
        query: String
    ) -> [AppBoxCatalogGroup] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return groups.compactMap { group in
            if normalizedQuery.isEmpty, let seriesID, !seriesID.isEmpty, group.series.id != seriesID {
                return nil
            }

            let filteredItems = group.items.filter { item in
                normalizedQuery.isEmpty ||
                    item.chineseName.localizedCaseInsensitiveContains(normalizedQuery) ||
                    item.englishName.localizedCaseInsensitiveContains(normalizedQuery) ||
                    (item.bundleIdentifier?.localizedCaseInsensitiveContains(normalizedQuery) ?? false) ||
                    (item.source.webEntryURL?.host?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
            }

            return filteredItems.isEmpty ? nil : group.replacingItems(filteredItems)
        }
    }
}
