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
  end

  class Grammer
    attr_reader :rules, :terms, :symbols, :start_symbol, :firsts, :follows, :tree, :table

    def initialize(rules)
      @rules = rules.map.with_index{|rule, i| Rule.new(i, rule)}
      @start_symbol = @rules.first.from
      @symbols, @terms = @rules.map(&:elems).flatten.uniq.partition{|elem| elem.is_a?(Symbol)}
      @firsts = {}
      resolve_firsts(@start_symbol)
      resolve_follows
      @tree = TransitionTree.new(self)
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

  class TransitionTree
    attr_reader :transitions, :rules, :id, :last_id

    def initialize(grammer, id=0, rules=nil)
      @g = grammer
      @id = id
      @last_id = @id
      @rules = rules || @g.rules
      @transitions = {}
      @rules.each do |rule|
        next if rule.current.nil?
        rule = Marshal.load(Marshal.dump(rule))
        @transitions[rule.current] ||= []
        @transitions[rule.current].push rule
        rule.ptr += 1
      end
      @transitions.each do |sym, rules|
        @transitions[sym] = TransitionTree.new(@g, @last_id + 1, rules)
        @last_id = @transitions[sym].last_id
      end
    end

    def flatten(table=[])
      table[@id] = self
      @transitions.values.each{|tree| tree.flatten(table)}
      table
    end

    def to_s
      "#{@id} : #{@transitions.map{|sym,tree| "#{sym} -> #{tree.id}"}.join(', ')}"
    end
  end

  class Table
    def initialize(grammer)
      @g = grammer
      @trees = @g.tree.flatten
      @table = []
      @trees.each do |tree|
        @table[tree.id] = {}
        tree.transitions.map do |sym, child|
          @table[tree.id][sym] = [sym.is_a?(Symbol) ? :goto : :shift, child.id]
        end
        # error if terminated rules > 1
        tree.rules.each do |rule|
          next unless rule.current.nil?
          if rule.from == @g.start_symbol
            @table[tree.id][nil] = [:acc]
          else
            [*@g.terms, nil].each do |term|
              @table[tree.id][term] = [:reduce, rule.id]
            end
          end
        end
      end
    end

    def states_to_s
      @states.map(&:to_s).join("\n")
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
  lr0 = Lr::Grammer.new [
    [:s, :e],
    [:e, :e, '+', 'num'],
    [:e, :e, '*', 'num'],
    [:e, 'num']
  ]
  puts lr0.table.to_s
end