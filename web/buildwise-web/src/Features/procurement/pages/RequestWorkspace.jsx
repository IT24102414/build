import { useEffect, useState } from 'react'
import { Button, Card, ErrorState, LoadingState, PageHeader, StatusBadge, materialRequestTone } from '../../../components/shared'
import { procurementApi } from '../services/procurementApi'
import QuotationEntryForm from '../components/QuotationEntryForm'
import ProjectBudgetPanel from '../components/ProjectBudgetPanel'
import WorkflowPipeline from '../components/WorkflowPipeline'
import QuotationComparisonView from '../components/QuotationComparisonView'
import AIRecommendationReview from '../components/AIRecommendationReview'
import ProcurementApprovalPanel from '../components/ProcurementApprovalPanel'

const TABS = ['Quotations', 'Comparison & AI Recommendation']

export default function RequestWorkspace({ requestId, role, canRecord = role === 'Officer', onBack, onViewPurchaseOrder }) {
  const [requestDetail, setRequestDetail] = useState(null)
  const [comparison, setComparison] = useState(null)
  const [workflow, setWorkflow] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [tab, setTab] = useState(TABS[0])
  const [runningAnalysis, setRunningAnalysis] = useState(false)
  const [deciding, setDeciding] = useState(false)
  const [creatingPo, setCreatingPo] = useState(false)
  const [budget, setBudget] = useState(null)
  const [notice, setNotice] = useState('')

  const loadCore = async () => {
    const [detail, compareData] = await Promise.all([
      procurementApi.getMaterialRequest(requestId),
      procurementApi.compareQuotations(requestId)
    ])
    setRequestDetail(detail)
    setComparison(compareData)
    setWorkflow(await procurementApi.getLatestWorkflow(requestId))
    // The project materials budget is context for the deterministic budget
    // check shown in the pipeline. Optional: a missing/unreadable budget must
    // never block the workspace (the API also enforces who may read it).
    try {
      const budgetData = await procurementApi.getProjectBudget(detail.projectId)
      setBudget(budgetData?.materialBudgetAmount ?? null)
    } catch {
      setBudget(null)
    }
  }

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      await loadCore()
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
    const refresh = () => { if (!document.hidden) loadCore().catch(() => {}) }
    const timer = setInterval(refresh, 15000)
    window.addEventListener('focus', refresh)
    return () => { clearInterval(timer); window.removeEventListener('focus', refresh) }
  }, [requestId])

  const handleQuotationCreated = async () => {
    setNotice('Quotation recorded.')
    await loadCore()
  }

  const handleDeleteQuotation = async (id) => {
    try {
      await procurementApi.deleteQuotation(id)
      await loadCore()
    } catch (err) {
      setError(err.message)
    }
  }

  const handleRunAnalysis = async () => {
    setRunningAnalysis(true)
    setError(null)
    try {
      const { workflowId } = await procurementApi.startWorkflow(requestId)
      const details = await procurementApi.getWorkflow(workflowId)
      setWorkflow(details)
      setTab(TABS[1])
    } catch (err) {
      setError(err.message)
    } finally {
      setRunningAnalysis(false)
    }
  }

  const handleDecision = async (decision, comment) => {
    setDeciding(true)
    setError(null)
    try {
      await procurementApi.recordDecision(workflow.id, decision, comment)
      const refreshed = await procurementApi.getWorkflow(workflow.id)
      setWorkflow(refreshed)
      if (decision === 'Approve') {
        const poId = refreshed.purchaseOrderId
        setNotice(poId ? `Purchase Order #${poId} created successfully.` : 'Decision recorded: Approved.')
        await loadCore()
        if (poId) {
          onViewPurchaseOrder?.(poId)
        }
      } else {
        setNotice(`Decision recorded: ${decision}.`)
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setDeciding(false)
    }
  }

  if (loading) return <LoadingState message="Loading request workspace…" />
  if (error && !requestDetail) return <ErrorState message={error} onRetry={load} />
  if (!requestDetail) return null

  return (
    <div className="stack">
      <button type="button" className="proc-back" onClick={onBack}>← Back to approved requests</button>
      <PageHeader eyebrow={`MATERIAL REQUEST #${requestDetail.id}`} title={requestDetail.projectName} description={requestDetail.reason || 'Quote, compare, and approve procurement for this request.'} />
      <div className="actions"><StatusBadge status={materialRequestTone(requestDetail.status)}>{requestDetail.status}</StatusBadge><span className="muted">Required by {requestDetail.requiredDate}</span></div>

      {notice && <div className="proc-mock-banner" style={{ background: 'var(--color-success-100)', color: 'var(--color-success-700)', borderColor: 'var(--color-success-700)' }}>{notice}</div>}
      {error && requestDetail && (
        <div className="proc-mock-banner" style={{ background: 'var(--color-danger-100)', color: 'var(--color-danger-700)', borderColor: 'var(--color-danger-700)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '0.5rem' }}>
          <span>{error}</span>
          {(() => {
            const match = error.match(/Purchase Order #(\d+)/i)
            if (match && onViewPurchaseOrder) {
              return (
                <Button variant="secondary" onClick={() => onViewPurchaseOrder(Number(match[1]))} style={{ fontSize: '0.8rem', padding: '0.25rem 0.6rem' }}>
                  View PO #{match[1]} →
                </Button>
              )
            }
            return null
          })()}
        </div>
      )}

      <div className="proc-tabs">
        {TABS.map((t) => <button key={t} type="button" className={`proc-tab ${tab === t ? 'proc-tab--active' : ''}`} onClick={() => setTab(t)}>{t}</button>)}
      </div>

      {tab === TABS[0] && (
        <div className="stack">
          {canRecord && <QuotationEntryForm requestDetail={requestDetail} onCreated={handleQuotationCreated} />}
          <QuotationComparisonView comparison={comparison} onDeleteQuotation={canRecord ? handleDeleteQuotation : undefined} onRunAnalysis={canRecord ? () => { setTab(TABS[1]); handleRunAnalysis() } : undefined} running={runningAnalysis} />
        </div>
      )}

      {tab === TABS[1] && (
        <div className="stack">
          <ProjectBudgetPanel projectId={requestDetail.projectId} />
          <Card>
            <div className="actions">
              {canRecord && <Button onClick={handleRunAnalysis} disabled={runningAnalysis}>{runningAnalysis ? 'Running AI analysis…' : workflow ? 'Re-run AI Analysis' : 'Run AI Analysis'}</Button>}
              {deciding && <span className="muted">Recording decision…</span>}
            </div>
          </Card>
          {workflow && <WorkflowPipeline workflow={workflow} budget={budget} />}
          <AIRecommendationReview workflow={workflow} />
          {workflow && <ProcurementApprovalPanel workflow={workflow} role={role} onDecide={handleDecision} deciding={deciding} onViewPurchaseOrder={onViewPurchaseOrder} />}
        </div>
      )}
    </div>
  )
}
