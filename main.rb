module Lr
  class Rule
    attr_reader :id, :from, :exps
    attr_accessor :ptr

    def initialize(id, from, exps=nil)
      from, *exps = from if exps.nil?
      @id = id
      @from = from
      @exps = exps
      @ptr = 0
    end

    def elems
      [from, *exps]
    end

    def to_s
      "#{from} -> #{exps.join(' ')}"
    end

    def current
      @exps[@ptr]
    end

    def terminated?
      @ptr + 1 == @exps.size
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
      resolve_follows
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
    def initialize(id, grammer, rules)
      @id = id
      @g = grammer
      @rules = Marshal.load(Marshal.dump(rules))
      @transitions = {}
    end

    def succeed(id)
      # separate rules to branch
      @rules.each do |rule|
        next if rule.current.nil?
        rule = Marshal.load(Marshal.dump(rule))
        @transitions[rule.current] ||= []
        @transitions[rule.current].push rule
        rule.ptr += 1
      end
      # create children
      @transitions.map do |sym, rules|
        state = TransitionState.new(id, @g, rules)
        @transitions[sym] = id
        id += 1
        state
      end
    end

    def to_s
      "#{@id} : #{@transitions.map{|sym,id| "#{sym} -> #{id}"}.join(', ')}"
    end
  end

  class TransitionStateList
    attr_accessor :list

    def initialize(grammer)
      @g = grammer
      @list = []
      stack = [TransitionState.new(0, @g, @g.rules)]
      while !stack.empty?
        state = stack.shift
        @list.push state
        stack.concat state.succeed(@list.size + stack.size)
      end
    end

    def to_s
      @list.map(&:to_s).join("\n")
    end
  end

  class Table
    def initialize(grammer)
      @g = grammer
      @states = @g.states
      @table = []
      @states.list.each do |state|
        @table[state.id] = {}
        state.transitions.map do |sym, to|
          @table[state.id][sym] = [sym.is_a?(Symbol) ? :goto : :shift, to]
        end
        # MEMO: error if terminated rules > 1
        state.rules.each do |rule|
          next unless rule.current.nil?
          if rule.from == @g.start_symbol
            @table[state.id][nil] = [:acc]
          else
            [*@g.terms, nil].each do |term|
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
      @table.each_with_index do |row, id|
        str << id.to_s.rjust(4) + "|" + columns.map{|t| row[t] ? (row[t][0][0] + (row[t][1].to_s||'')).rjust(5) : ' '*5}.join('|') + "\n"
      end
      str
    end
  end
end

if __FILE__ == $0
  require 'pp'
  require 'pry'
  # lr0 = Lr::Grammer.new [
  #   [:s, :e],
  #   [:e, :e, '+', 'num'],
  #   [:e, :e, '*', 'num'],
  #   [:e, 'num']
  # ]
  # puts lr0.states
  # puts lr0.table
  slr1 = Lr::Grammer.new [
    [:s, :e],
    [:e, :e, '+', :t],
    [:e, :t],
    [:t, :t, '*', 'num'],
    [:t, 'num']
  ]
  puts slr1.states
  puts slr1.table
end