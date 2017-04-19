require "spec_helper"

RSpec.describe Lalruby do
  it "has a version number" do
    expect(Lalruby::VERSION).not_to be nil
  end

  it "parses simple grammer well" do
    g = Lalruby::Grammer.new [
      [:s, :add],
      [:add, :add, '+', :mul],
      [:add, :mul],
      [:mul, :mul, '*', :num],
      [:mul, :num],
      [:num, '0'],
      [:num, '1'],
      [:num, '2'],
    ]
    parser = Lalruby::Parser.new(g)
    sentence = ['2', '*', '1', '+', '1', '*', '0', nil]
    result = parser.parse(sentence)
    expect(result).to eq [['2', '*', '1'], '+', ['1', '*', '0']]
  end
end
