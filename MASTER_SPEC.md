# BuildWise — Master Specification (SE3090 Assignment 1)

## 📌 Project Overview
**Title:** BuildWise – Intelligent Construction Supply Chain, Budget Tracking & Quality Management Platform  
**Academic Context:** SLIIT SE3090 Software Engineering Frameworks (Year 3 Semester 1, 2026)  
**Allocation:** 4 Students (Equal Full-Stack + Agentic AI Distribution across 7 Rubric Criteria)

---

## 🏗️ Domain & Real-World Construction Problem
Large-scale infrastructure and residential construction projects encounter recurring challenges:
1. **Material Requisitions:** On-site delays and lack of lead time planning.
2. **Procurement & Bidding:** Complex multi-vendor comparisons, opaque supplier pricing, and unapproved budget overruns.
3. **Logistics & Delivery:** Short deliveries, off-schedule transit, and undocumented material loss at the gate.
4. **Quality & Non-Conformance:** Substandard raw materials (cement, rebar, aggregates) installed without verifiable QA records.

BuildWise digitizes this entire lifecycle through an integrated ASP.NET Core backend, PostgreSQL database, React web portal, Flutter mobile field client, and a 4-agent AI microservice mesh.

---

## 📐 End-to-End Workflow Architecture

```text
[Flutter: Site Engineer]
        │
        ▼ Create Material Request #46
[ASP.NET Core Gateway] ────► [PostgreSQL: MaterialRequests]
        │
        ▼ (Port 8002)
[Request Planning Agent] ───► Evaluates Lead Time & Schedule
        │
        ▼ RFQ Dispatch
[React: Procurement Officer] ──► Solicits 3 Vendor Quotes
        │
        ▼ (Port 8001)
[Vendor Analysis Agent] ────► Evaluates Price, Reliability & Lead Time
        │
        ▼ Selected Quotation: Insee Cement (LKR 1,090,000)
[Budget Validation Agent] ──► Budget Overrun Detected (+LKR 90,000)
        │
        ▼ Workflow State: PAUSED_FOR_APPROVAL
[React: Procurement Manager] ──► Human-in-the-Loop Sign-off
        │
        ▼ Issue PO-46
[Flutter: Site Officer] ───► Scan QR & Capture Receipt Photo
        │
        ▼ Material Batch DEL-30
[React / Mobile: Quality Inspector] ──► 5-Point QA Checklist (INS-36)
        │
        ▼ 30 Torn Bags (Defect > 5%)
[Quality Risk Analysis Agent] ──► (Port 8004) Risk: HIGH -> Suggests NCR
        │
        ▼
[PostgreSQL: NonConformances] ──► NCR-104 Created & Supplier Email Sent
```

---

## 🗄️ Relational Database Entity Schema (PostgreSQL)

- **Auth & Access:** `Users`, `Roles`, `UserRoles`, `AuditLogs`, `NotificationEvents`
- **Projects & Core:** `Projects`, `Materials`, `Suppliers`, `SupplierContacts`
- **Requisition:** `MaterialRequests`, `MaterialRequestItems`, `MaterialRequestHistories`, `Approvals`
- **Procurement:** `Rfqs`, `RfqSuppliers`, `Quotations`, `QuotationItems`, `PurchaseOrders`, `PurchaseOrderItems`
- **Logistics & Receiving:** `Deliveries`, `DeliveryItems`, `DeliveryIssues`, `DeliveryEvidences`, `DeliverySchedules`
- **Quality & NCR:** `Inspections`, `InspectionItems`, `InspectionEvidences`, `NonConformances`
- **Agentic AI State:** `AgentWorkflows`, `AgentWorkflowSteps`, `AgentApprovals`

---

## 🔒 Security, RBAC & Third-Party Services

- **Authentication:** Stateless JWT bearer tokens with standard expiration and refresh cycle.
- **Role Hierarchy:**
  1. `Administrator`: Global tenant management, user provisioning, and audit logs.
  2. `SiteEngineer`: Requisition authoring, project-bound view access.
  3. `SiteManager`: Multi-project requisition approval and site oversight.
  4. `ProcurementOfficer`: RFQ lifecycle, vendor quotation registration.
  5. `ProcurementManager`: Purchase order issuance and budget variance approval gate.
  6. `SiteOfficer`: Delivery gate reception and discrepancy logging.
  7. `QualityInspector`: Quality checklist audits and NCR creation.
- **Third-Party Integrations:** SMTP Transactional Email Service (`SmtpEmailService.cs`) dispatched on quotation solicitations, PO sign-offs, and critical NCR generation.
