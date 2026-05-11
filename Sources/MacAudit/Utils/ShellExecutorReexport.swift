// ShellExecutorReexport.swift — 从 MacAuditCore 重导出 ShellExecutor 和 ShellResult 类型，供 MacAudit 模块统一使用

import MacAuditCore

/// Shell 命令执行器，重导出自 MacAuditCore
public typealias ShellExecutor = MacAuditCore.ShellExecutor
/// Shell 命令执行结果，重导出自 MacAuditCore
public typealias ShellResult = MacAuditCore.ShellResult
