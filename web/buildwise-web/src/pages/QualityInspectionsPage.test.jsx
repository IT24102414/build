import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import QualityInspectionsPage from './QualityInspectionsPage'
import { qualityApi } from '../services/qualityApi'
import { useAuth } from '../auth/AuthContext'

vi.mock('../services/qualityApi', () => ({
  qualityApi: {
    listNonConformances: vi.fn(),
    listInspections: vi.fn(),
    getInspection: vi.fn(),
    analyzeQualityRisk: vi.fn(),
    transitionNonConformance: vi.fn(),
  },
}))

vi.mock('../auth/AuthContext', () => ({ useAuth: vi.fn() }))

const inspections = [
  {
    id: 34,
    deliveryId: 33,
    overallDecision: 'PartiallyAccepted',
    inspectionCriteria: 'Visual',
    observedResult: '5 damaged',
    evidence: [],
    inspectedAt: '2026-09-28T07:54:00Z',
    // A recorded checklist: quantity and defects passed, the physical
    // characteristics failed (consistent with 5 damaged bags).
    quantityCheck: true,
    visualConditionCheck: false,
    moistureCheck: false,
    packagingCheck: false,
    defectsCheck: true,
  },
  {
    id: 33,
    deliveryId: 32,
    overallDecision: 'Accepted',
    inspectionCriteria: 'Visual',
    observedResult: 'All good',
    evidence: [],
    inspectedAt: '2026-09-28T07:41:00Z',
    // No checklist fields: this is a legacy inspection recorded before the
    // structured checklist existed, and must render as "not recorded".
  },
]

const mediumRisk = {
  inspectionId: 34,
  deliveryId: 33,
  agent: 'QualityRiskAnalysisAgent',
  tool: 'analyze_quality_risk',
  executionSource: 'PythonQualityAgent',
  riskLevel: 'Medium',
  requiresNcr: true,
  suggestedCorrectiveAction: 'Issue formal NCR to supplier for defective materials.',
  riskFlags: ['MINOR_QUALITY_DEFECT'],
  totalInspected: 240,
  totalRejected: 5,
  rejectionRatePct: 2.08,
  inspectionStatus: 'Completed',
  overallDecision: 'PartiallyAccepted',
}

// Shape mirrors the real /quality-inspections/non-conformances response, so the
// detail view is exercised against the full delivery → inspection → item chain.
const ncr = {
  id: 35,
  ncrNumber: 'NCR-781611',
  inspectionItemId: 33,
  inspectionItem: {
    id: 33,
    inspectionId: 35,
    material: { id: 1, name: 'Cement (50kg bag)', unit: 'bag' },
    inspectedQuantity: 240,
    acceptedQuantity: 235,
    rejectedQuantity: 5,
    rejectionReason: 'Water damage during transport.',
    inspection: {
      id: 35,
      deliveryId: 34,
      overallDecision: 'PartiallyAccepted',
      delivery: { id: 34, deliveryReference: 'E2E-20260928083239685', status: 'DiscrepancyReported' },
    },
  },
  deliveryId: 34,
  materialId: 1,
  supplierId: 1,
  quantityAffected: 5,
  severity: 'Medium',
  status: 'CorrectiveActionRequired',
  issueDescription: 'Water damage during transport.',
  correctiveActionPlan: 'Issue formal NCR to supplier for defective materials. Request credit note or replacement for rejected quantity.',
  resolution: null,
  reviewNotes: null,
  reviewedByUserId: null,
  reviewedAt: null,
  resolvedAt: null,
  closedAt: null,
  createdAt: '2026-09-28T08:32:42Z',
}

describe('QualityInspectionsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    qualityApi.listNonConformances.mockResolvedValue([])
    qualityApi.listInspections.mockResolvedValue(inspections)
    useAuth.mockReturnValue({ hasRole: () => true })
  })

  it('lists inspections and offers an AI analysis action for each', async () => {
    render(<QualityInspectionsPage />)

    expect(await screen.findByText('INS-34')).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: 'Run AI Analysis' })).toHaveLength(2)
    // Nothing is claimed before the agent actually runs.
    expect(screen.queryByTestId('quality-risk-panel')).not.toBeInTheDocument()
  })

  it('surfaces the real agent result with its risk level and NCR recommendation', async () => {
    const user = userEvent.setup()
    qualityApi.analyzeQualityRisk.mockResolvedValue(mediumRisk)
    render(<QualityInspectionsPage />)
    await screen.findByText('INS-34')

    await user.click(screen.getAllByRole('button', { name: 'Run AI Analysis' })[0])

    const panel = await screen.findByTestId('quality-risk-panel')
    expect(within(panel).getByText('QualityRiskAnalysisAgent')).toBeInTheDocument()
    expect(within(panel).getByText('analyze_quality_risk')).toBeInTheDocument()
    // Proves the real Python agent answered, not the deterministic fallback.
    expect(within(panel).getByText('PythonQualityAgent')).toBeInTheDocument()
    expect(within(panel).getByText('Medium')).toBeInTheDocument()
    expect(within(panel).getByText('Required by this assessment')).toBeInTheDocument()
    expect(within(panel).getByText('MINOR_QUALITY_DEFECT')).toBeInTheDocument()
    expect(qualityApi.analyzeQualityRisk).toHaveBeenCalledWith(34)
  })

  it('reports a low-risk inspection as not requiring an NCR', async () => {
    const user = userEvent.setup()
    qualityApi.analyzeQualityRisk.mockResolvedValue({
      ...mediumRisk,
      inspectionId: 33,
      riskLevel: 'Low',
      requiresNcr: false,
      riskFlags: [],
      totalRejected: 0,
      rejectionRatePct: 0,
      suggestedCorrectiveAction: 'No corrective action required. Material meets quality standards.',
    })
    render(<QualityInspectionsPage />)
    await screen.findByText('INS-33')

    await user.click(screen.getAllByRole('button', { name: 'Run AI Analysis' })[1])

    const panel = await screen.findByTestId('quality-risk-panel')
    expect(within(panel).getByText('Low')).toBeInTheDocument()
    expect(within(panel).getByText('Not required')).toBeInTheDocument()
    expect(within(panel).getByText('None')).toBeInTheDocument()
  })

  it('keeps the inspection list readable when the agent call fails', async () => {
    const user = userEvent.setup()
    qualityApi.analyzeQualityRisk.mockRejectedValue(new Error('Quality agent unavailable'))
    render(<QualityInspectionsPage />)
    await screen.findByText('INS-34')

    await user.click(screen.getAllByRole('button', { name: 'Run AI Analysis' })[0])

    expect(await screen.findByText('Quality agent unavailable')).toBeInTheDocument()
    // The authoritative inspection records are still shown.
    expect(screen.getByText('INS-34')).toBeInTheDocument()
    expect(screen.getByText('INS-33')).toBeInTheDocument()
  })

  it('does not file one inspection analysis under another row', async () => {
    const user = userEvent.setup()
    qualityApi.analyzeQualityRisk.mockResolvedValue(mediumRisk)
    render(<QualityInspectionsPage />)
    await screen.findByText('INS-34')

    await user.click(screen.getAllByRole('button', { name: 'Run AI Analysis' })[0])
    await screen.findByTestId('quality-risk-panel')
    // Exactly one panel, for the row that was analysed.
    expect(screen.getAllByTestId('quality-risk-panel')).toHaveLength(1)
    expect(screen.getByRole('button', { name: 'Run AI Analysis' })).toBeInTheDocument()
  })

  it('states that the agent is advisory while the inspection record is authoritative', async () => {
    const user = userEvent.setup()
    qualityApi.analyzeQualityRisk.mockResolvedValue(mediumRisk)
    render(<QualityInspectionsPage />)
    await screen.findByText('INS-34')
    await user.click(screen.getAllByRole('button', { name: 'Run AI Analysis' })[0])

    const panel = await screen.findByTestId('quality-risk-panel')
    // The viva point: the agent recommends, the backend/inspector decide.
    expect(within(panel).getByText(/Advisory only/)).toBeInTheDocument()
    expect(within(panel).getByText('Completed · Partially Accepted')).toBeInTheDocument()
  })

  it('shows the error state when the page cannot load', async () => {
    qualityApi.listInspections.mockRejectedValueOnce(new Error('API unavailable'))
    render(<QualityInspectionsPage />)

    expect(await screen.findByText('API unavailable')).toBeInTheDocument()
  })

  it('shows an empty state when no inspections exist', async () => {
    qualityApi.listInspections.mockResolvedValue([])
    render(<QualityInspectionsPage />)

    expect(await screen.findByText('No inspections recorded')).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Run AI Analysis' })).not.toBeInTheDocument())
  })

  it('renders the five-point checklist as structured pass/fail rows', async () => {
    render(<QualityInspectionsPage />)

    const row = (await screen.findByText('INS-34')).closest('tr')

    // true -> a tick, false -> a cross. The criteria are listed individually
    // rather than collapsed into one free-text sentence.
    expect(within(row).getByText('✓ Quantity')).toBeInTheDocument()
    expect(within(row).getByText('✗ Visual condition')).toBeInTheDocument()
    expect(within(row).getByText('✗ Moisture')).toBeInTheDocument()
    expect(within(row).getByText('✗ Packaging')).toBeInTheDocument()
    expect(within(row).getByText('✓ Defects')).toBeInTheDocument()
  })

  it('marks a legacy inspection as not recorded instead of passing it', async () => {
    render(<QualityInspectionsPage />)

    const row = (await screen.findByText('INS-33')).closest('tr')

    // An inspection recorded before the structured checklist existed must never
    // render as "✓" — that would fabricate a quality result.
    expect(within(row).getByText('Not recorded')).toBeInTheDocument()
    expect(within(row).queryByText('✓ Quantity')).not.toBeInTheDocument()
  })

  it('opens the full non-conformance record from the NCR number', async () => {
    const user = userEvent.setup()
    qualityApi.listNonConformances.mockResolvedValue([ncr])
    render(<QualityInspectionsPage />)

    // The table alone only shows a summary; the evidence chain is behind a click.
    await user.click(await screen.findByRole('button', { name: 'NCR-781611' }))

    const dialog = await screen.findByRole('dialog', { name: 'NCR-781611' })
    // Material, origin and the three quantities prove the record is complete.
    expect(within(dialog).getByText('Cement (50kg bag)')).toBeInTheDocument()
    expect(within(dialog).getByText('DEL-34')).toBeInTheDocument()
    expect(within(dialog).getByText('INS-35')).toBeInTheDocument()
    expect(within(dialog).getByText('240 units')).toBeInTheDocument()
    expect(within(dialog).getByText('5 units')).toBeInTheDocument()
    // Review trail is explicit about what has not happened yet.
    expect(within(dialog).getByText('Not yet resolved')).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Close' }))
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'NCR-781611' })).not.toBeInTheDocument())
  })
})