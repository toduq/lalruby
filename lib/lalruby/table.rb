module Lalruby
  class Table
    attr_reader :table
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
              if @table[state.id][term]
                if @table[state.id][term][0] == :shift
                  # shift and reduce conflict => shift
                else
                  # reduce and reduce conflit => error!
                  raise "#{} / reduce conflict"
                end
              else
                @table[state.id][term] = [:reduce, rule.id]
              end
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
end
