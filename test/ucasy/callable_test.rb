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
