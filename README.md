# EventQL

EventQL is a GraphQL API for managing events and selling tickets. It was built as part of a master's thesis to be compared against an equivalent REST implementation (same domain and features) in terms of ergonomics, performance, and implementation complexity.

## Tech Stack

- Ruby 3.4.7
- Rails 8 (API mode)
- GraphQL (graphql-ruby + graphql-batch for N+1 prevention)
- Devise (authentication base)
- JWT (Bearer token auth, manual implementation)
- PostgreSQL
- RSpec (tests)
- GraphiQL (interactive query explorer)

## Core Features

- **Events**: list (with filters), details, admin CRUD
- **Ticket Batches**: time-bound ticket pools with pricing and quantity (admin CRUD)
- **Orders**: place order, pay (mock), cancel, list own; admin sees all
- **Tickets**: list own tickets, view ticket
- **Users**: register, login (JWT), current profile, password change
- **Roles**: regular user vs admin (extra management rights)

## Requirements

- PostgreSQL
- Ruby 3.4.7
- Bundler

## Setup

1. **Clone repo**
   ```bash
   git clone <repo_url>
   cd EventQL
   ```

2. **Install gems**
   ```bash
   bundle install
   ```

3. **Database**
   Ensure PostgreSQL is running
   ```bash
   bin/rails db:prepare
   ```

4. **Credentials** (for JWT secret)
   ```bash
   bin/rails credentials:edit
   ```
   Ensure `config/master.key` exists or set `RAILS_MASTER_KEY`

5. **Run server**
   ```bash
   bin/rails s
   ```
   API endpoint: `http://localhost:3000/graphql`

## GraphQL Endpoint

- **Endpoint**: `POST /graphql`
- **GraphiQL**: `http://localhost:3000/graphiql` (interactive explorer)

### Example Queries

```graphql
# List upcoming events
query {
  events(upcoming: true) {
    nodes {
      id
      name
      date
      category
    }
  }
}

# Get single event with ticket batches
query {
  event(id: 1) {
    name
    description
    date
    ticketBatches {
      name
      price
      availableTickets
    }
  }
}

# Login
mutation {
  login(email: "user@example.com", password: "password") {
    token
    user {
      id
      email
    }
    errors
  }
}
```

### Authentication

Include JWT token in Authorization header:
```
Authorization: Bearer <token>
```

## Tests

```bash
bundle exec rspec
```

## Purpose

This GraphQL implementation serves as a comparison against a REST version (EventREST) covering the same functional scope, as part of a master's thesis study.
