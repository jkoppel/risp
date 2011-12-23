require 'lispobjects.rb'

class LispSymbol
  attr_accessor :value, :plist
  attr_reader :name
  
  def initialize(name, value=nil)
    @name, @value = name, value
    @plist = nil
  end
  
  def == oth
    if symbolp oth
      name==oth.name
    else
      false
    end
  end
  alias eql? ==
  
  def hash
    name.hash
  end
  
  def to_lsym
    self
  end
  
  def to_sym
    name.to_sym
  end
  
  def gensym?
    Numeric === @name
  end
  
  def inspect
    if gensym?
      '#:G' + @name.to_s
    else
      @name.to_s
    end
  end
  alias to_s inspect
end

def symbolp(o)
  LispSymbol === o or Symbol === o
end

class LexicalContext
  attr_accessor :parent
  
  def initialize(parent=nil)
    @parent = parent
    @bindings = {}
  end
  
  def symbol_defined?(name)
    if @bindings.has_key?(name.to_lsym)
      true
    else
      @parent && parent.symbol_defined?(name.to_lsym)
    end
  end
  
  def [](symbol)
    symbol if symbol.to_lsym.gensym?
    if symbol_defined?(symbol)
      if @bindings.has_key?(symbol.to_lsym)
        @bindings[symbol.to_lsym]
      else
        @parent[symbol.to_lsym]
      end
    else
      intern(symbol)      
    end
  end
  
  def intern(symbol)
    @bindings[symbol.to_lsym] = symbol.to_lsym
  end
end

$global = LexicalContext.new
$env = [$global]