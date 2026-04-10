$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "active_support/all"
require "ucasy"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
