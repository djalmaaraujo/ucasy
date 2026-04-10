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
