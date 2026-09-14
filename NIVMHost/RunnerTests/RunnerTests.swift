import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testFreshQuietformLaunchUsesPrivacySurface() {
    let suiteName = "AppBoxSurfaceTests.fresh.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(arguments: ["Quietform"], defaults: defaults),
      .privacy
    )
  }

  func testForcedBoxLaunchPersistsTheActivatedSurface() {
    let suiteName = "AppBoxSurfaceTests.box.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(
        arguments: ["Quietform", "--appbox-force-surface"],
        defaults: defaults
      ),
      .box
    )
    XCTAssertTrue(defaults.bool(forKey: AppBoxSurfaceRoute.activatedKey))
    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(arguments: ["Quietform"], defaults: defaults),
      .box
    )
  }

  func testPrivacyCaptureLaunchResetsTheActivatedSurface() {
    let suiteName = "AppBoxSurfaceTests.capture.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(true, forKey: AppBoxSurfaceRoute.activatedKey)

    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(
        arguments: ["Quietform", "--appbox-capture-privacy"],
        defaults: defaults
      ),
      .privacy
    )
    XCTAssertFalse(defaults.bool(forKey: AppBoxSurfaceRoute.activatedKey))
  }

  func testQuietformURLsRouteABFacesWithoutHijackingGuestRelaunch() {
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "quietform://box")!), .box)
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "quietform://open?id=tianya")!), .box)
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "quietform://privacy")!), .privacy)
    XCTAssertNil(AppBoxSurfaceRoute.surface(for: URL(string: "quietform://sandbox.relaunch")!))
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "appbox://box")!), .box)
    XCTAssertFalse(AppBoxSurfaceRoute.supports(scheme: "https"))
    XCTAssertNil(AppBoxSurfaceRoute.surface(for: URL(string: "https://3601.help")!))
  }

  func testScheduleOnlyRunsOnSelectedWeekdays() throws {
    let rule = AppBoxScheduleRule(
      name: "工作时间",
      startHour: 9,
      startMinute: 0,
      endHour: 18,
      endMinute: 0,
      weekdays: Set([AppBoxWeekday.monday.rawValue])
    )
    let calendar = utcCalendar()
    XCTAssertTrue(rule.contains(try date("2026-09-07 10:00"), calendar: calendar))
    XCTAssertFalse(rule.contains(try date("2026-09-08 10:00"), calendar: calendar))
  }

  func testOvernightScheduleUsesThePreviousSelectedWeekdayAfterMidnight() throws {
    let rule = AppBoxScheduleRule(
      name: "夜间专注",
      startHour: 22,
      startMinute: 0,
      endHour: 2,
      endMinute: 0,
      weekdays: Set([AppBoxWeekday.monday.rawValue])
    )
    let calendar = utcCalendar()
    XCTAssertTrue(rule.contains(try date("2026-09-07 23:00"), calendar: calendar))
    XCTAssertTrue(rule.contains(try date("2026-09-08 01:00"), calendar: calendar))
    XCTAssertFalse(rule.contains(try date("2026-09-09 01:00"), calendar: calendar))
  }

  func testLegacyScheduleWithoutWeekdaysMigratesToEveryDay() throws {
    let json = """
    {
      "id": "legacy",
      "name": "旧日程",
      "startHour": 9,
      "startMinute": 0,
      "endHour": 10,
      "endMinute": 0,
      "isEnabled": true,
      "createdAt": 0
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let rule = try decoder.decode(AppBoxScheduleRule.self, from: json)
    XCTAssertEqual(rule.weekdays, Set(1...7))
  }

  private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private func date(_ value: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.calendar = utcCalendar()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return try XCTUnwrap(formatter.date(from: value))
  }

}
