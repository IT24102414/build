import { describe, expect, it } from 'vitest'
import { statusTone } from './statusTone'
import {
  ROLES,
  NAVIGATION,
  navigationForRoles,
  defaultRouteForRoles,
  isInternalStaff,
  canSeeCommercialTerms,
} from '../../../auth/accessControl'

describe('statusTone', () => {
  it('maps a Suspended supplier to the danger tone', () => {
    expect(statusTone('Suspended')).toBe('danger')
  })

  it('maps an Active supplier to the success tone', () => {
    expect(statusTone('Active')).toBe('success')
  })

  it('maps AwaitingApproval to the warning tone', () => {
    expect(statusTone('AwaitingApproval')).toBe('warning')
  })

  it('falls back to neutral for an unrecognized status', () => {
    expect(statusTone('SomethingUnexpected')).toBe('neutral')
  })

  it('maps the RFQ statuses', () => {
    // RfqStatus.cs: a Draft is not out yet, Issued still needs supplier
    // responses, Closed is done.
    expect(statusTone('Draft')).toBe('neutral')
    expect(statusTone('Issued')).toBe('warning')
    expect(statusTone('Closed')).toBe('success')
  })
})

describe('accessControl — a supplier is an external stakeholder, not a user', () => {
  it('does not define a Supplier role', () => {
    expect(ROLES.Supplier).toBeUndefined()
    expect(Object.values(ROLES)).not.toContain('Supplier')
  })

  it('exposes no supplier portal route', () => {
    // `/suppliers` (procurement supplier master data) is legitimate and stays.
    // The removed surface was the singular `/supplier` portal namespace.
    const paths = NAVIGATION.map((item) => item.path)
    expect(paths).toContain('/suppliers')
    expect(paths).not.toContain('/supplier')
    expect(paths.some((path) => path.startsWith('/supplier/'))).toBe(false)
  })

  it('grants a legacy Supplier claim no navigation at all', () => {
    // Even if a stale token carried the role, the menu stays empty and the
    // user is not treated as internal staff.
    expect(navigationForRoles(['Supplier'])).toEqual([])
    expect(isInternalStaff(['Supplier'])).toBe(false)
  })

  it('never lets a Supplier claim reach commercial terms', () => {
    expect(canSeeCommercialTerms(['Supplier'])).toBe(false)
  })
})

describe('accessControl — the seven internal roles keep their procurement surfaces', () => {
  it('still lets the Procurement Officer select and manage suppliers', () => {
    const paths = navigationForRoles([ROLES.ProcurementOfficer]).map((item) => item.path)
    expect(paths).toContain('/suppliers')
    expect(paths).toContain('/quotations')
    expect(paths).toContain('/rfqs')
  })

  it('still lets the Procurement Manager review and see money', () => {
    expect(canSeeCommercialTerms([ROLES.ProcurementManager])).toBe(true)
    expect(canSeeCommercialTerms([ROLES.ProcurementOfficer])).toBe(true)
  })

  it('still denies commercial terms to site and quality roles', () => {
    expect(canSeeCommercialTerms([ROLES.SiteEngineer])).toBe(false)
    expect(canSeeCommercialTerms([ROLES.SiteOfficer])).toBe(false)
    expect(canSeeCommercialTerms([ROLES.QualityInspector])).toBe(false)
  })

  it('gives every internal role a real landing route', () => {
    for (const role of Object.values(ROLES)) {
      // A role matching no navigation entry falls back to '/dashboard', so the
      // meaningful assertion is that each role matches at least one entry.
      expect(navigationForRoles([role]).length).toBeGreaterThan(0)
      expect(defaultRouteForRoles([role])).toBeTruthy()
    }
  })
})


describe('statusTone', () => {
  it('maps a Suspended supplier to the danger tone', () => {
    expect(statusTone('Suspended')).toBe('danger')
  })

  it('maps an Active supplier to the success tone', () => {
    expect(statusTone('Active')).toBe('success')
  })

  it('maps AwaitingApproval to the warning tone', () => {
    expect(statusTone('AwaitingApproval')).toBe('warning')
  })

  it('falls back to neutral for an unrecognized status', () => {
    expect(statusTone('SomethingUnexpected')).toBe('neutral')
  })

  it('maps the RFQ statuses', () => {
    // RfqStatus.cs: a Draft is not out yet, Issued still needs supplier
    // responses, Closed is done.
    expect(statusTone('Draft')).toBe('neutral')
    expect(statusTone('Issued')).toBe('warning')
    expect(statusTone('Closed')).toBe('success')
  })
})
