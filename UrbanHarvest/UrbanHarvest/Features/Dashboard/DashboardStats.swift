import Foundation

/// Plain arithmetic over saved sessions. No ML involved.
struct DashboardStats: Equatable {
    enum Granularity: String, CaseIterable, Identifiable {
        case day
        case week

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .day: return "Harian"
            case .week: return "Mingguan"
            }
        }

        var calendarComponent: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            }
        }

        /// How many periods the chart shows.
        var periodsShown: Int {
            switch self {
            case .day: return 14
            case .week: return 8
            }
        }
    }

    /// Value-type copy of a session so the maths is easy to test.
    struct Entry: Equatable {
        var date: Date
        var good: Int
        var defect: Int
    }

    struct Point: Identifiable, Equatable {
        var period: Date
        var bucket: FruitBucket
        var count: Int

        var id: String { "\(period.timeIntervalSince1970)-\(bucket.rawValue)" }
    }

    var sessionCount = 0
    var totalGood = 0
    var totalDefect = 0

    var total: Int { totalGood + totalDefect }
    var goodPercent: Double { total == 0 ? 0 : Double(totalGood) / Double(total) * 100 }
    var defectPercent: Double { total == 0 ? 0 : Double(totalDefect) / Double(total) * 100 }

    init(entries: [Entry]) {
        sessionCount = entries.count
        totalGood = entries.reduce(0) { $0 + $1.good }
        totalDefect = entries.reduce(0) { $0 + $1.defect }
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "id_ID")
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    /// Good and defect totals per day or week, for the last `granularity.periodsShown` periods
    /// ending at `now`. Periods without sessions are omitted.
    static func series(
        _ entries: [Entry],
        granularity: Granularity,
        now: Date = .now,
        calendar: Calendar = DashboardStats.calendar
    ) -> [Point] {
        guard let currentPeriod = calendar.dateInterval(of: granularity.calendarComponent, for: now)?.start,
              let firstPeriod = calendar.date(byAdding: granularity.calendarComponent, value: -(granularity.periodsShown - 1), to: currentPeriod)
        else { return [] }

        var good: [Date: Int] = [:]
        var defect: [Date: Int] = [:]
        for entry in entries {
            guard let period = calendar.dateInterval(of: granularity.calendarComponent, for: entry.date)?.start,
                  period >= firstPeriod, period <= currentPeriod else { continue }
            good[period, default: 0] += entry.good
            defect[period, default: 0] += entry.defect
        }

        return Set(good.keys).union(defect.keys).sorted().flatMap { period in
            [
                Point(period: period, bucket: .good, count: good[period] ?? 0),
                Point(period: period, bucket: .defect, count: defect[period] ?? 0),
            ]
        }
    }
}

extension HarvestSession {
    var statsEntry: DashboardStats.Entry {
        DashboardStats.Entry(date: date, good: goodCount, defect: defectCount)
    }
}
