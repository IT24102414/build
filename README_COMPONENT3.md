# Component 3 — Delivery & Material Receiving Management
**Student:** Ramya · **ID:** IT24102513
**Your primary ownership:** Delivery scheduling, receiving, discrepancy detection, DeliveryDiscrepancyAgent

## What you submit
- ackend/BuildWise.Api/Controllers/DeliveriesController.cs — your main controller
- ackend/agent_service/delivery_agent.py — your Python AI agent (port 8003)
- ackend/BuildWise.Api.Tests/DeliveryServiceTests.cs — your unit tests
- web/buildwise-web/src/pages/DeliveriesPage.jsx — your React page
- mobile/.../features/deliveries/ — your Flutter screens
- docs/reports/IT24102513-Ramya-ai-usage-log.md — your AI usage log

## Run & verify
```powershell
powershell -File scripts/start-dev.ps1
powershell -File scripts/verify-full-journey.ps1
```

## Test your component
```powershell
dotnet test backend/BuildWise.Api.Tests/BuildWise.Api.Tests.csproj --filter "Delivery"
cd backend/agent_service && pytest test_delivery_agent.py test_request_agent.py -v
```

## Install APK on Android phone
1. Enable "Install unknown apps" on your phone
2. Transfer mobile/.../flutter-apk/app-release.apk and install
3. API at http://10.110.168.34:5078 (PC must be on same WiFi)
