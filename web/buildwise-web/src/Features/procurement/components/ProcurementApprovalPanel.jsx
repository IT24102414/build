import { useState } from 'react'
import { Button, Card, StatusBadge, TextInput } from '../../../components/shared'
import { statusTone } from './statusTone'

export default function ProcurementApprovalPanel({ workflow, role, onDecide, deciding, onViewPurchaseOrder }) {
  const [comment, setComment] = useState('')
  const [error, setError] = useState('')

  if (!workflow) return null

  const isManager = role === 'Manager'
  const alreadyDecided = workflow.approvalStatus && workflow.approvalStatus !== 'Pending'
  const canDecide = isManager && workflow.status === 'AwaitingApproval' && !alreadyDecided

  const handleDecision = async (decision) => {
    if (decision === 'RevisionRequested' && !comment.trim()) {
      setError('Add a comment explaining what needs revision.')
      return
    }
    setError('')
    await onDecide(decision, comment)
    setComment('')
  }

  return (
    <Card title="Procurement Approval" subtitle="Only a Procurement Manager decision unlocks purchase order creation.">
      <div className="actions" style={{ marginBottom: 'var(--space-4)' }}>
        <StatusBadge status={statusTone(workflow.approvalStatus || 'Pending')}>{workflow.approvalStatus || 'Pending'}</StatusBadge>
      </div>

      {!isManager ? (
        <p className="status-note">Sign in as Procurement Manager to Approve, Reject, or Request Revision on this workflow. Officers can view status only.</p>
      ) : alreadyDecided ? (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.75rem' }}>
          <p className="status-note" style={{ margin: 0 }}>
            This workflow has already been decided: <strong>{workflow.approvalStatus}</strong>.
            {workflow.purchaseOrderId ? ` Purchase Order #${workflow.purchaseOrderId} has been created.` : ''}
          </p>
          {workflow.purchaseOrderId && onViewPurchaseOrder && (
            <Button variant="secondary" onClick={() => onViewPurchaseOrder(workflow.purchaseOrderId)}>
              View Purchase Order #{workflow.purchaseOrderId} →
            </Button>
          )}
        </div>
      ) : workflow.status !== 'AwaitingApproval' ? (
        <p className="status-note">This workflow is not yet awaiting approval (current status: {workflow.status}).</p>
      ) : (
        <div className="approval-panel__form">
          <TextInput label="Comment" name="comment" multiline placeholder="Optional for Approve, required for Request Revision" value={comment} onChange={(e) => setComment(e.target.value)} error={error || undefined} />
          <div className="approval-panel__actions">
            <Button variant="primary" disabled={!canDecide || deciding} onClick={() => handleDecision('Approve')}>Approve</Button>
            <Button variant="danger" disabled={!canDecide || deciding} onClick={() => handleDecision('Reject')}>Reject</Button>
            <Button variant="secondary" disabled={!canDecide || deciding} onClick={() => handleDecision('RevisionRequested')}>Request Revision</Button>
          </div>
        </div>
      )}
    </Card>
  )
}
