module Lalruby
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

    def current
      @exps[@ptr]
    end

    def to_s
      # TODO: print in below style
      # symbol -> 'term' @ add_operator '2' ['+', '-', nil]
      "#{from} -> #{exps.join(' ')} [#{@look_ahead.map{|l| l ? l : 'nil'}.join(',')}]"
    end

    def ==(o)
      @id == o.id && @ptr == o.ptr && @look_ahead == o.look_ahead
    end

    def equal_without_look_ahead(o)
      @id == o.id && @ptr == o.ptr
    end
  end
end