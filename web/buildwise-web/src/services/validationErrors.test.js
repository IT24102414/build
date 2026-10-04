import { describe, expect, it } from 'vitest'
import { describeApiFailure, mapValidationError, statusMessage } from './validationErrors'

describe('mapValidationError', () => {
  it('reads RFC 7807 ValidationProblemDetails errors into fields', () => {
    const result = mapValidationError({
      title: 'One or more validation errors occurred.',
      errors: { TransportCharge: ['Transport charge cannot be negative.'], Email: ['Bad email.'] },
    })

    expect(result.fieldErrors.transportCharge).toBe('Transport charge cannot be negative.')
    expect(result.fieldErrors.email).toBe('Bad email.')
  })

  it('reads a { message } body used by the business-rule controllers', () => {
    const result = mapValidationError({ message: 'Cumulative received quantity cannot exceed the ordered quantity.' })

    expect(result.general).toContain('Cumulative received quantity')
    expect(result.fieldErrors.receivedQuantity).toContain('Cumulative')
  })

  it('reads a { error } body used by the auth controller', () => {
    expect(mapValidationError({ error: 'Invalid email or password.' }).general).toBe('Invalid email or password.')
  })

  it('reads a bare string body returned by BadRequest(string)', () => {
    expect(mapValidationError('Promised delivery date cannot be later than the quotation validity date.').general)
      .toContain('Promised delivery date')
  })

  it('never invents a field association when the server names none', () => {
    const result = mapValidationError({ message: 'Deliveries can only be recorded for Confirmed Purchase Orders.' })

    expect(result.fieldErrors).toEqual({})
    expect(result.general).toContain('Confirmed Purchase Orders')
  })

  it('handles a null payload without throwing', () => {
    expect(mapValidationError(null)).toEqual({ fieldErrors: {}, general: null })
  })
})

describe('statusMessage', () => {
  it('explains a 403 in role terms', () => {
    expect(statusMessage(403, {})).toMatch(/role/i)
  })

  it('never leaks a server exception for a 500', () => {
    const message = statusMessage(500, { message: 'System.NullReferenceException at Foo.cs:line 42' })

    expect(message).not.toMatch(/Exception|at Foo\.cs/)
    expect(message).toMatch(/server/i)
  })

  it('surfaces the 409 business message when one is supplied', () => {
    expect(statusMessage(409, { message: 'Purchase Order #7 already exists for material request #3.' }))
      .toContain('already exists')
  })
})

describe('describeApiFailure', () => {
  it('attaches a named field from the payload and keeps the summary', () => {
    const err = Object.assign(new Error('failed'), {
      status: 400,
      payload: { message: 'Transport charge cannot be negative.' },
    })

    const result = describeApiFailure(err)

    expect(result.fieldErrors.transportCharge).toBe('Transport charge cannot be negative.')
    expect(result.general).toContain('Transport charge')
  })

  it('turns a network failure into actionable guidance, not "Failed to fetch"', () => {
    const result = describeApiFailure(new TypeError('Failed to fetch'))

    expect(result.general).toMatch(/start-dev\.ps1/i)
    expect(result.general).not.toMatch(/Failed to fetch/)
  })

  it('maps a 401 to a sign-in prompt', () => {
    expect(describeApiFailure(Object.assign(new Error('x'), { status: 401, payload: {} })).general)
      .toMatch(/sign in/i)
  })
})