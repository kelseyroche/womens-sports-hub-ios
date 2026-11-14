import Foundation

public enum EasternTime {
    public static let zone = TimeZone(identifier: "America/New_York")!

    public static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    public static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    public static func addingDays(_ days: Int, to date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(byAdding: .day, value: days, to: date)!
    }
}
