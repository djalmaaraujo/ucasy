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
