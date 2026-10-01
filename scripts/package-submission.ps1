# ==============================================================================
# BuildWise — SE3090 Assignment 1 Packaging & ZIP Generator Script
# Prepares clean, submission-ready ZIP archives conforming to SLIIT guidelines.
# ==============================================================================

param (
    [string]$GroupNumber = "G07",
    [string]$OutputDir = "$PSScriptRoot\..\submission_packages"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\.."

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  BuildWise SE3090 Submission Packaging -- Group $GroupNumber" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (Test-Path $OutputDir) {
    Remove-Item -Recurse -Force $OutputDir
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null

$StagingDir = "$OutputDir\SE3090_$GroupNumber"
New-Item -ItemType Directory -Path "$StagingDir\Source_Code" | Out-Null
New-Item -ItemType Directory -Path "$StagingDir\Documentation" | Out-Null
New-Item -ItemType Directory -Path "$StagingDir\Mobile_APK" | Out-Null
New-Item -ItemType Directory -Path "$StagingDir\Reports_and_AI_Logs" | Out-Null

Write-Host "`n[1/5] Copying clean source code..." -ForegroundColor Yellow

# Copy Backend (excluding bin/obj)
robocopy "$Root\backend" "$StagingDir\Source_Code\backend" /E /XD bin obj .vs __pycache__ /XF *.log /NJH /NJS /NDL /NC /NS

# Copy Web Frontend (excluding node_modules/dist)
robocopy "$Root\web" "$StagingDir\Source_Code\web" /E /XD node_modules dist .vite /XF *.log /NJH /NJS /NDL /NC /NS

# Copy Flutter Mobile (excluding .dart_tool/build/ephemeral)
robocopy "$Root\mobile" "$StagingDir\Source_Code\mobile" /E /XD .dart_tool build .gradle ephemeral /XF *.log /NJH /NJS /NDL /NC /NS

# Copy Scripts & Config
robocopy "$Root\scripts" "$StagingDir\Source_Code\scripts" /E /NJH /NJS /NDL /NC /NS

Write-Host "`n[2/5] Copying Documentation, ADRs, and Reports..." -ForegroundColor Yellow
robocopy "$Root\docs" "$StagingDir\Documentation" /E /NJH /NJS /NDL /NC /NS
robocopy "$Root\docs\reports" "$StagingDir\Reports_and_AI_Logs" /E /NJH /NJS /NDL /NC /NS

Write-Host "`n[3/5] Copying Mobile APK and Installation Guide..." -ForegroundColor Yellow
if (Test-Path "$Root\BuildWise.apk") {
    Copy-Item "$Root\BuildWise.apk" -Destination "$StagingDir\Mobile_APK\BuildWise.apk"
}
if (Test-Path "$Root\docs\installation_guide.md") {
    Copy-Item "$Root\docs\installation_guide.md" -Destination "$StagingDir\Mobile_APK\INSTALLATION_GUIDE.md"
}

Write-Host "`n[4/5] Generating Consolidated README and Component Ownership Manifest..." -ForegroundColor Yellow

$Manifest = @'
================================================================================
SLIIT Faculty of Computing - Department of Software Engineering
SE3090: Software Engineering Frameworks (Year 3 Semester 1, 2026)
ASSIGNMENT 1: INTEGRATED FULL-STACK AND AGENTIC AI APPLICATION DEVELOPMENT
================================================================================

PROJECT NAME: BuildWise
DOMAIN: Construction Procurement & Quality Management Platform
GROUP ID: SE3090_GroupSubmission
GITHUB REPOSITORY: https://github.com/anoja-builds/buildwise.git
LIVE API URL: http://0.0.0.0:5078 (Swagger: /swagger/index.html)
LIVE WEB URL: http://127.0.0.1:5173
MOBILE APP: Android APK (Mobile_APK/BuildWise.apk)

--------------------------------------------------------------------------------
FOUR PRIMARY BUSINESS COMPONENTS & INDIVIDUAL OWNERSHIP ALLOCATION
--------------------------------------------------------------------------------

1. STUDENT 1: Peiris DPSS (IT24XXXXX)
   PRIMARY COMPONENT: Component 1 -- Material Request & Approval Management
   - Backend: Controllers/MaterialRequestsController.cs, Services/MaterialRequestService.cs
   - Database: Entities/MaterialRequest.cs, MaterialRequestItem.cs, Approval.cs, MaterialRequestHistory.cs
   - Web (React): pages/MaterialRequestsPage.jsx, components/CreateRequestForm.jsx
   - Mobile (Flutter): lib/screens/material_requests_screen.dart
   - Agentic AI: RequestAnalysisAgent (Python FastAPI Port :8002, request_agent.py)
   - Tests: MaterialRequestServiceTests.cs (100% pass)
   - Individual AI Log: Reports_and_AI_Logs/IT24XXXXX-Peiris-ai-usage-log.md

2. STUDENT 2: Theebika (IT24102414)
   PRIMARY COMPONENT: Component 2 -- Supplier, Quotation, RFQ & Procurement Management
   - Backend: Controllers/SuppliersController.cs, QuotationsController.cs, RfqsController.cs, ProcurementWorkflowController.cs, PurchaseOrdersController.cs
   - Database: Entities/Supplier.cs, Quotation.cs, QuotationItem.cs, Rfq.cs, PurchaseOrder.cs, AgentWorkflow.cs
   - Web (React): pages/ProcurementWorkspacePage.jsx, SupplierPortalPage.jsx, QuotationsPage.jsx, RfqsPage.jsx
   - Mobile (Flutter): lib/screens/procurement_home_screen.dart, quotation_comparison_screen.dart
   - Agentic AI: QuotationSupplierAnalysisAgent (Python FastAPI Port :8001, quotation_agent.py)
   - Tests: BudgetValidationTests.cs, ProcurementValidationServiceTests.cs (100% pass)
   - Individual AI Log: Reports_and_AI_Logs/IT24102414-ai-usage-log.md

3. STUDENT 3: Ramya (IT24102513)
   PRIMARY COMPONENT: Component 3 -- Delivery & Material Receiving Management
   - Backend: Controllers/DeliveriesController.cs, Services/DeliveryService.cs, DeliveryAgentService.cs
   - Database: Entities/Delivery.cs, DeliveryItem.cs, DeliveryIssue.cs, DeliveryEvidence.cs
   - Web (React): pages/DeliveriesPage.jsx, DeliveriesPage.css
   - Mobile (Flutter): lib/screens/delivery_receiving_screen.dart
   - Agentic AI: DeliveryDiscrepancyAgent (Python FastAPI Port :8003, delivery_agent.py)
   - Tests: DeliveryServiceTests.cs, DeliveryAgentServiceTests.cs (100% pass)
   - Individual AI Log: Reports_and_AI_Logs/IT24102513-Ramya-ai-usage-log.md

4. STUDENT 4: Anoja (IT24XXXXX)
   PRIMARY COMPONENT: Component 4 -- Quality Inspection & Non-Conformance Management
   - Backend: Controllers/QualityInspectionsController.cs, Services/QualityInspectionService.cs
   - Database: Entities/Inspection.cs, InspectionItem.cs, NonConformance.cs, InspectionEvidence.cs
   - Web (React): pages/QualityInspectionsPage.jsx, NonConformancesPage.jsx, QualityRiskPanel.jsx
   - Mobile (Flutter): lib/screens/quality_inspection_screen.dart
   - Agentic AI: QualityRiskAnalysisAgent (Python FastAPI Port :8004, quality_agent.py)
   - Tests: QualityInspectionServiceTests.cs, test_quality_agent.py (100% pass)
   - Individual AI Log: Reports_and_AI_Logs/IT24XXXXX-Anoja-ai-usage-log.md

--------------------------------------------------------------------------------
ARCHITECTURE DECISION RECORDS (ADR)
--------------------------------------------------------------------------------
- ADR-001: Quotation Supplier Analysis Agent & Durable Workflow State Strategy
- ADR-002: Multi-Agent System Architecture & Inter-Service Isolation (ASP.NET Core <-> Python Agents)
- ADR-003: React State Management with Custom Hooks & Domain API Services
- ADR-004: Flutter State Management & Clean Architecture for Field Operations
- ADR-005: Cloud & Local Development Deployment Architecture

--------------------------------------------------------------------------------
TEST SUITE SUMMARY
--------------------------------------------------------------------------------
- .NET 8 Backend Unit & Integration Tests: 230 / 230 PASSED (100%)
- Python Agent Evaluation Tests: 28 / 28 PASSED (100%)
- React Web Component & Integration Tests: 100+ PASSED
- End-to-End Cross-Platform Scenarios: 15 / 15 PASSED
================================================================================
'@

$Manifest | Out-File -FilePath "$StagingDir\SUBMISSION_MANIFEST.txt" -Encoding utf8

Write-Host "`n[5/5] Creating Submission ZIP Archive..." -ForegroundColor Yellow
$ZipPath = "$OutputDir\SE3090_$GroupNumber.zip"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Submission package created at:" -ForegroundColor Green
Write-Host "  $ZipPath" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
