# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Ucasy is a Ruby gem providing a lightweight service object / use case pattern for Rails applications. It supports input validation, lifecycle hooks (`before`/`call`/`after`), and composable transactional flows.

## Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/ucasy_spec.rb

# Lint
bundle exec rubocop
# or
bundle exec standardrb

# Build gem
make build
# or
gem build ucasy.gemspec

# Publish gem (after build)
make publish
```

## Architecture

### Core class hierarchy

```
Ucasy::Callable        # Base callable: provides .call(*) => new(*).call
  └── Ucasy::Base      # Use case base: lifecycle hooks + validation
        └── Ucasy::Flow  # Composes multiple use cases sequentially
```

### Key components

- **`Ucasy::Context`** (`lib/ucasy/context.rb`) — An `OpenStruct` subclass passed between use cases. Holds all input/output data. Use cases call `context.fail!(status:, message:, errors:)` to signal failure, which sets `@failure = true` and raises `Ucasy::Failure` (caught internally in `Base#perform`).

- **`Ucasy::Base`** (`lib/ucasy/base.rb`) — The primary class to subclass. Execution order in `perform`: `validate!` → `validate_required_attributes!` → `before` → `call` → `after`. Steps short-circuit on failure. `method_missing` proxies unknown methods to `context`, so use case methods can access context attributes directly (e.g. `context.user` or just `user`).

- **`Ucasy::Flow`** (`lib/ucasy/flow.rb`) — Chains multiple use cases via `flow(UseCase1, UseCase2, ...)`. Supports `transactional` DSL which wraps execution in `ActiveRecord::Base.transaction` and raises `ActiveRecord::Rollback` on failure.

- **Validators** — Two validator types:
  - `required_attributes(:attr1, :attr2)` — Raises `ArgumentError` if attributes are missing from context.
  - `validate(ValidatorClass, *attr_keys)` — Instantiates a validator (e.g. ActiveModel class), checks `valid?`, merges `to_context` hash back into context on success, or calls `context.fail!` on failure. Optional `attr_keys` slice context before passing to validator.

### Generators

- `ucasy:install` — Creates `app/use_cases/use_case_base.rb` only (gem stays as runtime dependency).
- `ucasy:copy` — Copies all gem source files into `app/use_cases/ucasy/` (gem becomes dev-only dependency).

### Linting

Uses StandardRB (configured via `inherit_gem: standard`) with RuboCop plugins for RSpec and Rake. Target: Ruby 3.4, Rails 8.0.
