module Lalruby
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
        terms.concat resoelve_symbol_follows(sym)
      end
      @follows[sym] = terms.uniq
    end
  end
end