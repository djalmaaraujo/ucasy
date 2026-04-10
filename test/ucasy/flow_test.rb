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
