# Reference Documents Index

> Complete catalog of all research, analysis, testing, and audit documents for MacAudit.

## Directory Structure

```
docs/references/
├── README.md                      ← This file
├── FEATURE_SPEC.md                ← Molecular-level feature specification (all 12 modules)
├── security/                      ← Security hardening & configuration
├── claude_protection/             ← Claude Code protection & AI service compatibility
├── optimization/                  ← macOS performance optimization (per-OS)
├── dev_environment/               ← Development environment setup (per-OS)
├── audit_reports/                 ← Original audit reports & analysis
├── expert_audits/                 ← Multi-round expert code review documents
├── testing/                       ← Test plans, reports, VM validation results
└── articles/                      ← External research articles
```

---

## Security (`security/`)

| File | Description |
|------|-------------|
| `Mac_System_Optimization_Guide.md` | macOS system security hardening guide (3rd edition final) |
| `Surge_Optimization_Guide.md` | Surge proxy configuration optimization guide (2nd edition) |
| `Surge_Config_Checklist.md` | Complete Surge proxy configuration checklist derived from MacAudit rules, including .conf template and verification script |

## Claude Protection (`claude_protection/`)

| File | Description |
|------|-------------|
| `Claude_Protection_Guide.md` | 6-layer defense guide v1.1 (L1 Surge → L6 Sandbox) |
| `Claude_Protection_Audit.md` | 8-dimension 40+ item audit (P0/P1/P2 risk levels) |
| `Claude_Protection_Research.md` | GitHub Issues + community deep research |
| `2026-04-25_Claude_Protection_Analysis.md` | Analysis: 34/397 checks (8.6%) have direct Claude value |
| `MacAudit_调优方案变更说明.md` | Philosophy shift v0.1.3→v0.1.4: "disappearance" → "integration" strategy |

## Performance Optimization (`optimization/`)

| File | Description |
|------|-------------|
| `Mac_Perf_Optimize_Tahoe_26.md` | macOS 26 Tahoe M4 Max performance optimization (includes Claude protection section) |
| `Mac_Perf_Optimize_Sequoia_15.md` | macOS 15 Sequoia M4 Max performance optimization |
| `Mac_Perf_Optimize_Ventura_13.md` | macOS 13 Ventura Intel i9 performance optimization |
| `Mac_Performance_Optimization_Guide.md` | General macOS performance optimization guide |

## Development Environment (`dev_environment/`)

| File | Description |
|------|-------------|
| `Dev_Environment_Tahoe_26.md` | macOS 26 Tahoe dev setup (10 chapters + Brewfile) |
| `Dev_Environment_Sequoia_15.md` | macOS 15 Sequoia dev setup (with compatibility notes) |
| `Dev_Environment_Ventura_13.md` | macOS 13 Ventura dev setup |

## Audit Reports (`audit_reports/`)

| File | Description |
|------|-------------|
| `Mac_Audit_Report.md` | Original system audit report |
| `Sequoia分析.md` | Sequoia vs Tahoe difference analysis |
| `mac_audit_readme.md` | Audit report index and collection guide |

## Expert Audits (`expert_audits/`)

### Penta Expert Audit (5 Experts × 5 Rounds = 29 documents)

| Expert | Persona | Files |
|--------|---------|-------|
| Expert 1 | Steve Krug (UX) | `EXPERT1_UX_KRUG_ROUND1.md` → `ROUND5.md` |
| Expert 2 | Robert C. Martin (Clean Code) | `EXPERT2_CLEAN_CODE_BOB_ROUND1.md` → `ROUND5.md` |
| Expert 3 | Don Norman (Design) | `EXPERT3_DESIGN_NORMAN_ROUND1.md` → `ROUND5.md` |
| Expert 4 | Edsger Dijkstra (Logic) | `EXPERT4_LOGIC_DIJKSTRA_ROUND1.md` → `ROUND5.md` |
| Expert 5 | Kent Beck (TDD) | `EXPERT5_TDD_BECK_ROUND1.md` → `ROUND5.md` |
| Synthesis | Combined | `SYNTHESIS_REPORT_PART1.md` → `PART4.md` |

### Triple Expert Audit Round 2 (112 Swift files)

| File | Description |
|------|-------------|
| `TRIPLE_EXPERT_AUDIT_R2.md` | Expert A (Cryptographer) + Expert B (Systems Engineer) + Expert C (UX Anthropologist) — exit on 3 consecutive zero-finding cycles |

## Testing (`testing/`)

### Test Plans & Reports

| File | Description |
|------|-------------|
| `TAHOE_REAL_MACHINE_TEST_REPORT.md` | Real machine test on macOS 26.4.1 Tahoe (Intel x86_64): 7 categories, 70 test points, 100% pass |
| `TAHOE26_PHYSICAL_TEST_PLAN.md` | Molecular-level physical test plan: 26 historical crash lessons as constraints |
| `RELEASE_CHECKLIST.md` | v0.2.0 MVP release checklist with A0 scope (~85 checks across 6 modules) |
| `M4_COMPLETION_SUMMARY.md` | Tahoe compatibility fix summary: 9 commits, 89 files, +3,190/-889 lines |
| `M4_REVIEW_REPORT.md` | M4 work plan 5-expert × 3-round review: 21 findings (6 CRITICAL) |
| `M4_WORK_PLAN.md` | Detailed M4 work plan with task breakdown |

### macOS 15 VM Test Results

| File | Description |
|------|-------------|
| `macos15_test_report.md` | M1: 400-check × 3 rounds consistency test |
| `macos15_issues_detail.md` | Detailed issue findings from macOS 15 testing |
| `macos15_vm_environment.md` | VM environment specification |
| `macos15_coverage_gap.md` | Test coverage gap analysis |
| `macos15_final_comprehensive_report.md` | M1 final comprehensive report |

### macOS 26 Tahoe VM Test Results

| File | Description |
|------|-------------|
| `tahoe26_environment.md` | Tahoe 26 VM environment specification |
| `tahoe26_module_stability.md` | 12 modules × 3 rounds consistency verification |
| `tahoe26_fixcmd_issues.md` | 13 FAIL items classification from fixCommand testing |
| `tahoe26_final_report.md` | M2 final comprehensive report |
| `tahoe26_vs_macos15_comparison.md` | Cross-version behavior differences (macOS 15 vs 26) |
| `tahoe26_supplementary_report.md` | M3: 169 supplementary tests |
| `tahoe26_export_report.md` | Markdown export verification report |

## Articles (`articles/`)

| File | Description |
|------|-------------|
| `Claude Code Account ban mechanism exploration.md` | Reverse engineering of Claude Code ban mechanisms: Attribution Headers, Bayesian risk scoring, cch Attestation |
| `Claude-Ban-Experience.md` | Documented ban experiences and recovery procedures |
| `CODEX_ClaudeCode_Risk_Research_2026-04-22.md` | Codex analysis: comprehensive risk factors for AI service accounts |
| `CODEX_ClaudeComplianceAddon_Checklist_2026-04-22.md` | Codex audit: compliance verification checklist for Claude Code |
| `CODEX_ClaudeComplianceAddon_ImplementationPlan_2026-04-22.md` | Codex planning: step-by-step compliance implementation guide |

---

## External References

| Project | URL | Usage |
|---------|-----|-------|
| Lynis | [github.com/CISOfy/lynis](https://github.com/CISOfy/lynis) | Adversarial testing methodology |
| Google Santa | [github.com/google/santa](https://github.com/google/santa) | Mutation testing patterns |
| NIST macOS Security | [github.com/usnistgov/macos_security](https://github.com/usnistgov/macos_security) | Fix-roundtrip verification |
| osquery | [github.com/osquery/osquery](https://github.com/osquery/osquery) | Idempotency + concurrency testing |
| swift-argument-parser | [github.com/apple/swift-argument-parser](https://github.com/apple/swift-argument-parser) | Snapshot comparison testing |
| claudit | [github.com/nicholasaleks/claudit](https://github.com/nicholasaleks/claudit) | Claude security audit methodology |
| Claude Code Ban Research | [github.com/instructkr/claude-code](https://github.com/instructkr/claude-code) | Network traffic analysis, ban mechanism reverse engineering |
