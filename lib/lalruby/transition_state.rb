module Lalruby
  class TransitionState
    attr_reader :id, :transitions, :rules
    def initialize(id, grammer, rules, list)
      @id = id
      @g = grammer
      @list = list
      @rules = rules
      @transitions = {}
      # expand [A -> v @ B] to rules that starts with B [B -> *]
      begin
        current_rule_size = @rules.size
        @rules.each do |rule|
          next unless rule.ptr + 1 == rule.exps.size
          target = rule.current
          next unless target.is_a?(Symbol)
          new_rules = @g.rules.select{|rule| rule.from == target}
          next if (new_rules.map(&:id) - @rules.map(&:id)).empty?
          @rules.concat Lalruby.deep_clone(new_rules)
          resolve_look_ahead
        end
      end while current_rule_size != @rules.size
    end

    def resolve_look_ahead
      begin
        updated = false
        @rules.each do |rule|
          next unless Symbol === rule.current
          next_elem = rule.exps[rule.ptr + 1]
          if next_elem == nil
            resolved = rule.look_ahead
          elsif Symbol === next_elem
            resolved = @g.firsts[next_elem]
          else
            resolved = [next_elem]
          end
          next if resolved.empty?
          @rules.each do |updating_rule|
            next if updating_rule.from != rule.current
            next if (resolved - updating_rule.look_ahead).empty?
            updated = true
            updating_rule.look_ahead.concat resolved
            updating_rule.look_ahead.uniq!
          end
        end
      end while updated
      self
    end

    def succeed(id)
      next_rules = {}
      # separate rules to branch
      @rules.each do |rule|
        next if rule.current.nil?
        rule = Lalruby.deep_clone(rule)
        next_rules[rule.current] ||= []
        next_rules[rule.current].push rule
        rule.ptr += 1
      end
      # create children
      next_states = []
      next_rules.each do |sym, rules|
        state = TransitionState.new(id, @g, rules, @list)
        # join to existing state
        joined = false
        [*@list.list, *@list.stack].each do |exisiting_state|
          next if exisiting_state != state
          @transitions[sym] = exisiting_state.id
          joined = true
        end
        unless joined
          @transitions[sym] = id
          id += 1
          next_states.push state
        end
      end
      next_states
    end

    def to_s
      "#{@id} : #{@transitions.map{|sym,id| "#{sym} -> #{id}"}.join(', ')}"
    end

    def ==(o)
      return false if @rules.size != o.rules.size
      @rules.zip(o.rules).all? {|r| r[0] == r[1]} # this == is override method
    end

    def equal_without_look_ahead(o)
      return false if @rules.size != o.rules.size
      @rules.zip(o.rules).all? {|r| r[0].equal_without_look_ahead r[1]}
    end
  end
end