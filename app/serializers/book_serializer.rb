module BookSerializer
  module_function

  # For lists, preload `active_loan: :reader` to avoid one query per book.
  def summary(book)
    loan = book.active_loan

    {
      serial_number: book.serial_number,
      title: book.title,
      author: book.author,
      status: book.status,
      current_loan: loan && loan_json(loan)
    }
  end

  # The current loan and its reader are queried twice: once by summary, once in
  # the history. Kept on purpose, so summary stays shared with the list; the cost
  # is two indexed single-row lookups and does not grow with the history.
  def detail(book)
    loans = book.loans.includes(:reader).order(borrowed_at: :desc)

    summary(book).merge(loans: loans.map { |loan| loan_json(loan) })
  end

  def loan_json(loan)
    {
      borrowed_at: loan.borrowed_at,
      due_on: loan.due_on,
      returned_at: loan.returned_at,
      reader: {
        card_number: loan.reader.card_number,
        full_name: loan.reader.full_name,
        email: loan.reader.email
      }
    }
  end
end
