module Lr
  class Rule
    attr_reader :id, :from, :exps
    attr_accessor :ptr, :look_ahead

    def initialize(id, from, exps=nil)
      from, *exps = from if exps.nil?
      @id = id
      @from = from
      @exps = exps
      @ptr = 0
      @look_ahead = []
    end

    def elems
      [from, *exps]
    end

    def to_s
      "#{from} -> #{exps.join(' ')} [#{@look_ahead.map{|l| l ? l : 'nil'}.join(',')}]"
    end

    def current
      @exps[@ptr]
    end

    def ==(o)
      @id == o.id && @ptr == o.ptr && @look_ahead == o.look_ahead
    end

    def equal_without_look_ahead(o)
      @id == o.id && @ptr == o.ptr
    end
  end

  class Grammer
    attr_reader :rules, :terms, :symbols, :start_symbol, :firsts, :follows, :states, :table

    def initialize(rules)
      @rules = rules.map.with_index{|rule, i| Rule.new(i, rule)}
      @start_symbol = @rules.first.from
      @symbols, @terms = @rules.map(&:elems).flatten.uniq.partition{|elem| elem.is_a?(Symbol)}
      @firsts = {}
      resolve_firsts(@start_symbol)
      #resolve_follows
      @states = TransitionStateList.new(self)
      @table = Table.new(self)
    end

    def to_s
      @rules.map(&:to_s).join("\n")
    end

    private
    def resolve_firsts(sym)
      @firsts[sym] ||= @rules
        .select{|rule| rule.from == sym && rule.exps.first != sym }
        .map{|rule| rule.exps.first.is_a?(Symbol) ? resolve_firsts(rule.exps.first) : rule.exps.first }
        .flatten
    end

    def resolve_follows
      @follows = @symbols.map{|sym| [sym, []]}.to_h
      @follows[:s] = [nil]
      @rules.each do |rule|
        rule.exps.each_cons(2) do |exp, follow|
          next unless exp.is_a?(Symbol)
          @follows[exp].push follow
        end
        @follows[rule.exps.last].push rule.from if rule.exps.last.is_a?(Symbol)
      end
      @follows.each{|sym, elems| elems.uniq!}
      @symbols.each{|sym| resolve_symbol_follows(sym)}
    end

    def resolve_symbol_follows(sym)
      # MEMO: terms includes nil
      symbols, terms = @follows[sym].partition{|elem| elem.is_a?(Symbol)}
      return terms if symbols.empty?
      symbols.each do |sym|
        terms.concat resolve_symbol_follows(sym)
      end
      @follows[sym] = terms.uniq
    end
  end

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
          @rules.concat Lr.deep_clone(new_rules)
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
        rule = Lr.deep_clone(rule)
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

  class TransitionStateList
    attr_accessor :list, :stack

    def initialize(grammer)
      @g = grammer
      @list = []
      state = TransitionState.new(0, @g, Lr.deep_clone(@g.rules), self)
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

  class Table
    def initialize(grammer)
      @g = grammer
      @states = @g.states
      @table = {}
      @states.list.each do |state|
        @table[state.id] = {}
        state.transitions.map do |sym, to|
          @table[state.id][sym] = [sym.is_a?(Symbol) ? :goto : :shift, to]
        end
        state.rules.each do |rule|
          next unless rule.current.nil?
          if rule.from == @g.start_symbol
            @table[state.id][nil] = [:acc]
          else
            rule.look_ahead.each do |term|
              raise "#{@table[state.id][term][0]} / reduce conflict" if @table[state.id][term]
              @table[state.id][term] = [:reduce, rule.id]
            end
          end
        end
      end
    end

    def to_s
      columns = [*@g.terms, nil, *@g.symbols]
      columns.delete(@g.start_symbol)
      str = ''
      str << "    |" + columns.map{|t| (t||'$').to_s.rjust(5)}.join('|') + "\n"
      str << "----" + "------" * columns.size + "\n"
      @table.each do |id, row|
        str << id.to_s.rjust(4) + "|" + columns.map{|t| row[t] ? (row[t][0][0] + (row[t][1].to_s||'')).rjust(5) : ' '*5}.join('|') + "\n"
      end
      str
    end
  end

  def self.deep_clone(obj)
    Marshal.load(Marshal.dump(obj))
  end
end

if __FILE__ == $0
  require 'pp'
  require 'pry'
  def lalr1
    g = Lr::Grammer.new [
      [:s, :a],
      [:a, :e, '=', :e],
      [:a, 'id'],
      [:e, :e, '+', :t],
      [:e, :t],
      [:t, 'num'],
      [:t, 'id']
    ]
    puts g.states
    puts g.table
  end
  lalr1
end