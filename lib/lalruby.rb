require "lalruby/version"
require "lalruby/rule"
require "lalruby/grammer"
require "lalruby/transition_state"
require "lalruby/transition_state_list"
require "lalruby/table"
require "lalruby/parser"

require 'pp' # TODO: remove this

module Lalruby
  def self.deep_clone(obj)
    Marshal.load(Marshal.dump(obj))
  end
end
