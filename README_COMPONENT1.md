# Component 1 — Material Request & Approval Management
**Student:** Peiris DPSS
**Your primary ownership:** Material Request lifecycle, multi-level approvals, RBAC, SMTP notifications

## What you submit
- ackend/BuildWise.Api/Controllers/MaterialRequestsController.cs — your main controller
- ackend/BuildWise.Api/Services/MaterialRequestService.cs — business logic
- ackend/BuildWise.Api.Tests/MaterialRequestServiceTests.cs — your unit tests
- web/buildwise-web/src/pages/MaterialRequestsPage.jsx — your React page
- mobile/.../features/material_requests/ — your Flutter screens
- docs/reports/IT24XXXXX-Peiris-ai-usage-log.md — your AI usage log

## Run the system
1. Copy .env.example → .env and fill in your DB password
2. Run: powershell -File scripts/start-dev.ps1
3. Web: http://localhost:5173 | API: http://localhost:5078 | Swagger: http://localhost:5078/swagger

## Test your component
```powershell
dotnet test backend/BuildWise.Api.Tests/BuildWise.Api.Tests.csproj --filter "MaterialRequest|Rbac|FullLifecycle"
```

## Install APK on Android phone (same WiFi as this PC)
1. Enable "Install unknown apps" on your phone
2. Transfer mobile/buildwise_mobile/build/app/outputs/flutter-apk/app-release.apk to your phone
3. Open the APK file on your phone to install
4. API is running at http://10.110.168.34:5078 (your PC must be on)
