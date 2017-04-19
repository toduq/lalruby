module Lalruby
  class TransitionStateList
    attr_accessor :list, :stack

    def initialize(grammer)
      @g = grammer
      @list = []
      state = TransitionState.new(0, @g, Lalruby.deep_clone(@g.rules), self)
      state.rules.first.look_ahead = [nil]
      state.resolve_look_ahead
      @stack = [state]
      while !@stack.empty?
        state = @stack.shift
        @list.push state
        new_states = state.succeed(@list.size + @stack.size)
        @stack.concat new_states
      end
      merge_lalr_states
    end

    def merge_lalr_states
      @list.combination(2) do |s1, s2|
        next unless s1.equal_without_look_ahead s2
        # merge s2 to s1
        s1.rules.zip(s2.rules).each do |r1, r2|
          r1.look_ahead.concat r2.look_ahead
          r1.look_ahead.uniq!
        end
        @list.each do |state|
          state.transitions.each do |from, to|
            next if to != s2.id
            state.transitions[from] = s1.id
          end
        end
        @list.delete(s2)
        merge_lalr_states
        break
      end
    end

    def to_s
      @list.map(&:to_s).join("\n")
    end

    def dump
      str = ''
      @list.each do |state|
        str << "**" + state.id.to_s + "\n"
        state.rules.each{|rule| str << rule.to_s + "\n"}
      end
      str
    end
  end
end