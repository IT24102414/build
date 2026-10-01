# BuildWise — Final Submission Checklist (SE3090 Assignment 1)

**Group ID:** `SE3090_G07`  
**Target Deadline:** 2026-10-01  
**Project:** BuildWise – Construction Procurement & Quality Platform

---

## 📋 1. CourseWeb Submission Files Checklist

| Item | File / Directory | Status | Notes |
| :--- | :--- | :---: | :--- |
| **Group Master ZIP** | `submission_packages/SE3090_G07.zip` | [x] | 36.0 MB cleanly packaged without node_modules/bin/obj. |
| **Consolidated PDF Report** | `docs/reports/SE3090_G07_BuildWise_Final_Report.pdf` | [x] | Complete with Architecture, ERD, ADRs, and 4 student sections. |
| **Android Release APK** | `mobile/buildwise_mobile/build/app/outputs/flutter-apk/app-release.apk` | [x] | Standalone APK ready for phone testing. |
| **Student 1 ZIP** | `submissions/Component1-Peiris-MaterialRequest.zip` | [x] | 24.7 MB package for Peiris DPSS. |
| **Student 2 ZIP** | `submissions/Component2-IT24102414-Theebika-Procurement.zip` | [x] | 24.8 MB package for Theebika (`IT24102414`). |
| **Student 3 ZIP** | `submissions/Component3-IT24102513-Ramya-Delivery.zip` | [x] | 24.7 MB package for Ramya (`IT24102513`). |
| **Student 4 ZIP** | `submissions/Component4-Anoja-QualityInspection.zip` | [x] | 24.7 MB package for Anoja. |

---

## 🧪 2. Automated Test Execution Checklist

- [x] **Backend .NET 8 Tests:** `dotnet test backend/BuildWise.Api.Tests/BuildWise.Api.Tests.csproj` (230 / 230 passed)
- [x] **Python Agent Tests:** `cd backend/agent_service && pytest -v` (28 / 28 passed)
- [x] **React Vitest Suite:** `cd web/buildwise-web && npm test -- --run` (109 / 109 passed)
- [x] **Flutter Mobile Tests:** `cd mobile/buildwise_mobile && flutter test` (4 / 4 passed)
- [x] **Total Test Count:** **371 / 371 Automated Tests Passing (100% Success Rate)**

---

## 📑 3. AI Usage & Academic Integrity Checklist

- [x] Group AI Usage Declaration signed by all 4 members (`docs/reports/GROUP-ai-usage-declaration.md`).
- [x] Student 1 AI Usage Log completed (`docs/reports/IT24XXXXX-Peiris-ai-usage-log.md`).
- [x] Student 2 AI Usage Log completed (`docs/reports/IT24102414-ai-usage-log.md`).
- [x] Student 3 AI Usage Log completed (`docs/reports/IT24102513-Ramya-ai-usage-log.md`).
- [x] Student 4 AI Usage Log completed (`docs/reports/IT24XXXXX-Anoja-ai-usage-log.md`).
- [x] 5 Formal ADRs documented in `docs/adr/` (`0001` through `ADR-005`).
