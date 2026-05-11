import Testing
@testable import MacAudit
import Foundation

// MARK: - Helpers

private func tempDir() -> String {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    return path
}

private func makeRecord(id: String = "t.c1") -> FixRecord {
    FixRecord(
        checkId: id,
        name: "Check \(id)",
        command: "defaults write com.apple.X key -bool true",
        previousValue: "false",
        newValue: "true",
        timestamp: ISO8601DateFormatter().string(from: Date()),
        undoCommand: "defaults write com.apple.X key -bool false"
    )
}

private func makeBatch(id: String = "fix_test", records: [FixRecord]) -> FixBatch {
    FixBatch(id: id, timestamp: ISO8601DateFormatter().string(from: Date()), records: records)
}

// MARK: - FixHistory init and paths

@Test("FixHistory uses custom baseDir")
func fixHistoryCustomBaseDir() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    // Should not throw on init — just stores the path
    _ = history.loadAll()  // loads from empty/nonexistent path → returns []
}

@Test("FixHistory loadAll returns empty when no history file exists")
func fixHistoryLoadAllEmpty() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batches = history.loadAll()
    #expect(batches.isEmpty)
}

// MARK: - saveBatch / loadAll

@Test("FixHistory saveBatch persists a batch")
func fixHistorySaveBatch() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batch = makeBatch(records: [makeRecord()])
    try history.saveBatch(batch)
    let loaded = history.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded[0].id == batch.id)
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("FixHistory saveBatch appends multiple batches")
func fixHistoryMultipleBatches() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    try history.saveBatch(makeBatch(id: "batch1", records: [makeRecord()]))
    try history.saveBatch(makeBatch(id: "batch2", records: [makeRecord()]))
    let loaded = history.loadAll()
    #expect(loaded.count == 2)
    #expect(loaded[0].id == "batch1")
    #expect(loaded[1].id == "batch2")
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("FixHistory saveBatch preserves record fields")
func fixHistorySaveBatchRecordFields() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let record = makeRecord(id: "m2.sip")
    let batch = makeBatch(records: [record])
    try history.saveBatch(batch)
    let loaded = history.loadAll()
    let loadedRecord = loaded[0].records[0]
    #expect(loadedRecord.checkId == "m2.sip")
    #expect(loadedRecord.command == record.command)
    #expect(loadedRecord.undoCommand == record.undoCommand)
    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - lastBatch

@Test("FixHistory lastBatch returns nil when empty")
func fixHistoryLastBatchNil() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    #expect(history.lastBatch() == nil)
}

@Test("FixHistory lastBatch returns last saved batch")
func fixHistoryLastBatch() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    try history.saveBatch(makeBatch(id: "first", records: [makeRecord()]))
    try history.saveBatch(makeBatch(id: "last", records: [makeRecord()]))
    let last = history.lastBatch()
    #expect(last?.id == "last")
    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - generateUndoScript

@Test("FixHistory generateUndoScript contains shebang")
func fixHistoryUndoScriptShebang() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batch = makeBatch(records: [makeRecord()])
    let script = history.generateUndoScript(for: batch)
    #expect(script.hasPrefix("#!/bin/bash"))
}

@Test("FixHistory generateUndoScript contains batch id")
func fixHistoryUndoScriptBatchId() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batch = makeBatch(id: "fix_20250101_120000", records: [makeRecord()])
    let script = history.generateUndoScript(for: batch)
    #expect(script.contains("fix_20250101_120000"))
}

@Test("FixHistory generateUndoScript contains undo commands for each record")
func fixHistoryUndoScriptCommands() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let r1 = makeRecord(id: "t.c1")
    let r2 = FixRecord(
        checkId: "t.c2", name: "C2",
        command: "defaults write com.apple.Y k -bool true",
        previousValue: "false", newValue: "true",
        timestamp: "", undoCommand: "defaults write com.apple.Y k -bool false"
    )
    let batch = makeBatch(records: [r1, r2])
    let script = history.generateUndoScript(for: batch)
    #expect(script.contains(r1.undoCommand))
    #expect(script.contains(r2.undoCommand))
}

@Test("FixHistory generateUndoScript is empty records produces only header")
func fixHistoryUndoScriptEmpty() {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batch = makeBatch(records: [])
    let script = history.generateUndoScript(for: batch)
    #expect(script.contains("#!/bin/bash"))
    #expect(script.contains("MacAudit"))
}

// MARK: - A0 Defect: atomic write + NSFileCoordinator (T7/T8)

@Test("FixHistory saveBatch writes atomically — no temp files left behind")
func fixHistoryAtomicWriteNoTempFiles() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batch = makeBatch(records: [makeRecord()])
    try history.saveBatch(batch)
    let contents = try FileManager.default.contentsOfDirectory(atPath: dir)
    let tempFiles = contents.filter { $0.hasSuffix(".tmp") || $0.contains(".write_tmp") }
    #expect(tempFiles.isEmpty)
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("FixHistory saveBatch survives rapid concurrent writes without data loss")
func fixHistoryConcurrentWrites() async throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let count = 10
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<count {
            group.addTask {
                let h = FixHistory(baseDir: dir)
                let r = FixRecord(
                    checkId: "t.c\(i)", name: "Concurrent \(i)",
                    command: "echo \(i)", previousValue: "old\(i)", newValue: "new\(i)",
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    undoCommand: "echo undo\(i)"
                )
                let b = FixBatch(id: "batch_\(i)", timestamp: ISO8601DateFormatter().string(from: Date()), records: [r])
                try? h.saveBatch(b)
            }
        }
    }
    let loaded = history.loadAll()
    #expect(loaded.count == count)
    try? FileManager.default.removeItem(atPath: dir)
}

// MARK: - A0 Defect: saveBatch throws on corrupt existing file (D5)

@Test("FixHistory saveBatch throws when existing file contains invalid JSON")
func fixHistorySaveBatchThrowsOnCorruptFile() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try Data("{ invalid json".utf8).write(to: URL(fileURLWithPath: "\(dir)/history.json"))
    let batch = makeBatch(records: [makeRecord()])
    #expect(throws: Error.self) {
        try history.saveBatch(batch)
    }
    try? FileManager.default.removeItem(atPath: dir)
}

@Test("FixHistory saveBatch succeeds when no prior file exists (first run)")
func fixHistorySaveBatchNoPriorFile() throws {
    let dir = tempDir()
    let history = FixHistory(baseDir: dir)
    let batch = makeBatch(records: [makeRecord()])
    try history.saveBatch(batch)
    let loaded = history.loadAll()
    #expect(loaded.count == 1)
    try? FileManager.default.removeItem(atPath: dir)
}
