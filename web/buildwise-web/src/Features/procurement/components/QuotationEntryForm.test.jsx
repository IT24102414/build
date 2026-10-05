import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import QuotationEntryForm from './QuotationEntryForm'

const requestDetail = {
  id: 101,
  status: 'Approved',
  items: [{ id: 1001, materialName: 'Cement (50kg bag)', unit: 'bag', requestedQuantity: 250 }]
}

describe('QuotationEntryForm validation', () => {
  it('requires a supplier before it will submit', async () => {
    const user = userEvent.setup()
    render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    await user.click(screen.getByRole('button', { name: 'Save quotation' }))

    expect(await screen.findByText('Select a supplier.')).toBeInTheDocument()
  })

  it('requires at least one line item with a quantity and price', async () => {
    const user = userEvent.setup()
    render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    await waitFor(() => expect(screen.getByRole('combobox', { name: 'Supplier' }).options.length).toBeGreaterThan(1))
    await user.selectOptions(screen.getByRole('combobox', { name: 'Supplier' }), '1')
    await user.click(screen.getByRole('button', { name: 'Save quotation' }))

    expect(await screen.findByText('Enter quantity and unit price for at least one item.')).toBeInTheDocument()
  })

  it('rejects a zero quantity even when a price is entered', async () => {
    // A negative value is blocked earlier by the field's own min="0" HTML5
    // constraint (the browser never fires the submit event at all), so this
    // exercises the app's own "quantity must be positive" business rule via
    // the one value (0) that constraint validation lets through.
    const user = userEvent.setup()
    render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    await waitFor(() => expect(screen.getByRole('combobox', { name: 'Supplier' }).options.length).toBeGreaterThan(1))
    await user.selectOptions(screen.getByRole('combobox', { name: 'Supplier' }), '1')
    await user.type(screen.getByLabelText('Quantity (bag)'), '0')
    await user.type(screen.getByLabelText('Unit price'), '2100')
    await user.click(screen.getByRole('button', { name: 'Save quotation' }))

    expect(await screen.findByText('Quantity must be positive and unit price cannot be negative.')).toBeInTheDocument()
  })

  it('computes the live line total and quotation total as quantity/price are entered', async () => {
    const user = userEvent.setup()
    render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    await user.type(screen.getByLabelText('Quantity (bag)'), '250')
    await user.type(screen.getByLabelText('Unit price'), '2100')

    expect(await screen.findAllByText('525,000')).toHaveLength(2)
  })

  it('blocks saving when "valid until" is not after the quotation date', async () => {
    // The date fields use a sibling <label> without htmlFor, so they are not
    // reachable by getByLabelText — select them by their form names instead.
    const { container } = render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    // Default quotation date is today, so any earlier date violates the rule.
    fireEvent.change(container.querySelector('input[name="validUntil"]'), {
      target: { value: '2020-01-01' },
    })

    // The error text carries a leading ⚠ in the markup, so match by substring.
    expect(
      await screen.findByText(/"Valid until" must be after the quotation date/),
    ).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save quotation' })).toBeDisabled()
  })

  it('blocks saving when the promised delivery date is not after the quotation date', async () => {
    const { container } = render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    fireEvent.change(container.querySelector('input[name="promisedDeliveryDate"]'), {
      target: { value: '2020-01-01' },
    })

    expect(
      await screen.findByText(/Promised delivery date must be after the quotation date/),
    ).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save quotation' })).toBeDisabled()
  })

  it('shows an inline error for a zero quantity as soon as it is typed', async () => {
    const user = userEvent.setup()
    render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    await user.type(screen.getByLabelText('Quantity (bag)'), '0')

    expect(
      await screen.findByText('Quantity must be a positive number greater than 0.'),
    ).toBeInTheDocument()
  })

  it('rejects a decimal quantity for a discrete unit (bags) inline', async () => {
    const user = userEvent.setup()
    render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    await user.type(screen.getByLabelText('Quantity (bag)'), '10.5')

    expect(await screen.findByText(/Decimal quantities are not allowed for 'bag'/)).toBeInTheDocument()
  })

  it('rejects a negative unit price inline', async () => {
    // fireEvent rather than user-event: typing a bare minus sign into
    // <input type="number"> is filtered out by the user-event keyboard model.
    const { container } = render(<QuotationEntryForm requestDetail={requestDetail} onCreated={() => {}} />)

    fireEvent.change(container.querySelector('input[name="unitPrice-1001"]'), {
      target: { value: '-5' },
    })

    expect(
      await screen.findByText('Unit price must be a number of 0 or more.'),
    ).toBeInTheDocument()
  })
})
