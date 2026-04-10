require "test_helper"

class Ucasy::BaseTest < Minitest::Test
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
