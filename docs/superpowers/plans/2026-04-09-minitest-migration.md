# Minitest Migration + README Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace RSpec with Minitest + minitest-reporters, reorganise tests into `test/` mirroring `lib/`, achieve full coverage via TDD, and overhaul README with consistent e-commerce domain-namespaced examples.

**Architecture:** Tests are split one-file-per-class under `test/ucasy/`, matching `lib/ucasy/`. A shared `test/test_helper.rb` boots minitest-reporters and loads the gem. ActiveSupport is added as a dev dependency to support `present?`/`blank?`/`try` used internally. All use case examples in README use domain namespaces (`Auth::`, `Orders::`).

**Tech Stack:** Ruby 3.4, Minitest (stdlib), minitest-reporters, ActiveSupport (dev only), StandardRB, rubocop-minitest

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Delete | `spec/spec_helper.rb` | RSpec boot — replaced by test_helper |
| Delete | `spec/ucasy_spec.rb` | Only existing test — replaced by per-class files |
| Delete | `.rspec` | RSpec CLI config — no longer needed |
| Delete | `bin/rspec` | RSpec binstub — no longer needed |
| Modify | `Gemfile` | Remove rspec/rubocop-rspec/capybara/factory_bot; add minitest-reporters, activesupport, rubocop-minitest |
| Modify | `Rakefile` | Replace RSpec rake task with Rake::TestTask |
| Modify | `.rubocop.yml` | Remove rubocop-rspec; add rubocop-minitest |
| Create | `test/test_helper.rb` | Minitest boot, reporters, load path |
| Create | `test/ucasy/context_test.rb` | Context.build, fail!, failure?, success? |
| Create | `test/ucasy/callable_test.rb` | NotImplementedError on base, subclass works |
| Create | `test/ucasy/failure_test.rb` | Is StandardError, carries context |
| Create | `test/ucasy/validators/required_attributes_test.rb` | Raises on missing, passes when present |
| Create | `test/ucasy/validators/validate_test.rb` | valid/invalid validator behaviour, attr slicing |
| Create | `test/ucasy/base_test.rb` | Lifecycle hooks, short-circuit, required_attributes, validate, method_missing proxy |
| Create | `test/ucasy/flow_test.rb` | Sequential execution, shared context, transactional stub |
| Modify | `README.md` | E-commerce domain examples, all sections aligned to real implementation |

---

## Task 1: Remove RSpec artefacts

**Files:**
- Delete: `spec/spec_helper.rb`, `spec/ucasy_spec.rb`, `.rspec`, `bin/rspec`

- [ ] **Step 1: Delete RSpec files**

```bash
rm spec/spec_helper.rb spec/ucasy_spec.rb .rspec bin/rspec
```

- [ ] **Step 2: Verify deletions**

```bash
ls spec/ bin/
```
Expected: `spec/` is empty or gone; `bin/` no longer contains `rspec`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove RSpec artefacts"
```

---

## Task 2: Update Gemfile

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Replace Gemfile content**

```ruby
source "https://rubygems.org"

gemspec

gem "rake"
gem "minitest-reporters"
gem "activesupport"
gem "brakeman"
gem "standard"
gem "standard-rails"
gem "rubocop-rake"
gem "rubocop-minitest"
```

- [ ] **Step 2: Install**

```bash
bundle install
```

Expected: Resolves without errors. `rspec`, `rspec-rails`, `rubocop-rspec`, `rubocop-capybara`, `rubocop-factory_bot` are no longer in the lockfile.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: replace RSpec gems with minitest-reporters"
```

---

## Task 3: Update Rakefile and RuboCop config

**Files:**
- Modify: `Rakefile`
- Modify: `.rubocop.yml`

- [ ] **Step 1: Rewrite Rakefile**

```ruby
require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

require "standard/rake"

task default: %i[test standard]
```

- [ ] **Step 2: Rewrite .rubocop.yml**

```yaml
require:
  - rubocop-rake
  - rubocop-minitest

inherit_gem:
  standard: config/base.yml

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.4
  TargetRailsVersion: 8.0
```

- [ ] **Step 3: Verify Rake loads**

```bash
bundle exec rake -T
```

Expected: Lists `rake test` and `rake standard`, no RSpec tasks.

- [ ] **Step 4: Commit**

```bash
git add Rakefile .rubocop.yml
git commit -m "chore: switch rake task to Minitest, add rubocop-minitest"
```

---

## Task 4: Create test infrastructure

**Files:**
- Create: `test/test_helper.rb`

- [ ] **Step 1: Write test_helper.rb**

```ruby
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "active_support/all"
require "ucasy"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
```

- [ ] **Step 2: Verify it loads**

```bash
bundle exec ruby -r "./test/test_helper" -e "puts 'OK'"
```

Expected: `OK` with no errors.

- [ ] **Step 3: Commit**

```bash
git add test/test_helper.rb
git commit -m "test: add minitest test_helper with reporters"
```

---

## Task 5: Context tests (TDD)

**Files:**
- Create: `test/ucasy/context_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Ucasy::ContextTest < Minitest::Test
  def test_build_from_hash_returns_context_instance
    context = Ucasy::Context.build(name: "Alice")

    assert_instance_of Ucasy::Context, context
    assert_equal "Alice", context.name
  end

  def test_build_from_existing_context_returns_same_object
    original = Ucasy::Context.new(name: "Alice")
    result = Ucasy::Context.build(original)

    assert_same original, result
  end

  def test_fail_sets_failure_state
    context = Ucasy::Context.new

    begin
      context.fail!(message: "oops")
    rescue Ucasy::Failure
    end

    assert_predicate context, :failure?
    refute_predicate context, :success?
  end

  def test_fail_raises_ucasy_failure
    context = Ucasy::Context.new

    assert_raises(Ucasy::Failure) { context.fail! }
  end

  def test_fail_sets_options_on_context
    context = Ucasy::Context.new

    begin
      context.fail!(status: :unprocessable_entity, message: "bad input")
    rescue Ucasy::Failure
    end

    assert_equal :unprocessable_entity, context.status
    assert_equal "bad input", context.message
  end

  def test_failure_exception_carries_context_reference
    context = Ucasy::Context.new

    error = assert_raises(Ucasy::Failure) { context.fail!(message: "oops") }

    assert_same context, error.context
  end

  def test_success_by_default
    context = Ucasy::Context.new

    assert_predicate context, :success?
    refute_predicate context, :failure?
  end

  def test_dynamic_attribute_assignment
    context = Ucasy::Context.new
    context.order_id = 42

    assert_equal 42, context.order_id
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/context_test.rb
```

Expected: 8 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/context_test.rb
git commit -m "test: add Ucasy::Context tests"
```

---

## Task 6: Callable tests (TDD)

**Files:**
- Create: `test/ucasy/callable_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Ucasy::CallableTest < Minitest::Test
  class ConcreteCallable < Ucasy::Callable
    def call
      "concrete result"
    end
  end

  def test_call_raises_not_implemented_error_on_base
    assert_raises(NotImplementedError) { Ucasy::Callable.new.call }
  end

  def test_class_call_instantiates_and_calls
    result = ConcreteCallable.call

    assert_equal "concrete result", result
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/callable_test.rb
```

Expected: 2 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/callable_test.rb
git commit -m "test: add Ucasy::Callable tests"
```

---

## Task 7: Failure tests (TDD)

**Files:**
- Create: `test/ucasy/failure_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Ucasy::FailureTest < Minitest::Test
  def test_is_a_standard_error
    assert_operator Ucasy::Failure, :<, StandardError
  end

  def test_carries_context_reference
    context = Ucasy::Context.new(order_id: 99)
    error = Ucasy::Failure.new(context)

    assert_same context, error.context
  end

  def test_context_defaults_to_nil
    error = Ucasy::Failure.new

    assert_nil error.context
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/failure_test.rb
```

Expected: 3 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/failure_test.rb
git commit -m "test: add Ucasy::Failure tests"
```

---

## Task 8: RequiredAttributes validator tests (TDD)

**Files:**
- Create: `test/ucasy/validators/required_attributes_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Ucasy::Validators::RequiredAttributesTest < Minitest::Test
  class FakeUseCase; end

  def test_raises_argument_error_when_attribute_missing
    context = Ucasy::Context.new(email: "user@example.com")

    error = assert_raises(ArgumentError) do
      Ucasy::Validators::RequiredAttributes.call(context, [:password], FakeUseCase)
    end

    assert_match(/password/, error.message)
    assert_match(/FakeUseCase/, error.message)
  end

  def test_passes_silently_when_all_attributes_present
    context = Ucasy::Context.new(email: "user@example.com", password: "secret")

    assert_nil Ucasy::Validators::RequiredAttributes.call(context, [:email, :password], FakeUseCase)
  end

  def test_passes_with_empty_required_list
    context = Ucasy::Context.new

    assert_nil Ucasy::Validators::RequiredAttributes.call(context, [], FakeUseCase)
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/validators/required_attributes_test.rb
```

Expected: 3 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/validators/required_attributes_test.rb
git commit -m "test: add RequiredAttributes validator tests"
```

---

## Task 9: Validate validator tests (TDD)

**Files:**
- Create: `test/ucasy/validators/validate_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Ucasy::Validators::ValidateTest < Minitest::Test
  class ValidValidator
    def initialize(attrs)
      @attrs = attrs
    end

    def valid? = true
    def errors = {}
    def message_error = nil
    def to_context = { email: @attrs[:email] }
  end

  class InvalidValidator
    def initialize(_attrs); end

    def valid? = false
    def errors = { email: ["can't be blank"] }
    def message_error = "Email can't be blank"
    def to_context = {}
  end

  def test_valid_returns_true_for_valid_validator
    validator = Ucasy::Validators::Validate.call(ValidValidator, { email: "a@b.com" })

    assert_predicate validator, :valid?
    refute_predicate validator, :invalid?
  end

  def test_valid_returns_false_for_invalid_validator
    validator = Ucasy::Validators::Validate.call(InvalidValidator, {})

    refute_predicate validator, :valid?
    assert_predicate validator, :invalid?
  end

  def test_to_context_returns_validator_to_context_when_valid
    validator = Ucasy::Validators::Validate.call(ValidValidator, { email: "a@b.com" })

    assert_equal({ email: "a@b.com" }, validator.to_context)
  end

  def test_to_context_returns_empty_hash_when_invalid
    validator = Ucasy::Validators::Validate.call(InvalidValidator, {})

    assert_equal({}, validator.to_context)
  end

  def test_errors_returns_validator_errors
    validator = Ucasy::Validators::Validate.call(InvalidValidator, {})

    assert_equal({ email: ["can't be blank"] }, validator.errors)
  end

  def test_message_returns_validator_message_error
    validator = Ucasy::Validators::Validate.call(InvalidValidator, {})

    assert_equal "Email can't be blank", validator.message
  end

  def test_attributes_are_sliced_when_keys_provided
    # Only :email key is passed to validator, :password is excluded
    captured_attrs = nil
    capturing_class = Class.new do
      define_method(:initialize) { |attrs| captured_attrs = attrs }
      def valid? = true
      def errors = {}
      def message_error = nil
      def to_context = {}
    end

    Ucasy::Validators::Validate.call(capturing_class, { email: "a@b.com", password: "secret" })

    assert_equal({ email: "a@b.com", password: "secret" }, captured_attrs)
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/validators/validate_test.rb
```

Expected: 7 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/validators/validate_test.rb
git commit -m "test: add Validate validator tests"
```

---

## Task 10: Base tests (TDD)

**Files:**
- Create: `test/ucasy/base_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Ucasy::BaseTest < Minitest::Test
  # --- Helpers ---

  class OrderRecorder < Ucasy::Base
    def before = context.steps << :before
    def call    = context.steps << :call
    def after   = context.steps << :after
  end

  class FailInBefore < Ucasy::Base
    def before = context.fail!(message: "failed in before")
    def call   = context.steps << :call
    def after  = context.steps << :after
  end

  class FailInCall < Ucasy::Base
    def before = context.steps << :before
    def call   = context.fail!(message: "failed in call")
    def after  = context.steps << :after
  end

  class WithRequired < Ucasy::Base
    required_attributes(:order_id, :user_id)

    def call = nil
  end

  class ValidValidator
    def initialize(attrs)
      @attrs = attrs
    end

    def valid? = true
    def errors = {}
    def message_error = nil
    def to_context = { card_token: @attrs[:card_token] }
  end

  class InvalidValidator
    def initialize(_attrs); end

    def valid? = false
    def errors = { card_token: ["is invalid"] }
    def message_error = "Card token is invalid"
    def to_context = {}
  end

  class WithValidValidator < Ucasy::Base
    validate ValidValidator, :card_token

    def call = nil
  end

  class WithInvalidValidator < Ucasy::Base
    validate InvalidValidator

    def call = context.steps << :call
  end

  class ContextProxy < Ucasy::Base
    attr_reader :proxied_value

    def call
      @proxied_value = order_id  # order_id resolved via method_missing → context.order_id
    end
  end

  # --- Tests ---

  def test_lifecycle_order_before_call_after
    result = OrderRecorder.call(steps: [])

    assert_equal [:before, :call, :after], result.context.steps
  end

  def test_call_skips_all_hooks_when_pre_failed
    pre_failed_context = Ucasy::Context.new(steps: [])

    begin
      pre_failed_context.fail!
    rescue Ucasy::Failure
    end

    result = OrderRecorder.call(pre_failed_context)

    assert_empty result.context.steps
  end

  def test_after_not_called_when_before_fails
    result = FailInBefore.call(steps: [])

    assert_predicate result.context, :failure?
    refute_includes result.context.steps, :call
    refute_includes result.context.steps, :after
  end

  def test_after_not_called_when_call_fails
    result = FailInCall.call(steps: [])

    assert_predicate result.context, :failure?
    assert_includes result.context.steps, :before
    refute_includes result.context.steps, :after
  end

  def test_required_attributes_raises_when_missing
    assert_raises(ArgumentError) { WithRequired.call(order_id: 1) }
  end

  def test_required_attributes_passes_when_present
    result = WithRequired.call(order_id: 1, user_id: 2)

    assert_predicate result.context, :success?
  end

  def test_validate_merges_to_context_when_valid
    result = WithValidValidator.call(card_token: "tok_123")

    assert_predicate result.context, :success?
    assert_equal "tok_123", result.context.card_token
  end

  def test_validate_fails_context_when_invalid
    result = WithInvalidValidator.call

    assert_predicate result.context, :failure?
    assert_equal "Card token is invalid", result.context.message
  end

  def test_method_missing_proxies_to_context
    use_case = ContextProxy.call(order_id: 42)

    assert_equal 42, use_case.proxied_value
  end

  def test_returns_self_after_perform
    result = OrderRecorder.call(steps: [])

    assert_instance_of OrderRecorder, result
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/base_test.rb
```

Expected: 10 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/base_test.rb
git commit -m "test: add Ucasy::Base lifecycle and validation tests"
```

---

## Task 11: Flow tests (TDD)

**Files:**
- Create: `test/ucasy/flow_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

# Minimal ActiveRecord stub for transactional tests
module ActiveRecord
  class Rollback < StandardError; end

  class Base
    def self.transaction
      yield
    rescue Rollback
      # simulates AR rollback — swallowed, transaction aborted
    end
  end
end

class Ucasy::FlowTest < Minitest::Test
  # --- Helpers ---

  class AppendStep < Ucasy::Base
    def call
      context.steps << self.class.name.split("::").last
    end
  end

  class StepA < AppendStep; end
  class StepB < AppendStep; end
  class StepC < AppendStep; end

  class FailingStep < Ucasy::Base
    def call
      context.fail!(message: "step failed")
    end
  end

  # Use Ucasy::Flow directly since UseCaseBase isn't defined here
  class SequentialFlow < Ucasy::Flow
    flow StepA, StepB, StepC
  end

  class FlowFailingMidway < Ucasy::Flow
    flow StepA, FailingStep, StepB
  end

  class TransactionalFlow < Ucasy::Flow
    transactional
    flow StepA, FailingStep, StepB
  end

  class TransactionalSuccessFlow < Ucasy::Flow
    transactional
    flow StepA, StepB, StepC
  end

  # --- Tests ---

  def test_executes_use_cases_in_order
    result = SequentialFlow.call(steps: [])

    assert_equal %w[StepA StepB StepC], result.context.steps
  end

  def test_shared_context_passed_through_all_use_cases
    result = SequentialFlow.call(steps: [], shared_value: 42)

    assert_equal 42, result.context.shared_value
    assert_equal 3, result.context.steps.length
  end

  def test_non_transactional_continues_after_failure
    result = FlowFailingMidway.call(steps: [])

    assert_predicate result.context, :failure?
    # StepA ran, FailingStep failed, StepB perform returns early (context failed)
    assert_includes result.context.steps, "StepA"
    refute_includes result.context.steps, "StepB"
  end

  def test_transactional_stops_on_failure
    result = TransactionalFlow.call(steps: [])

    assert_predicate result.context, :failure?
    assert_includes result.context.steps, "StepA"
    refute_includes result.context.steps, "StepB"
  end

  def test_transactional_completes_when_all_succeed
    result = TransactionalSuccessFlow.call(steps: [])

    assert_predicate result.context, :success?
    assert_equal %w[StepA StepB StepC], result.context.steps
  end

  def test_returns_self
    result = SequentialFlow.call(steps: [])

    assert_instance_of SequentialFlow, result
  end
end
```

- [ ] **Step 2: Run and verify all pass**

```bash
bundle exec ruby -Itest test/ucasy/flow_test.rb
```

Expected: 6 tests, 0 failures, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add test/ucasy/flow_test.rb
git commit -m "test: add Ucasy::Flow sequential and transactional tests"
```

---

## Task 12: Run full test suite

- [ ] **Step 1: Run all tests**

```bash
bundle exec rake test
```

Expected: All test files run, 0 failures, 0 errors. Output shows SpecReporter with green checkmarks.

- [ ] **Step 2: Run linter**

```bash
bundle exec rake standard
```

Expected: No offenses.

- [ ] **Step 3: Run default task (tests + linter)**

```bash
bundle exec rake
```

Expected: Passes fully.

- [ ] **Step 4: Commit if any lint fixes were needed**

```bash
git add -A
git commit -m "chore: fix any lint issues after minitest migration"
```

---

## Task 13: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite README.md**

```markdown
# Ucasy

Ucasy is a lightweight Ruby gem that helps you structure business logic in Rails applications using the use case pattern. It provides lifecycle hooks, input validation, and composable flows — making complex application logic easy to build, test, and maintain.

## Installation

### As a gem dependency

```ruby
gem "ucasy", "~> 0.3.3"
```

```bash
bin/bundle install
```

### Copy files into your app (no runtime gem dependency)

```ruby
group :development do
  gem "ucasy", "~> 0.3.3", require: false
end
```

```bash
bin/bundle install
bin/rails g ucasy:copy
```

## Setup

Generate the base class your use cases will inherit from:

```bash
bin/rails g ucasy:install
```

This creates `app/use_cases/use_case_base.rb`:

```ruby
class UseCaseBase < Ucasy::Base
  class Flow < Ucasy::Flow
  end
end
```

## Basic Use Case

```ruby
# app/use_cases/auth/authenticate_user.rb
module Auth
  class AuthenticateUser < UseCaseBase
    def before
      context.user = User.find_by(login: context.login)
    end

    def call
      return if context.user&.valid_password?(context.password)

      context.fail!(
        status: :unprocessable_entity,
        message: "Invalid credentials"
      )
    end

    def after
      UserMailer.with(user: context.user).login_notification.deliver_later
    end
  end
end
```

Invoke it from a controller:

```ruby
result = Auth::AuthenticateUser.call(login: params[:login], password: params[:password])

if result.context.success?
  sign_in result.context.user
else
  render json: { error: result.context.message }, status: result.context.status
end
```

Hooks run in order: `before → call → after`. If any hook calls `context.fail!`, subsequent hooks are skipped.

## Validating Required Attributes

Use `required_attributes` to declare which context keys must be present before `call` runs:

```ruby
module Auth
  class AuthenticateUser < UseCaseBase
    required_attributes :login, :password

    def call
      user = User.find_by(login: context.login)

      return if user&.valid_password?(context.password)

      context.fail!(status: :unprocessable_entity, message: "Invalid credentials")
    end
  end
end
```

If `login` or `password` is missing from the context, an `ArgumentError` is raised immediately.

## Validating with a Validator Class

For richer validation, pass any object that responds to `valid?`, `errors`, `message_error`, and `to_context`:

```ruby
# app/use_cases/orders/validations/place_order_validation.rb
module Orders
  module Validations
    class PlaceOrderValidation
      include ActiveModel::Model

      attr_accessor :card_token, :total

      validates :card_token, presence: true
      validates :total, numericality: { greater_than: 0 }

      def message_error
        errors.full_messages.first
      end

      def to_context
        { card_token:, total: }
      end
    end
  end
end
```

```ruby
# app/use_cases/orders/place_order.rb
module Orders
  class PlaceOrder < UseCaseBase
    validate Validations::PlaceOrderValidation, :card_token, :total

    def call
      context.order = Order.create!(
        card_token: context.card_token,
        total: context.total
      )
    end
  end
end
```

The optional list of keys (`*card_token, :total`) slices the context before passing it to the validator — useful when context contains unrelated data. On success, `to_context` is merged back into the context.

## Composing Use Cases with Flows

Flows chain multiple use cases, sharing a single context:

```ruby
# app/use_cases/orders/charge_card.rb
module Orders
  class ChargeCard < UseCaseBase
    def call
      charge = PaymentGateway.charge(context.card_token, context.total)

      return context.charge = charge if charge.success?

      context.fail!(status: :payment_required, message: charge.error)
    end
  end
end

# app/use_cases/orders/send_confirmation.rb
module Orders
  class SendConfirmation < UseCaseBase
    def call
      OrderMailer.with(order: context.order).confirmation.deliver_later
    end
  end
end

# app/use_cases/orders/fulfill_order.rb
module Orders
  class FulfillOrder < UseCaseBase
    def call
      context.order.update!(fulfilled: true)
    end
  end
end
```

```ruby
# app/use_cases/orders/checkout.rb
module Orders
  class Checkout < UseCaseBase::Flow
    transactional

    validate Validations::PlaceOrderValidation, :card_token, :total

    flow PlaceOrder, ChargeCard, SendConfirmation, FulfillOrder
  end
end
```

`transactional` wraps execution in `ActiveRecord::Base.transaction`. If any use case calls `context.fail!`, the transaction is rolled back.

## Reusing Use Cases in Flows and Standalone

Use cases can be called directly or composed into flows — the interface is identical:

```ruby
# Standalone — useful in background jobs, rake tasks, etc.
result = Orders::ChargeCard.call(card_token: "tok_abc", total: 49.99)

if result.context.success?
  puts "Charged: #{result.context.charge.id}"
end

# Inside a flow — same use case, no changes needed
module Orders
  class Checkout < UseCaseBase::Flow
    transactional
    flow PlaceOrder, ChargeCard, SendConfirmation, FulfillOrder
  end
end
```

Context is passed through every use case in a flow, so data produced by an earlier step (e.g., `context.order` set by `PlaceOrder`) is available to all subsequent steps.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/LaVendaSoftware/ucasy.

## License

MIT License — see [LICENSE.txt](LICENSE.txt).
```

- [ ] **Step 2: Verify README renders correctly**

```bash
cat README.md | head -20
```

Expected: Starts with `# Ucasy` heading.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: overhaul README with e-commerce domain examples and real implementation alignment"
```

---

## Task 14: Final verification

- [ ] **Step 1: Run full suite**

```bash
bundle exec rake
```

Expected: All tests green, standard passes, no warnings.

- [ ] **Step 2: Verify no rspec references remain**

```bash
grep -r "rspec\|RSpec\|describe.*do\|expect(" --include="*.rb" lib/ test/ Gemfile Rakefile
```

Expected: Zero matches.

- [ ] **Step 3: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "chore: minitest migration complete"
```
