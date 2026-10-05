# Mobile and web parity review - 5 October 2026

Flutter was reviewed against the React workflows, backend DTOs, routes, and authorization policies. The backend remains responsible for final validation and workflow decisions.

## Changes

- All seven internal roles now land on the backend role dashboard. Metrics, quick-action routes, alerts, activity references, outcomes, and timestamps use the same response fields as React.
- Mobile navigation exposes the appropriate workspaces, including purchase orders for operational readers. Only the visible workspace loads its APIs. The drawer and scrollable navigation support roles with many destinations on smaller screens.
- Request creation and delivery receiving are restricted to site engineers and officers; supplier editing and RFQ creation to procurement officers and administrators. Procurement decisions require an approver. React controls were corrected where they disagreed with these backend policies.
- Quotation entry loads request details rather than relying on summary rows for material lines, excludes inactive suppliers, checks finite quantities and prices, and records transport charges and payment terms.
- Purchase orders read the paged response, provide pagination and details, preserve backend price redaction, and expose supported status transitions to authorized procurement users.
- Suppliers support details, editing, status updates, and complete directory loading across backend pages. RFQs support the backend email DTO and date/supplier validation.
- Administration supports account creation, activation, and role updates through the actual admin endpoints; API failures are surfaced rather than presented as empty successful results.
- Procurement officers can run the quotation agent without gaining human approval permission. Managers can approve, reject, or request revision; revision requires a real comment, and validation errors retain the decision form.
- Agent history supports status filtering, pagination, structured step results, validation findings, timing, final outcomes, and recorded human approvals. Domain analyses use the same four backend routes and extended timeout.
- Quality inspections reset when delivery changes, start with zero rejected quantity, retain the requested inspection/evidence rules, and use legal NCR transitions with required resolutions. Existing NCR resolutions are prefilled for subsequent transitions.
- Delivery history remains visible even when there are no confirmed orders available to receive.
- API origin defaults work for Android emulators, browsers, and desktop. Physical phones still require the server's reachable address via `API_BASE_URL`.

## Verification

| Check | Result |
| --- | --- |
| Flutter unit/widget/API-contract tests | 134 passed |
| React tests | 154 passed across 13 files |
| Backend tests | 302 passed |
| Flutter analysis | No issues found |
| Flutter release web build | Passed |
| React production build | Passed |
| Android debug APK | Blocked by unavailable Flutter engine dependencies |
| Live database and four domain-agent health checks | Healthy |

Backend tests were rerun with permission to access Windows logging and database resources after sandbox restrictions caused environment errors. The successful suite includes authorization and lifecycle validation tests. Added mobile tests cover all seven role dashboards, deferred workspace loading, API response/payload contracts, agent endpoints, history pagination, and procurement decision permissions.

The online APK build stalled downloading Flutter engine artifacts over HTTPS and was stopped after approximately 12 minutes. The offline check reached Android app tasks and confirmed that `io.flutter:armeabi_v7a_debug`, `io.flutter:arm64_v8a_debug`, and `io.flutter:x86_64_debug` for engine revision `af7e796e161ae0bb1ff0758c71a7105418bd9ded` are absent from the Gradle cache. No installable APK was produced. Retry `flutter build apk --debug --no-pub` once these downloads are reachable.

## Material request parity follow-up (5 October 2026)

Flutter's create-request page now sends the selected request date, editable unit, site notes, and optional material specification. It requires site notes and rejects fractional quantities for the same countable-unit vocabulary as React. Both clients enforce the backend's three-day minimum required date. Flutter's request and approval registers support priority filtering and background refresh every 30 seconds and when the application resumes; a failed background refresh preserves the current register. Approval filters include UnderReview and AwaitingProcurementApproval.

Validation after these changes: Flutter analysis reported no issues and all 135 Flutter tests passed, including seven-role dashboard/permission coverage and the new countable-quantity/site-notes regression test. React's 156 tests and production build passed. These checks do not establish pixel-identical rendering or a physical-device walkthrough.

## Practical limits

These results verify the reviewed workflows and contracts; they do not establish that every visual interaction is identical on all devices. No physical-device walkthrough, camera/upload interaction, actual email delivery, or complete live LLM recommendation/approval journey was performed. Agent health verifies reachability; automated mobile tests use controlled service responses. Browser WebAssembly is not supported by the current secure-storage dependency; the regular JavaScript release web build succeeds.

For a physical phone, rebuild with `flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_SERVER:5078/api` and ensure the server is reachable from the phone. The default Android debug build targets the local Android emulator using `10.0.2.2`.

## Browser visual review

Playwright MCP was unavailable in this session. Local Playwright with headless Microsoft Edge was used instead. The reproducible script is `scripts/ui-browser-review.cjs`; screenshots and the machine-readable report are under `artifacts/ui-review`.

The earlier visual pass used explicitly labelled browser fixtures (`--fixtures`) while the running API rejected demo credentials. After the API restarted, all seven documented demo accounts authenticated successfully (HTTP 200). The recorded visual results remain fixture-based: they cover all seven React and Flutter role dashboards, React workspace pages at desktop and phone widths, and selected Flutter workspaces at phone width. The Flutter target is the browser build, not a physical-device run.

Browser findings and corrections:

- Web and Flutter share the blue palette, background, body text, and border colours. The latest visual alignment uses React's single-column phone dashboard layout and matching pastel metric cards.
- Long demo-account email addresses wrap inside their web buttons.
- Grid/card/table constraints prevent phone-width overflow on Suppliers and Administration. Tables retain their own horizontal scrolling.
- Flutter dropdowns expand within their field and truncate long selected labels.
- Flutter supplier search and status filters now provide the same directory operations available on web; a regression test checks combined filtering and clearing filters.
- Dashboard fallback labels are human-readable. Flutter's navigation arrow uses the bundled icon font rather than a missing fallback glyph.
- The React procurement workspace recognizes administrators as approvers, matching backend and Flutter permissions, instead of labelling their account read-only and hiding its approval actions.
- A self-contained Flutter web build resolves the blank preview caused by unavailable renderer CDN resources. Build with `flutter build web --no-pub --no-web-resources-cdn --no-wasm-dry-run` for this environment.

Run the browser review with `npm exec --yes --package=playwright -- node scripts/ui-browser-review.cjs --fixtures`. Without `--fixtures`, the script attempts the live demo accounts and records authentication failures separately. Playwright requires Microsoft Edge, the React server at port 5173, and the Flutter web build. It temporarily serves Flutter at port 8081 and closes its browser/server when finished.

The completed fixture-based pass recorded 49 checks with zero page-width overflows or captured browser/Flutter errors. See `artifacts/ui-review/browser-report.json` for the exact checked targets, roles, viewport widths, and data mode.

## Current React-to-Flutter alignment

The latest visual comparison updates Flutter's shared muted surface and success/warning/error fills to the React theme, and uses React's 17.6px card corners. Dashboard metric cards now show labels above values, a coloured left edge, and the API-source caption; the phone grid uses one column. Quick actions, attention alerts, and recent activity each share a grouped card with the corresponding React subtitle and action labels. Navigation regression checks scroll through the taller cards and continue to assert the actual destination routes. All 142 Flutter tests pass and analysis reports no issues. The subsequent shell update replaces the native bottom navigation and drawer with React-style responsive navigation, and bundles Plus Jakarta Sans with its open font license. The role-filtered menu uses React labels and ordering, including a separate NCR entry; quotation recording is reached from the quotation workspace. Responsive navigation tests cover 390px and 1440px widths, notifications, and sign-out. All 144 Flutter tests pass and analysis is clean. These checks verify the changed shell and existing workflow regressions; they are not evidence of pixel identity for every form or physical-device rendering.

Flutter now mirrors the current React Site Officer view by hiding request creation for that role while retaining it for Site Engineers. The inspection form selects a material from the selected delivery, validates against the sum received for that material, and preserves fractional accepted quantities instead of rounding them to two decimal places. A regression test selects the second material and submits 10.125 accepted units. Inspection evidence supports an optional custom filename for camera/gallery photos as well as URL evidence. Flutter's audit view now uses readable actions, user names where available, status descriptions, Sri Lanka timestamps, and selectable request paths, matching the web audit presentation.

Verification: 142 Flutter tests passed; the four quality tests passed again after the optional filename update; Flutter analysis was clean; 163 React tests passed; both browser builds succeeded. Physical-device camera, gallery, and exact native rendering were not tested.

The subsequent live Playwright pass completed 49 checks with no captured runtime errors or page-width overflow. After the dashboard visual updates, the rebuilt Flutter release passed another 49 live browser checks with no captured errors or page-width overflow. The initial screenshot pass timed out waiting for fonts; subsequent passes used `PW_TEST_SCREENSHOT_NO_FONTS_READY=1` to bypass that screenshot-only wait. Results are in `artifacts/ui-review-live/browser-report.json`.

## Live run follow-up

Procurement workflow synchronization: both apps now load the latest persisted quotation-analysis workflow for the selected request, allowing a manager to review the officer's recommendation in a separate session. Comparison and receiving-order lists refresh every 15 seconds; React also refreshes on window focus. Procurement Managers have review/decision controls; quotation entry and initiating analysis belong to officers and administrators. Backend approval already creates the purchase order with Confirmed status in the approval transaction, making it available through the receiving endpoint. The API was rebuilt and restarted, and the latest-workflow endpoint was verified with a live manager login. Backend: 307 tests passed; React: 162 tests passed; Flutter's full suite passed before the additional manager-specific regression, and the focused parity suite including that regression passed afterward. Both app builds succeeded.

The API was rebuilt and restarted to load the current fixes. PostgreSQL, all four agents, the API, and React passed the startup health checks. The current Flutter release browser build is served at http://127.0.0.1:8082; React is at http://127.0.0.1:5173. Both use the API on port 5078. The pre-existing Flutter debug session on port 8081 was preserved.

The live Playwright review completed 49 checks with zero page-width overflows or captured runtime errors. All seven Flutter roles reached authenticated dashboards, and the review checked React dashboards and administrator workspace pages at desktop and phone widths plus selected Flutter administrator workspaces. Results and screenshots are in `artifacts/ui-review-live`; this pass used the actual API, without browser fixtures. It was a read-only page review, not a full write-operation journey.

Current verification: Flutter analysis clean; 138 Flutter tests passed; 158 React tests passed; Flutter browser and React production builds passed. No Android device was connected. Real email delivery still requires SMTP credentials. Exact native-device appearance and every end-to-end operation are not established by these checks.

To review an already running Flutter release server: set `FLUTTER_REVIEW_URL` to its URL and run `npm exec --yes --package=playwright -- node scripts/ui-browser-review.cjs --existing-flutter`.

## Responsive shell and typography verification

Flutter now bundles the same Plus Jakarta Sans font used by React, including the font license. The React-style shell uses a navy horizontal navigation menu at widths up to 820px and a 268px sidebar above that breakpoint. It displays React navigation labels in React order, the signed-in user avatar, notifications, and sign-out. Role permissions continue to govern the available destinations and operations. NCRs have a separate destination, and officers/admins record quotations from the quotation workspace rather than a separate navigation tab. The final header adjustment matches React's 38px rounded rectangular icon buttons.

Verification: 144 Flutter tests passed; analysis clean; release browser build passed. The live browser review completed 49 checks without captured errors or page-width overflow after the shell/font changes; the final icon-button styling was covered by the focused responsive shell tests. Review artifacts remain in `artifacts/ui-review-live`. Camera hardware, every write-operation journey, and pixel identity for all pages on physical phones remain outside this verification.

## Procurement Officer and Procurement Manager workspace follow-up

Flutter quotation workspaces now retain the selected request across reloads, show its project/reason/required date/status/material lines, and use the React quotation and AI recommendation tab labels. Quotation details include supplier status, total, and workflow status. Officers/admins can remove Submitted or UnderReview quotations and run analysis; managers review the persisted recommendation and use Approve, Reject, or Request Revision. Revision requires a comment. Already-decided workflows show their decision rather than a misleading permissions message. A purchase-order link opens the resulting order details, and quotation entry starts on the selected request.

The project materials budget uses the same GET/PUT endpoints and payload as React. Officers read the allocation; managers can save a non-negative amount or clear it with a blank value. The dashboard refreshes metrics/activity every 15 seconds while resumed, refreshes on resume, and exposes activity endpoint/status under Technical details. Refused 401/403 events retain warning styling.

Verification: 146 Flutter tests passed, including new budget role and validation tests; 8 quotation-entry tests passed again after preserving the selected request; analysis clean. Browser results for the expanded procurement-role review are recorded in `artifacts/ui-review-live/browser-report.json`. The review uses live data and performs no procurement decisions or budget writes.

The expanded live Playwright review passed 81 checks with no captured runtime errors or page-width overflow, including both procurement roles' React pages at desktop/phone widths and Flutter workspaces plus recommendation tabs. The manager recommendation page was visually inspected with the live persisted AwaitingApproval workflow. Two detail separators were corrected after the screenshot pass; no workflow behavior changed.

## Seven demo-role comparison

The Flutter login now follows React's demo-account presentation: separate role and email labels, the same seven accounts in the same order, the evaluation subtitle, and the shared demo-password hint. The screen uses a bounded login column and a two-column demo grid above the React 480px breakpoint, with one column on phones. Valid email and non-empty password are checked before authentication, and the password keyboard action submits login. Async login callbacks check that the screen remains mounted.

A role-scope mismatch was corrected: Site Officers now load their own material requests, matching React, while remaining unable to create requests. Procurement Officers still read the entire register. Two regression tests verify these API scopes. The NCR heading can wrap alongside its status badge on narrow screens.

The browser review now reads React's navigation table directly, visits every allowed workspace for all seven roles in both apps, and checks for missing or unexpectedly exposed Flutter workspaces. Existing tests cover request, procurement, delivery, inspection, NCR, account, and activity behaviors. Verification: 149 Flutter tests passed; analyzer clean; the eight authentication tests passed again after keyboard/spacing updates. Real-device camera and every live write journey are not established by a read-only browser pass.

The complete seven-role browser review covered 179 pages/states with no Flutter runtime errors, page-width overflow, or missing/unexpected role workspaces. It uncovered supplier-directory prefetches in React's shared procurement wrapper that returned 403 for read-only roles opening purchase orders. That prefetch is now restricted to procurement roles. React's 163 tests and production build passed. The final targeted seven-role login/dashboard/purchase-order follow-up completed 44 checks with zero captured errors or overflow. The initial complete report is retained as `artifacts/ui-review-live/seven-role-full-review.json`; the successful follow-up is `artifacts/ui-review-live/browser-report.json`. The final bundled-font adjustment passed the 10 authentication/responsive-shell tests and the Flutter release build.
