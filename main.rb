class Lalruby
  attr_accessor :rules
  def initialize(rules)
    @rules = rules
    @symbols, @terms = @rules.flatten.uniq.partition{|elem| elem.is_a?(Symbol)}
    @firsts = {}
    _resolve_first
    _resolve_follow
  end

  def lr0
    @states = [@rules.map{|rule| {ptr: 1, rule: rule}}]
    @state_transitions = []
    _lr0_recursive(0)

  end

  def _lr0_table
    @state_table = []
    @states.each_with_index do |state, id|
      @state_table[id] = {}
      @state_transitions[id].each do |elem, dest|
        @state_table[id][elem] = [:shift, dest]
      end
    end
  end

  def _lr0_transitions(state)
    next_states = {}
    @states[state].each do |extended_rule|
      next if extended_rule[:ptr] == extended_rule[:rule].size
      cloned = Marshal.load(Marshal.dump(extended_rule))
      current = cloned[:rule][cloned[:ptr]]
      next_states[current] ||= []
      next_states[current].push cloned
      cloned[:ptr] += 1
    end
    next_states.each do |elem, extended_rule|
      @states.push extended_rule
      next_state = @states.size - 1
      @state_transitions[state] ||= {}
      @state_transitions[state][elem] = next_state
      _lr0_transitions(next_state)
    end
  end

  private
  def _resolve_first(sym=:s)
    @firsts[sym] = @firsts[sym] || @rules
      .select{|r| r[0] == sym && r[1] != sym }
      .map{|r| r[1].is_a?(Symbol) ? _resolve_first(r[1]) : r[1] }
      .flatten
  end

  def _resolve_follow
    @follows = @symbols.map{|sym| [sym, []]}.to_h
    @follows[:s] = [nil]
    @rules.each do |rule|
      sym, *exps = rule
      exps.each_cons(2) do |exp, follow|
        next unless exp.is_a?(Symbol)
        @follows[exp].push follow
      end
      @follows[exps.last].push sym if exps.last.is_a?(Symbol)
    end
    @follows.each{|sym, elems| elems.uniq!}
    @symbols.each{|sym| _resolve_follow_recursive(sym)}
  end

  private
  def _resolve_follow_recursive(sym)
    # !! terms includes nil !!
    symbols, terms = @follows[sym].partition{|elem| elem.is_a?(Symbol)}
    return terms if symbols.empty?
    symbols.each do |sym|
      terms.concat _resolve_follow_recursive(sym)
    end
    @follows[sym] = terms.uniq
  end
end

if __FILE__ == $0
  require 'pry'
  rules = [ # LR(0)
    [:s, :e],
    [:e, :e, '+', 'num'],
    [:e, :e, '*', 'num'],
    [:e, 'num']
  ]
  # rules = [ # SLR(1)
  #   [:s, :e],
  #   [:e, :e, '+', :t],
  #   [:e, :t],
  #   [:t, :t, '*', 'num'],
  #   [:t, 'num']
  # ]
  # rules = [ # LALR(1)
  #   [:s, :a],
  #   [:a, :e, '=', :e],
  #   [:a, 'id'],
  #   [:e, :e, '+', :t],
  #   [:e, :t],
  #   [:t, 'num'],
  #   [:t, 'id']
  # ]
  rules 
  @p = Lalruby.new(rules)
  @p.lr0
  binding.pry
  puts @p.first(:e)
end