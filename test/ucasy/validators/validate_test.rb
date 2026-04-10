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
end
