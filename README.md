# Ucasy

Ucasy is a lightweight Ruby gem that helps you structure business logic in Rails applications using the use case pattern. It provides lifecycle hooks, input validation, and composable flows — making complex application logic easy to build, test, and maintain.

## Installation

### As a gem dependency

Add to your application's Gemfile:

```ruby
gem "ucasy", "~> 0.3.3"
```

Then run:

```bash
bin/bundle install
```

### Copy files into your app (no runtime gem dependency)

Add to your Gemfile:

```ruby
group :development do
  gem "ucasy", "~> 0.3.3", require: false
end
```

Then:

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

Create a use case under a domain namespace:

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

Invoke from a controller:

```ruby
result = Auth::AuthenticateUser.call(login: params[:login], password: params[:password])

if result.context.success?
  sign_in result.context.user
else
  render json: { error: result.context.message }, status: result.context.status
end
```

Hooks run in order: `before → call → after`. If any hook calls `context.fail!`, subsequent hooks are skipped and the use case returns immediately.

## Declaring Required Attributes

Use `required_attributes` to ensure specific keys are present in the context before `call` runs:

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

If `:login` or `:password` is missing from the context, an `ArgumentError` is raised immediately.

## Validating with a Validator Class

For richer validation, pass any class that responds to `valid?`, `errors`, `message_error`, and `to_context`:

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

The optional attribute list (`:card_token, :total`) slices the context before passing it to the validator — useful when context contains unrelated keys. On success, `to_context` is merged back into the context.

## Composing Use Cases with Flows

Flows chain multiple use cases sharing a single context. Each use case can read data written by a previous step.

### Defining the steps

```ruby
# app/use_cases/orders/place_order.rb
module Orders
  class PlaceOrder < UseCaseBase
    def call
      # reads: context.card_token, context.total (set by validator via to_context)
      # writes: context.order
      context.order = Order.create!(card_token: context.card_token, total: context.total)
    end
  end
end

# app/use_cases/orders/charge_card.rb
module Orders
  class ChargeCard < UseCaseBase
    def call
      # reads: context.card_token, context.total
      # writes: context.charge
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
      # reads: context.order (written by PlaceOrder)
      OrderMailer.with(order: context.order).confirmation.deliver_later
    end
  end
end

# app/use_cases/orders/fulfill_order.rb
module Orders
  class FulfillOrder < UseCaseBase
    def call
      # reads: context.order (written by PlaceOrder)
      context.order.update!(fulfilled: true)
    end
  end
end
```

### Assembling the flow

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

### How context chains through each step

When `Orders::Checkout.call(card_token: "tok_abc", total: 49.99)` is called:

```
Input context:      { card_token: "tok_abc", total: 49.99 }
  ↓ validate        merges to_context → { card_token: "tok_abc", total: 49.99 }
  ↓ PlaceOrder      writes context.order = #<Order id=1>
  ↓ ChargeCard      writes context.charge = #<Charge id=ch_x>
  ↓ SendConfirmation  enqueues email (reads context.order)
  ↓ FulfillOrder    updates context.order.fulfilled = true
Output context:     { card_token: "tok_abc", total: 49.99, order: #<Order>, charge: #<Charge> }
```

If `ChargeCard` calls `context.fail!`, the remaining steps are skipped and the transaction rolls back:

```
  ↓ PlaceOrder      writes context.order = #<Order id=1>
  ↓ ChargeCard      calls context.fail! → remaining steps skipped, transaction rolls back
  ✗ SendConfirmation  (skipped)
  ✗ FulfillOrder    (skipped)
Output context:     { ..., failure: true, status: :payment_required, message: "Card declined" }
```

### Invoking from a controller

```ruby
result = Orders::Checkout.call(card_token: params[:card_token], total: params[:total])

if result.context.success?
  render json: { order_id: result.context.order.id }
else
  render json: { error: result.context.message }, status: result.context.status
end
```

`transactional` wraps execution in `ActiveRecord::Base.transaction`. If any use case calls `context.fail!`, the transaction is rolled back and no partial writes persist.

## Reusing Use Cases Standalone and in Flows

The same use case can be called directly or composed into a flow — the interface is identical:

```ruby
# Standalone — useful in background jobs, rake tasks, scripts
result = Orders::ChargeCard.call(card_token: "tok_abc", total: 49.99)

if result.context.success?
  puts "Charged: #{result.context.charge.id}"
else
  puts "Failed: #{result.context.message}"
end

# Inside a flow — same use case class, no changes needed
module Orders
  class Checkout < UseCaseBase::Flow
    transactional
    flow PlaceOrder, ChargeCard, SendConfirmation, FulfillOrder
  end
end
```

Context is shared across all use cases in a flow. Data written to context by `PlaceOrder` (e.g. `context.order`) is immediately available to `ChargeCard`, `SendConfirmation`, and `FulfillOrder`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/LaVendaSoftware/ucasy.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
