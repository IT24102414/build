# BuildWise: four-student component ownership and evidence review

Reviewed against assignment section 3 on 5 October 2026. This document explains the work in ordinary project terms and identifies what each student needs to demonstrate. It is an evidence review and proposed ownership map, not a signed claim of personal authorship.

## How the group is organised

BuildWise follows a material from the initial request to purchasing, delivery and inspection. Each student takes responsibility for one stage, including its API, database records, React interface, Flutter interface, tests and domain agent. Integration, review and documentation are shared tasks, but they do not replace an individual's technical component.

| Student | Proposed primary component | Distinct domain agent |
|---|---|---|
| 1 — Peiris DPSS, ID to confirm | A: material request and approval | Request assessment agent |
| 2 — Theebika, IT24102414, full registered name to confirm | B: procurement | Quotation analysis agent |
| 3 — Ramya, IT24102513, full registered name to confirm | C: delivery and receiving | Delivery discrepancy agent |
| 4 — Anoja, ID to confirm | D: quality inspection and NCR | Quality risk agent |

These assignments follow the existing project documentation. The team must confirm them. None of the four positions is a project-manager-only, testing-only or documentation-only role. Business roles such as Procurement Manager are application users, not student contribution roles.

## Student 1 — material request and approval

This component starts the lifecycle. A site engineer describes the material needed for a project, including quantity and justification. A site manager reviews the request before it becomes purchasing work. The owner needs to explain why invalid requests are refused and why one user cannot approve or read records outside their permissions.

| Required evidence | Repository implementation |
|---|---|
| Backend | backend/BuildWise.Api/Controllers/MaterialRequestsController.cs; request service and approval logic |
| Database | MaterialRequest, MaterialRequestItem, MaterialRequestHistory and Approval entities; related EF migrations |
| React | web/buildwise-web/src/pages/MaterialRequestsPage.jsx; approval interface |
| Flutter | mobile/buildwise_mobile/lib/features/operations/screens/material_requests_screen.dart; approvals_screen.dart |
| Tests | MaterialRequestServiceTests.cs; MaterialRequestsPage.test.jsx; material_requests_test.dart; test_request_agent.py |
| Agentic AI | backend/agent_service/request_agent.py; request assessment called through the API |
| Documentation | Component A section in the consolidated report and individual log appendix |
| Git ownership | Personal attribution still requires evidence; no distinct Peiris author appeared in the reachable HEAD shortlog reviewed |

Business work beyond CRUD includes request submission, assessment and approval. Show request creation, own-request retrieval, detail retrieval and approval, and explain the corresponding route permissions. Demonstrate that an alphanumeric material such as Cement 50kg is accepted while invalid quantities and missing required information are rejected.

Student contribution statement to complete: describe the exact API, database, screen, test and agent functions you personally implemented or substantially changed. Identify shared fixes separately. If commits were made through a teammate's account, explain that openly and provide authentic review, issue or other corroborating evidence; do not create backdated history.

Viva preparation: explain a request-to-approval trace, the foreign keys joining request lines to materials, role checks, the request agent's inputs/outputs, and one real bug you fixed. Be ready to modify a validation rule and run a relevant test.

## Student 2 — procurement

This component turns an approved request into a purchasing decision. The procurement officer records supplier quotations and requests analysis. The manager reviews the validated recommendation and approves, rejects or requests revision. A successful approval creates a confirmed purchase order through the backend transaction.

| Required evidence | Repository implementation |
|---|---|
| Backend | SuppliersController.cs, RfqsController.cs, QuotationsController.cs, ProcurementWorkflowController.cs and PurchaseOrdersController.cs |
| Database | Supplier, Rfq, Quotation, PurchaseOrder and workflow/step/approval entities; EF mappings and migrations |
| React | Features/procurement/pages/RequestWorkspace.jsx; QuotationEntryForm.jsx, QuotationComparisonView.jsx and ProcurementApprovalPanel.jsx |
| Flutter | quotation_entry_screen.dart, quotation_comparison_screen.dart, suppliers_screen.dart, rfq_screen.dart and purchase_orders_screen.dart |
| Tests | ProcurementValidationServiceTests.cs; ProcurementPlanningAgentServiceTests.cs; procurement React tests; quotation_entry_test.dart; test_quotation_agent.py |
| Agentic AI | backend/agent_service/quotation_agent.py; backend planning, controlled tools, validation and human approval workflow |
| Documentation | Component B report section, ADRs and Theebika AI log appendix |
| Git ownership | Theebika/IT24102414 authors are present; file-level attribution must distinguish procurement work from shared integration commits |

The owner should demonstrate four meaningful procurement operations and the analysis/decision operation beyond CRUD. Explain supplier eligibility, quantities, price comparison, budget checks, workflow state and why the officer cannot approve their own recommendation. Show the confirmed PO becoming available to receiving.

Student contribution statement to complete: identify personally written supplier/RFQ/quotation logic, EF changes, React/Flutter UI, tests and agent orchestration. Do not claim every shared cross-platform maintenance change as procurement-only work.

Viva preparation: trace a quotation through analysis to an authorized decision, explain how invalid recommendations are rejected, and show what happens if the agent or SMTP provider fails. Explain the measured quotation-agent latency failure rather than describing every performance target as passed.

## Student 3 — delivery and receiving

This component records what actually arrives at the construction site. It connects a confirmed purchase order to received items, damage and shortages. The stored receiving quantities become the reference used by inspection, so a mistake here would affect the next component as well.

| Required evidence | Repository implementation |
|---|---|
| Backend | backend/BuildWise.Api/Controllers/DeliveriesController.cs; delivery and discrepancy services |
| Database | Delivery, DeliveryItem, DeliveryIssue, DeliveryEvidence and DeliverySchedule entities; order relationships and EF migrations |
| React | web/buildwise-web/src/pages/DeliveriesPage.jsx and DeliveriesPage.css |
| Flutter | mobile/buildwise_mobile/lib/features/operations/screens/delivery_receiving_screen.dart |
| Tests | DeliveryServiceTests.cs; DeliveryAgentServiceTests.cs; DeliveriesPage.test.jsx; delivery_receiving_test.dart; test_delivery_agent.py |
| Agentic AI | backend/agent_service/delivery_agent.py; discrepancy analysis routed through the API |
| Documentation | Component C report section and Ramya AI log appendix |
| Git ownership | Ranjanaramya and IT24102513 authors are present; inspect their commits and changed files before making personal claims |

Meaningful operations include confirmed-order retrieval, delivery listing/creation, issue retrieval and discrepancy analysis. The owner must explain ordered versus received versus damaged quantities, supplier/material DTO fields and how persisted receiving data is read by quality inspection.

Student contribution statement to complete: identify the receiving endpoints, entity mappings, both client interfaces, discrepancy agent work and regression tests you personally completed. State which integration changes were shared with procurement or quality.

Viva preparation: record a delivery with a shortage, inspect the persisted issue and agent result, and demonstrate an invalid receiving input. Explain why a UI label must follow the actual DTO rather than an assumed nested object.

## Student 4 — quality inspection and NCR

This component checks whether delivered material is acceptable and records what needs follow-up. The inspector enters quantities, checklist results, notes and evidence. The backend creates an NCR when rejected quantity is positive and prevents invalid resolution transitions.

| Required evidence | Repository implementation |
|---|---|
| Backend | backend/BuildWise.Api/Controllers/QualityInspectionsController.cs; inspection/NCR services |
| Database | Inspection, InspectionItem, InspectionEvidence and NonConformance entities; delivery/material relationships and EF migrations |
| React | QualityInspectionsPage.jsx; NonConformancesPage.jsx; quality checklist, evidence and risk components |
| Flutter | mobile/buildwise_mobile/lib/features/operations/screens/quality_inspection_screen.dart, including NCR view |
| Tests | QualityInspectionServiceTests.cs; QualityInspectionsPage.test.jsx; quality_inspection_test.dart; test_quality_agent.py |
| Agentic AI | backend/agent_service/quality_agent.py; inspection-risk assessment called through the API |
| Documentation | Component D report section and Anoja AI log appendix |
| Git ownership | Anoja and anoja-builds authors are present; verify which component files each commit actually changed |

The owner must demonstrate creation/list/detail/risk-analysis operations and an NCR transition. Explain accepted + rejected = inspected, received-quantity limits, delivery/material membership, notes for failed checklist items, rejection reasons and the ten-file/10 MB evidence limits. NCR creation is a deterministic backend rule, not an optional AI decision.

Student contribution statement to complete: identify personally implemented validation, NCR transitions, EF relationships, React/Flutter evidence UI, tests and quality-agent functions. Confirm the camera/gallery behavior on a real installed device before claiming hardware verification.

Viva preparation: show zero rejection producing no NCR, positive rejection creating an NCR, and a forbidden or unresolved transition being rejected. Explain one failing test and the change that corrected it.

## What the current evidence establishes

All four component implementations have identifiable backend, relational data, React, Flutter, test and agent files. The project therefore has the technical breadth required for four primary components. This does not prove that each named student personally wrote all the work in their section.

The reachable HEAD history contains author identities for Theebika, Anoja and Ramya, including aliases. A distinct Peiris identity was not found in that history. Author aliases and commit counts must not be treated as four independently verified ownership records. Pull-request review and issue ownership have not been independently verified in this review.

The recorded group test results are 307 backend, 28 Python, 163 React and 149 Flutter passes, followed by focused mobile checks. Do not divide these totals by four to invent individual test counts. Each owner should run their focused suite and preserve its actual output.

## Evidence each student supplies before signing

1. Confirm registered name, ID and primary component.
2. Provide real commit links and describe the changed functions, including shared work. Add actual PR/review and issue links if available; otherwise state that evidence is unavailable.
3. Show backend, database, React, Flutter and distinct agent work in the component. Explain at least four API operations and one business operation beyond CRUD.
4. Preserve a positive and negative test run and one complete component demonstration. Explain fixtures, expected outcomes and limitations.
5. Correct the existing AI log using actual dates, tools/models, outputs, changes/rejections and verification. Add only work that really happened.
6. Write approximately one page of personal reflection in your own words. Discuss useful and incorrect AI output, your corrections and what you learned. The specification does not award credit for an AI-generated personal reflection.
7. Sign the declaration after checking the claims. Use actual dates and your own signature.

An appropriate final contribution statement reads naturally because it describes specific work: what you changed, why it was needed, how you tested it and where the evidence is. Replace vague claims such as 'I did the whole component' with genuine, attributable examples. No student is assigned invented experiences or signatures by this document.

## Recorded component Git examples

These are current HEAD path histories, not verified personal ownership. Preserve the recorded author when citing them.

### Component A

```
c318c46 | Loganathan Theebika | Complete field mobile workspaces: approvals, review, PO, quotation entry, RBAC, validation UX
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
9466c5e | Loganathan Theebika | feat: complete procurement and operations workflow
```

### Component B

```
4e09d1c | Loganathan Theebika | Align React and Flutter workflows and refresh SE3090 submission documentation
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
9466c5e | Loganathan Theebika | feat: complete procurement and operations workflow
```

### Component C

```
4e09d1c | Loganathan Theebika | Align React and Flutter workflows and refresh SE3090 submission documentation
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
9466c5e | Loganathan Theebika | feat: complete procurement and operations workflow
```

### Component D

```
c318c46 | Loganathan Theebika | Complete field mobile workspaces: approvals, review, PO, quotation entry, RBAC, validation UX
9ab414f | IT24102414 | feat: RBAC hardening, supplier portal, budget validation and C1-C4 coverage
9466c5e | Loganathan Theebika | feat: complete procurement and operations workflow
```

Use https://github.com/IT24102414/build/commit/ followed by the actual hash. A commit inherited from another repository may mention a PR there; do not manufacture a matching PR URL in this repository.
