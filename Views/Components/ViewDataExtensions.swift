import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    var asISODate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: self)
    }

    var relativeDescription: String {
        guard let date = asISODate else { return self }
        return date.relativeDescription
    }

    var shortFormat: String {
        guard let date = asISODate else { return self }
        return date.shortFormat
    }
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortFormat: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("E d.M")
        return formatter.string(from: self)
    }
}

