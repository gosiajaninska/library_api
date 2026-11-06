readers = [
  { card_number: "100001", full_name: "John Doe", email: "john.doe@example.com" },
  { card_number: "100002", full_name: "Jane Doe", email: "jane.doe@example.com" },
  { card_number: "100003", full_name: "Adam Smith", email: "adam.smith@example.com" }
]

books = [
  { serial_number: "000001", title: "Dune", author: "Frank Herbert" },
  { serial_number: "000002", title: "The Hobbit", author: "J.R.R. Tolkien" },
  { serial_number: "000003", title: "Solaris", author: "Stanisław Lem" },
  { serial_number: "000004", title: "Neuromancer", author: "William Gibson" }
]

readers = readers.map { |attributes| Reader.create_with(attributes).find_or_create_by!(card_number: attributes[:card_number]) }
books = books.map { |attributes| Book.create_with(attributes).find_or_create_by!(serial_number: attributes[:serial_number]) }

# One borrowed book, so the API shows both statuses out of the box.
# Skipped if it is already borrowed, or was deleted through the API since the last run.
dune = books.first
Loans::BorrowBook.call(book: dune, reader: readers.first) unless dune.borrowed? || dune.discarded?

puts "Seeded #{Reader.count} readers and #{Book.kept.count} books."
