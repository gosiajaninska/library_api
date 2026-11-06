# Library API

JSON API for library staff: add and remove books, list them with their status,
see each book's loan history, lend and return books. Loans last 30 days, and
readers get an email reminder 3 days before the due date and on the due date.

Ruby 3.4 · Rails 8.1 (API) · PostgreSQL 18 · Solid Queue · RSpec

## Quick start

```sh
docker compose up
```

- API: http://localhost:3000/api/v1/books
- Sent emails (Mailpit): http://localhost:8025

Seed data: readers `100001`–`100003`, books `000001`–`000004`, with `000001`
already borrowed. To send today's reminders now:
`docker compose exec jobs bin/rails loans:send_reminders`.

Tests need a local PostgreSQL: `bin/rails db:prepare && bundle exec rspec`.

## API

Books are identified by their 6-digit serial number.

| Request                                     | Does                                                                                          |
| ------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `GET /api/v1/books`                         | List books with status and current loan                                                       |
| `GET /api/v1/books/:serial_number`          | One book with its full loan history                                                           |
| `POST /api/v1/books`                        | Add a book: `{"book": {"serial_number", "title", "author"}}`                                  |
| `DELETE /api/v1/books/:serial_number`       | Remove a book (soft delete)                                                                   |
| `PATCH /api/v1/books/:serial_number/status` | Lend: `{"status": "borrowed", "card_number": "100002"}`, or return: `{"status": "available"}` |

Errors are always `{"error": "..."}`, plus `details` for validation errors:
**400** missing parameter or invalid JSON · **404** unknown or removed book ·
**409** conflicts with the book's state (already borrowed, not borrowed,
removing a borrowed book) · **422** invalid data, unknown reader or status.

## Design decisions

- **Rules are enforced twice.** Model validations give readable 422s.
  PostgreSQL constraints (checks, unique indexes, foreign keys) hold even if
  some code skips the models. A partial unique index allows only one active
  loan per book.
- **Status is derived, never stored.** A book is borrowed when it has a loan
  with no `returned_at`. Loans are never overwritten, so they are the history.
- **Removing a book is a soft delete** (`discarded_at`), so its history stays.
  A borrowed book can't be removed, and serial numbers are never reused.
- **Concurrent requests are serialised.** Borrowing, returning and removing
  all lock the book row first, so two requests can't both lend the same book.
- **Thin controllers.** Rules live in `Loans::BorrowBook`,
  `Loans::ReturnBook` and `Book`. Errors are `LibraryErrors` classes, mapped to
  HTTP statuses in one `rescue_from` block.
- **Reminders run as a daily sweep.** Solid Queue runs `LoanRemindersJob` at
  8am, and it emails readers with loans due in 3 days or today. A book
  returned early needs no cancelled job, and the mailer skips loans returned
  before the email goes out.
- **One time zone** (`LIBRARY_TIME_ZONE`, default Warsaw) drives both due
  dates and the 8am schedule.

## Limitations

- No authentication (out of scope for the task), so borrower names and emails
  are visible to anyone who can reach the API.
- No reader endpoints (readers come from seeds) and no pagination.
- Running the reminder job twice in one day sends the same emails again, and
  missed days aren't caught up.
- Loans should only be created or ended through the services. The database
  still blocks invalid writes made directly, but returns a generic 409.
- Two simultaneous `POST`s with the same new serial number: the second gets
  409 from the unique index instead of a 422.
- Compose is for local evaluation only: it uses a placeholder secret and a
  default database password.

## AI use

I used Claude Code and to write code faster and to get a second set of eyes in
review. The design, the trade-offs in this README and the final say on every
change were mine.

I reviewed its output as I would a colleague's pull request: I questioned the
approach, asked for proof in a spec and rejected suggestions that didn't
hold up. Nothing went in without passing the test suite.
