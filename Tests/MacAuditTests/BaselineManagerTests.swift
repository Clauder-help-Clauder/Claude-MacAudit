import Testing
@testable import MacAudit
import Foundation

// MARK: - Helpers

private func tempDir() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_baseline_\(UUID().uuidString)").path
}

private let sampleJSON = """
{
  "version": "0.1.0",
  "timestamp": "2025-01-01T00:00:00Z",
  "system": {"macosVersion": "15.0", "macosName": "sequoia", "deviceType": "laptop"},
  "summary": {"total": 2, "pass": 1, "fail": 1, "warn": 0, "info": 0, "skip": 0, "error": 0, "durationSeconds": 1.0},
  "results": [
    {"checkId": "m1.test", "name": "Test", "status": "pass", "riskLevel": "safe", "message": "ok"},
    {"checkId": "m2.test", "name": "Test2", "status": "fail", "riskLevel": "low", "message": "bad"}
  ]
}
"""

// MARK: - BaselineManager save

@Test("BaselineManager save creates file in baseDir")
func baselineSaveCreatesFile() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    let path = try manager.save(sampleJSON)
    #expect(FileManager.default.fileExists(atPath: path))
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager save returns path ending with .json")
func baselineSaveReturnsJsonPath() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    let path = try manager.save(sampleJSON)
    #expect(path.hasSuffix(".json"))
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager save filename starts with audit_")
func baselineSaveFilenamePrefix() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    let path = try manager.save(sampleJSON)
    let filename = URL(fileURLWithPath: path).lastPathComponent
    #expect(filename.hasPrefix("audit_"))
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager save content matches what was saved")
func baselineSaveContentMatches() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    let path = try manager.save(sampleJSON)
    let loaded = try String(contentsOfFile: path, encoding: .utf8)
    #expect(loaded == sampleJSON)
    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - lastReport / previousReport

@Test("BaselineManager lastReport returns nil when empty")
func baselineLastReportNil() {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    #expect(manager.lastReport() == nil)
}

@Test("BaselineManager lastReport returns path after save")
func baselineLastReportAfterSave() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    _ = try manager.save(sampleJSON)
    #expect(manager.lastReport() != nil)
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager previousReport returns nil with only one report")
func baselinePreviousReportNilSingleReport() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    _ = try manager.save(sampleJSON)
    #expect(manager.previousReport() == nil)
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager previousReport returns second-to-last after two saves")
func baselinePreviousReportTwoSaves() async throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    let first = try manager.save(sampleJSON)
    // Small delay to ensure different timestamps in filenames
    try await Task.sleep(nanoseconds: 1_100_000_000)
    _ = try manager.save(sampleJSON)
    let prev = manager.previousReport()
    #expect(prev != nil)
    #expect(prev == first)
    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - listReports

@Test("BaselineManager listReports returns empty when no reports")
func baselineListReportsEmpty() {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    #expect(manager.listReports().isEmpty)
}

@Test("BaselineManager listReports returns one entry after one save")
func baselineListReportsOneSave() throws {
    let dir = tempDir()
    let manager = BaselineManager(baseDir: dir)
    _ = try manager.save(sampleJSON)
    let reports = manager.listReports()
    #expect(reports.count == 1)
    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - diff

@Test("BaselineManager diff returns nil for missing files")
func baselineDiffMissingFiles() {
    let result = BaselineManager.diff(
        oldPath: "/nonexistent/old.json",
        newPath: "/nonexistent/new.json"
    )
    #expect(result == nil)
}

@Test("BaselineManager diff detects fixed items")
func baselineDiffFixed() throws {
    let dir = tempDir()
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    let oldJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"fail","riskLevel":"safe","message":"bad"}
    ]}
    """
    let newJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let oldPath = "\(dir)/old.json"
    let newPath = "\(dir)/new.json"
    try oldJSON.write(toFile: oldPath, atomically: true, encoding: .utf8)
    try newJSON.write(toFile: newPath, atomically: true, encoding: .utf8)

    let report = BaselineManager.diff(oldPath: oldPath, newPath: newPath)
    #expect(report != nil)
    #expect(report?.fixed.count == 1)
    #expect(report?.regressed.count == 0)

    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager diff detects regressed items")
func baselineDiffRegressed() throws {
    let dir = tempDir()
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    let oldJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let newJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"fail","riskLevel":"safe","message":"bad"}
    ]}
    """
    let oldPath = "\(dir)/old.json"
    let newPath = "\(dir)/new.json"
    try oldJSON.write(toFile: oldPath, atomically: true, encoding: .utf8)
    try newJSON.write(toFile: newPath, atomically: true, encoding: .utf8)

    let report = BaselineManager.diff(oldPath: oldPath, newPath: newPath)
    #expect(report != nil)
    #expect(report?.regressed.count == 1)
    #expect(report?.fixed.count == 0)

    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager diff hasChanges is false for identical reports")
func baselineDiffNoChanges() throws {
    let dir = tempDir()
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    let json = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let oldPath = "\(dir)/old.json"
    let newPath = "\(dir)/new.json"
    try json.write(toFile: oldPath, atomically: true, encoding: .utf8)
    try json.write(toFile: newPath, atomically: true, encoding: .utf8)

    let report = BaselineManager.diff(oldPath: oldPath, newPath: newPath)
    #expect(report != nil)
    #expect(report?.hasChanges == false)

    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager diff detects added checkId in new report")
func baselineDiffAdded() throws {
    let dir = tempDir()
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    let oldJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.existing","name":"Existing","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let newJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":2},"results":[
      {"checkId":"m1.existing","name":"Existing","status":"pass","riskLevel":"safe","message":"ok"},
      {"checkId":"m1.new_check","name":"New Check","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let oldPath = "\(dir)/old.json"
    let newPath = "\(dir)/new.json"
    try oldJSON.write(toFile: oldPath, atomically: true, encoding: .utf8)
    try newJSON.write(toFile: newPath, atomically: true, encoding: .utf8)

    let report = BaselineManager.diff(oldPath: oldPath, newPath: newPath)
    #expect(report != nil)
    #expect(report?.added == 1)
    #expect(report?.removed == 0)
    #expect(report?.hasChanges == true)

    try? FileManager.default.removeItem(atPath: dir)
}

@Test("BaselineManager diff detects removed checkId in new report")
func baselineDiffRemoved() throws {
    let dir = tempDir()
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    let oldJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":2},"results":[
      {"checkId":"m1.existing","name":"Existing","status":"pass","riskLevel":"safe","message":"ok"},
      {"checkId":"m1.removed_check","name":"Removed","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let newJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.existing","name":"Existing","status":"pass","riskLevel":"safe","message":"ok"}
    ]}
    """
    let oldPath = "\(dir)/old.json"
    let newPath = "\(dir)/new.json"
    try oldJSON.write(toFile: oldPath, atomically: true, encoding: .utf8)
    try newJSON.write(toFile: newPath, atomically: true, encoding: .utf8)

    let report = BaselineManager.diff(oldPath: oldPath, newPath: newPath)
    #expect(report != nil)
    #expect(report?.removed == 1)
    #expect(report?.added == 0)
    #expect(report?.hasChanges == true)

    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - DiffReport JSON serialization

@Test("DiffReport toJSON produces valid JSON without TUI text")
func diffReportToJSONIsValid() throws {
    let report = DiffReport(
        oldTotal: 10, newTotal: 10,
        fixed: [("m1.test", "Test")],
        regressed: [],
        changed: [],
        added: 0, removed: 0
    )
    let jsonStr = report.toJSON()
    let data = jsonStr.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(parsed["hasChanges"] as? Bool == true)
    #expect(parsed["fixed"] as? Int == 1)
    #expect(parsed["regressed"] as? Int == 0)
    #expect(parsed["oldTotal"] as? Int == 10)
    #expect(parsed["newTotal"] as? Int == 10)
    #expect(parsed["added"] as? Int == 0)
    #expect(parsed["removed"] as? Int == 0)
}

@Test("DiffReport toJSON with no changes reports hasChanges false")
func diffReportToJSONNoChanges() throws {
    let report = DiffReport(
        oldTotal: 5, newTotal: 5,
        fixed: [], regressed: [], changed: [],
        added: 0, removed: 0
    )
    let jsonStr = report.toJSON()
    let data = jsonStr.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(parsed["hasChanges"] as? Bool == false)
}

@Test("DiffReport toJSON includes changed items with old and new status")
func diffReportToJSONChangedItems() throws {
    let report = DiffReport(
        oldTotal: 3, newTotal: 3,
        fixed: [],
        regressed: [("m2.sec", "Security")],
        changed: [("m3.net", "Network", "pass", "warn")],
        added: 1, removed: 2
    )
    let jsonStr = report.toJSON()
    let data = jsonStr.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(parsed["hasChanges"] as? Bool == true)
    #expect(parsed["regressed"] as? Int == 1)
    #expect(parsed["changed"] as? Int == 1)
    #expect(parsed["added"] as? Int == 1)
    #expect(parsed["removed"] as? Int == 2)
    #expect(parsed["details"] != nil)
    let details = parsed["details"] as! [String: Any]
    let regressedArr = details["regressed"] as! [[String: String]]
    #expect(regressedArr.count == 1)
    #expect(regressedArr[0]["id"] == "m2.sec")
    let changedArr = details["changed"] as! [[String: String]]
    #expect(changedArr.count == 1)
    #expect(changedArr[0]["oldStatus"] == "pass")
    #expect(changedArr[0]["newStatus"] == "warn")
}

@Test("BaselineManager diff detects changed status (warn to info)")
func baselineDiffChanged() throws {
    let dir = tempDir()
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    // warn → info: neither is fail→pass or pass→fail, goes into 'changed'
    let oldJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"warn","riskLevel":"safe","message":"w"}
    ]}
    """
    let newJSON = """
    {"version":"0.1.0","timestamp":"","system":{},"summary":{"total":1},"results":[
      {"checkId":"m1.test","name":"Test","status":"info","riskLevel":"safe","message":"i"}
    ]}
    """
    let oldPath = "\(dir)/old.json"
    let newPath = "\(dir)/new.json"
    try oldJSON.write(toFile: oldPath, atomically: true, encoding: .utf8)
    try newJSON.write(toFile: newPath, atomically: true, encoding: .utf8)

    let report = BaselineManager.diff(oldPath: oldPath, newPath: newPath)
    #expect(report != nil)
    #expect(report?.changed.count == 1)
    #expect(report?.fixed.count == 0)
    #expect(report?.regressed.count == 0)
    #expect(report?.hasChanges == true)

    try? FileManager.default.removeItem(atPath: dir)
}
