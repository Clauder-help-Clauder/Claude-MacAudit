import Foundation

/// 单条修复记录
public struct FixRecord: Codable {
    public let checkId: String
    public let name: String
    public let command: String
    public let previousValue: String
    public let newValue: String
    public let timestamp: String
    public let undoCommand: String
}

/// 修复批次记录
public struct FixBatch: Codable {
    public let id: String
    public let timestamp: String
    public let records: [FixRecord]
}

/// 修复历史管理
public struct FixHistory {
    private let baseDir: String

    public init(baseDir: String = "~/.macaudit") {
        self.baseDir = (baseDir as NSString).expandingTildeInPath
    }

    private var historyPath: String { "\(baseDir)/history.json" }

    private func ensureDir() throws {
        try FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
    }

    /// 保存一个修复批次（原子写入 + 文件协调防 TOCTOU）
    public func saveBatch(_ batch: FixBatch) throws {
        try ensureDir()
        let fileURL = URL(fileURLWithPath: historyPath)
        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinatorError) { url in
            do {
                var batches: [FixBatch] = []
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                if fileExists {
                    let data = try Data(contentsOf: url)
                    batches = try JSONDecoder().decode([FixBatch].self, from: data)
                }
                batches.append(batch)
                let data = try JSONEncoder().encode(batches)
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = writeError { throw error }
        if let error = coordinatorError { throw error as Error }
    }

    /// 加载所有批次
    public func loadAll() -> [FixBatch] {
        guard let data = FileManager.default.contents(atPath: historyPath),
              let batches = try? JSONDecoder().decode([FixBatch].self, from: data)
        else { return [] }
        return batches
    }

    /// 获取最近一个批次
    public func lastBatch() -> FixBatch? {
        loadAll().last
    }

    /// 生成回滚脚本
    public func generateUndoScript(for batch: FixBatch) -> String {
        var script = "#!/bin/bash\n"
        script += "# MacAudit 回滚脚本\n"
        script += "# 批次: \(batch.id)\n"
        script += "# 时间: \(batch.timestamp)\n\n"

        for record in batch.records {
            script += "# 回滚: \(record.name)\n"
            script += "\(record.undoCommand)\n\n"
        }
        return script
    }

    /// 打印历史
    public func printHistory() {
        let batches = loadAll()
        if batches.isEmpty {
            Layout.print(ANSIColor.dim.wrap("\n  无修复历史记录\n"))
            return
        }

        Layout.print(ANSIColor.bold.wrap("\n  修复历史 (\(batches.count) 个批次)"))
        for batch in batches.reversed().prefix(5) {
            Layout.printEmpty()
            Layout.print("  批次: \(batch.id)")
            Layout.print("  时间: \(batch.timestamp)")
            Layout.print("  修复: \(batch.records.count) 项")
            for r in batch.records.prefix(5) {
                Layout.print("    - \(r.name): \(r.previousValue) → \(r.newValue)")
            }
            if batch.records.count > 5 {
                Layout.print("    ... 还有 \(batch.records.count - 5) 项")
            }
        }
        Layout.printEmpty()
    }
}
