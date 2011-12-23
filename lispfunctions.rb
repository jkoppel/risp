#require 'lispobjects.rb'
require 'lispenv.rb'

def value(o)
  case o
    when LispSymbol, Symbol
      if $env.last.symbol_defined? o
        $env.last[o].value
      ##Gensyms
      elsif LispSymbol === o and Numeric === o.name
        o.value
      else
        o
      end
    else
      o
  end
end

def define_lisp_val(name, value)
  $global[name].value = value
end

def define_lisp_function(name, value)
  $global[name].value = Function.new(nil, value)
end

####Ruby functions can work differently than Lisp functions;
####they'll have to be written over in lisp
####E.g:
####(let ((orig-+ +))
####  (defun + (&rest args)
####    (reduce orig-+ (cons 0 args))))

####Many lisp functions are already defined via the calsue in lisp_eval that passes
####them to ruby

define_lisp_function("cons", lambda{|car, cdr| Cons.new(car,cdr)})
define_lisp_function("=", lambda{|a,b| a==b ? true : nil})
define_lisp_function("tag", proc{|type, val|
    val.instance_variable_set(:@lisp_type, type); val})
define_lisp_function("type", lambda{|val|
  val.instance_variable_get(:@lisp_type)})
define_lisp_function("gensym",
  lambda{LispSymbol.new($global["*gensym-counter*"].value +=1)})

require 'enumerator'

def lisp_set(*args)
  ret = nil
  args.each_slice(2) do |s,v|
    if $env.last.symbol_defined?(s)
      ret = $env.last[s].value = v
    else
      ret = $global[s].value = v
    end
  end
  ret
end

define_lisp_function("set", method(:lisp_set))

define_lisp_val("t", true)
define_lisp_val("nil", nil)
define_lisp_val("*gensym-counter*", 0)
define_lisp_val("*file-class*", File)
define_lisp_val("*global-env*", $global)
define_lisp_val("*env*", $env)

$macro_characters = {}
$macro_characters_nonterm = {}
$macro_dispatch_characters = []
$macro_dispatch_characters_nonterm = {}
$macro_dispatch_character_combos = {}

[:$macro_characters, :$macro_characters_nonterm,
  :$macro_dispatch_characters,:$macro_dispatch_characters_nonterm,
  :$macro_dispatch_character_combos].each do |sym|
    define_lisp_val(sym.id2name[1..-1].gsub('_','-'), eval(sym.id2name))
end
    