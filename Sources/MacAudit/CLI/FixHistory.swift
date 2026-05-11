// FixHistory.swift
// 修复历史管理 — 记录每次修复操作的批次（FixBatch），
// 支持生成回滚脚本、查看历史，为 --undo 功能提供数据基础。

import Foundation

/// 单条修复记录，记录一次修复的完整上下文
struct FixRecord: Codable {
    /// 关联的检测项 ID
    let checkId: String
    /// 检测项名称
    let name: String
    /// 执行的修复命令
    let command: String
    /// 修复前的原始值
    let previousValue: String
    /// 修复后的新值
    let newValue: String
    /// 修复时间（ISO 8601）
    let timestamp: String
    /// 回滚命令
    let undoCommand: String
}

/// 修复批次记录，一次修复操作中所有记录的集合
struct FixBatch: Codable {
    /// 批次唯一标识
    let id: String
    /// 批次时间（ISO 8601）
    let timestamp: String
    /// 本批次包含的修复记录
    let records: [FixRecord]
}

/// 修复历史管理器，负责持久化修复批次到 JSON 文件
struct FixHistory {
    /// 历史文件存储根目录
    private let baseDir: String

    /// 初始化历史管理器
    /// - Parameter baseDir: 存储根目录，默认 ~/.macaudit
    init(baseDir: String = "~/.macaudit") {
        self.baseDir = (baseDir as NSString).expandingTildeInPath
    }

    /// 历史文件完整路径
    private var historyPath: String { "\(baseDir)/history.json" }

    /// 确保存储目录存在
    private func ensureDir() throws {
        try FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
    }

    /// 保存一个修复批次（原子写入 + NSFileCoordinator 防 TOCTOU 竞态）
    /// - Parameter batch: 待保存的修复批次
    func saveBatch(_ batch: FixBatch) throws {
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

    /// 加载所有已保存的修复批次
    /// - Returns: 批次数组，文件不存在或解析失败返回空数组
    func loadAll() -> [FixBatch] {
        guard let data = FileManager.default.contents(atPath: historyPath),
              let batches = try? JSONDecoder().decode([FixBatch].self, from: data)
        else { return [] }
        return batches
    }

    /// 获取最近一个批次
    func lastBatch() -> FixBatch? {
        loadAll().last
    }

    /// 根据指定批次生成可执行的 bash 回滚脚本
    /// - Parameter batch: 目标批次
    /// - Returns: 完整的 bash 脚本字符串
    func generateUndoScript(for batch: FixBatch) -> String {
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

    /// 格式化输出最近 5 个批次的修复历史到终端
    func printHistory() {
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
