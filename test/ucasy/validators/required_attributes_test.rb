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

  def test_passes_when_required_attribute_is_nil
    # OpenStruct returns true for respond_to? when key exists, even if value is nil.
    # This documents the current behaviour: nil values satisfy required_attributes.
    context = Ucasy::Context.new(password: nil)

    assert_nil Ucasy::Validators::RequiredAttributes.call(context, [:password], FakeUseCase)
  end
end
