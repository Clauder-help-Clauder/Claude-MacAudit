# Contributing to MacAudit

First off, thank you for considering contributing to MacAudit! We welcome contributions from everyone.

**Repository**: [github.com/Clauder-help-Clauder/Claude-MacAudit](https://github.com/Clauder-help-Clauder/Claude-MacAudit)

## Quick Links

- [Code of Conduct](#code-of-conduct)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

Be respectful, constructive, and professional. We're all here to make macOS security better.

## Development Setup

### Prerequisites

- macOS 15.0 (Sequoia) or later
- Xcode 16.0+ with Swift 6.0 toolchain
- Git

### Build & Test

```bash
git clone https://github.com/Clauder-help-Clauder/Claude-MacAudit.git
cd Claude-MacAudit/MacAudit
swift build -c debug
swift test
bash scripts/build_app.sh        # Build GUI app
```

### Project Structure

```
MacAudit/Sources/
├── MacAudit/         # CLI executable (internal access)
├── MacAuditCore/     # Shared framework (public access)
├── MacAuditUI/       # SwiftUI interface
└── MacAuditApp/      # Thin launcher
```

> **Important**: This project uses a dual-copy architecture. Changes to modules, models, or shared utilities must be synced between `MacAudit/` and `MacAuditCore/`. See `HANDOFF.md` for details.

## Code Style

### Swift Conventions

- **Swift 6 strict concurrency** — all targets use `.swiftLanguageMode(.v6)`
- No third-party runtime dependencies
- `AuditModule` protocol for all audit modules
- `AuditCheck` struct with: `id`, `name`, `command`, `expectedValue`, `fixCommand`, `riskLevel`, `priority`, `architectures`
- Module files: `*Module.swift` in `Modules/` directory
- Test files: `*Tests.swift` in `Tests/MacAuditTests/`

### Naming Conventions

- Modules: PascalCase with `Module` suffix (e.g., `PrivacyModule.swift`)
- Checks: `m<module_num>.<check_name>` ID format (e.g., `m4.diagnostics`)
- Tests: `<ModuleName>Tests.swift` (e.g., `FixEngineTests.swift`)

### Priority System

Every `AuditCheck` MUST have an explicit `priority:` field:
- `A0` — Critical security (always included in default runs)
- `A1` — High impact
- `A2` — Medium / cosmetic
- `A3` — Low / informational

Default is `.a3` — new checks default to the lowest priority for safety.

### Fix Commands

- Every fix must have a corresponding undo command
- Fix commands are validated by `UndoValidator` (whitelist-based)
- Undo scripts are generated with `0o700` file permissions
- Test fix→undo roundtrip for every new fix command

## Testing Requirements

### Mandatory

- All new code must have corresponding unit tests
- `swift test` must pass with zero failures before PR submission
- New modules need at minimum: basic load test, check count test, key check validation

### Test Structure

```swift
import Testing
@testable import MacAuditCore

@Test func MyModuleLoads() async throws {
    let module = MyModule()
    let checks = module.checks(for: .macBookPro, arch: .arm64)
    #expect(checks.count > 0)
}
```

### Testing Levels

| Level | Description | Required |
|-------|-------------|----------|
| Unit tests | Per-module check logic | Yes |
| Fix-Roundtrip | break→detect→fix→verify | For new fix commands |
| Dual-copy sync | MacAudit ↔ MacAuditCore consistency | For shared components |
| Cross-platform | macOS 15 + macOS 26 behavior | For OS-sensitive checks |

### Running Tests

```bash
swift test                              # All tests
swift test --filter FixEngineTests      # Specific suite
bash scripts/build_app.sh               # Verify full build
```

## Pull Request Process

### Before Submitting

1. **Fork** the repository and create a feature branch
2. **Build** passes: `swift build -c debug` with zero warnings
3. **Tests** pass: `swift test` with zero failures
4. **Code style** follows conventions above
5. **Dual-copy sync** verified if touching shared code

### PR Template

```markdown
## Description
Brief description of changes

## Type
- [ ] Bug fix
- [ ] New feature
- [ ] Module addition
- [ ] Performance improvement
- [ ] Documentation

## Testing
- [ ] Unit tests added/updated
- [ ] `swift test` passes
- [ ] Tested on macOS 15 / 26 (specify)

## Checklist
- [ ] Dual-copy files synced (if applicable)
- [ ] Fix commands have undo support (if applicable)
- [ ] Priority explicitly set on new checks
```

### Review Process

1. Automated build & test verification
2. Code review by maintainers
3. For significant changes: 3-round review (architecture → edge cases → final verification)

## Reporting Issues

### Bug Reports

Please include:
- macOS version and architecture (`sw_vers` + `uname -m`)
- MacAudit version (`MacAudit --version` or check `MacAudit.swift`)
- Module and check ID if applicable (e.g., `m4.diagnostics`)
- Expected vs actual behavior
- Output of `MacAudit --self-test`

### Feature Requests

- Describe the security/performance gap the feature addresses
- Suggest which module it belongs to
- Provide the `defaults`/`sysctl`/shell command if known

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
