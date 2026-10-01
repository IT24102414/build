# Component 2 — Supplier, Quotation, RFQ & Procurement Management
**Student:** Theebika · **ID:** IT24102414
**Your primary ownership:** Suppliers, Quotations, RFQs, Procurement Workflow, 4 AI Agents

## What you submit
- ackend/BuildWise.Api/Controllers/Suppliers|Quotations|Rfqs|ProcurementWorkflow|PurchaseOrders|SupplierPortalController.cs
- ackend/agent_service/quotation_agent.py — the main AI agent (Python)
- ackend/BuildWise.Api.Tests/Procurement*Tests.cs — your unit tests
- web/buildwise-web/src/Features/procurement/ — all React procurement UI
- mobile/.../features/procurement/ — Flutter procurement screens
- docs/reports/IT24102414-ai-usage-log.md — your AI usage log

## Run & verify your component
```powershell
powershell -File scripts/start-dev.ps1          # start all services
powershell -File scripts/verify-component2.ps1  # verify all C2 checks
powershell -File scripts/verify-planning-agent.ps1
```

## Test
```powershell
dotnet test backend/BuildWise.Api.Tests/BuildWise.Api.Tests.csproj
cd backend/agent_service && pytest -q
cd web/buildwise-web && npm test -- --run
```

## Install APK on Android phone (same WiFi as this PC)
1. Enable "Install unknown apps" on your phone
2. Transfer mobile/.../flutter-apk/app-release.apk to your phone and install
3. API is at http://10.110.168.34:5078 (PC must be on same WiFi)
