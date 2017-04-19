module Lalruby
  class Parser
    def initialize(grammer, verbose=false)
      @g = grammer
      @table = @g.table.table
      @verbose = verbose
    end

    def parse(tokens)
      puts @g.table if @verbose
      stack = [{state: 0, val: nil}]
      result = []
      while !tokens.empty?
        next_token = tokens.first
        command, operand = @table[stack.last[:state]][next_token]
        print "next operation : " if @verbose
        pp @table[stack.last[:state]][next_token] if @verbose
        print "stack : " if @verbose
        pp stack if @verbose
        raise "No transition defined @ #{stack.last[:state]} => #{next_token}" unless command
        case command
        when :acc
          raise "Accpet found on the middle of sentence" if tokens != [nil] || stack.size != 2
          break
        when :shift
          stack.push({state: operand, val: tokens.shift})
        when :reduce
          rule = @g.rules[operand]
          val = rule.exps.size.times.map do |_|
            stack.pop[:val]
          end
          val.reverse!
          val = val[0] if val.size == 1
          # result.push({rule: rule.from, val: val})
          goto_command = @table[stack.last[:state]][rule.from]
          raise "No GOTO transition defined @ #{stack.last[:state]} => #{rule.from}" unless goto_command
          stack.push({state: goto_command[1], val: val})
        end
      end
      stack.last[:val]
    end
  end
end
