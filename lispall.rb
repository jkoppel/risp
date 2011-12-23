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


class Module
  def defining_module(meth_sym)
    ancestors.each do |anc|
      return anc if (anc.public_instance_methods(false) +
                          anc.protected_instance_methods(false) +
                          anc.private_instance_methods(false) +
                          anc.instance_methods(false)).
                          include?(meth_sym.id2name)
    end
    nil
  end
end  

module Kernel
  def lisp_eval(code_tree)
    
    if atomp(code_tree)
      return value(code_tree)
    end
    
    f = lisp_eval(code_tree.car)
    
    case f
      when :quote
        code_tree.cadr
      when :block
        block(code_tree.cdr)
      when :if
        if lisp_eval(code_tree.cadr)
          lisp_eval(code_tree.caddr)
        else
          lisp_eval(code_tree.cadddr)
        end
      when :let
        let(code_tree.cadr){code_tree.cddr.each_returning_last{|el| eval_lisp_eval(el)}}
    #macro on let and lambda
    #  when :labels
    #    labels(code_tree.cadr){code_tree.cddr.each_returning_last{|el| lisp_eval(el)}}
      when :tagbody
        tagbody(code_tree.cdr)
      when :lambda
        Function.new(get_args(code_tree.cadr), code_tree.caddr)
        
      else
        if Function === f
          value(f).apply(*code_tree.cdr.to_list_a.map{|x| eval_lisp_eval(x)})
        else
          meth = code_tree.car.to_s.to_sym
          receiver = lisp_eval(code_tree.cadr)
          if receiver.class.defining_module(meth) == Kernel
            Kernel.send(meth, *([receiver] + (code_tree.cddr.to_list_a.
              map{|sexp| eval_lisp_eval(sexp)})))
          else
            receiver.send(meth,
              *code_tree.cddr.to_list_a.map{|sexp| eval_lisp_eval(sexp)})
          end
        end
    end
  end
end

def eval_lisp_eval(code_tree)
  lisp_eval([:lisp_eval, [:quote, code_tree]].to_list)
end

def lisp_return(val=nil)
  throw :block_return, val
end

def block(code)
  ret = Function.new(nil, method(:lisp_return))
  catch(:block_return) do
    let("return"=>ret) do
      code.each_returning_last{|sexp| lisp_eval(sexp)}
    end
  end
end

def tagbody(body)
  code_arr = body.to_list_a
  labels = {}
  i = 0
  code_arr.each_with_index do |code, idx|
    labels[value(code)] = idx if symbolp(code)
  end
  let("go"=>Function.new(nil, proc {|sym| i = labels[sym]})) do
    while i < code_arr.length
      lisp_eval(code_arr[i])
      i += 1
    end
  end
end

def let(env_mod)
  val = nil
  case env_mod
    when Array
      env_mod.each {|lc|$env.push(lc)}
      val = yield
      env_mod.size.times{$env.pop}
    when LexicalContext
      $env.push(env_mod)
      val = yield
      $env.pop
    when Hash
      lc = LexicalContext.new(nil)
      env_mod.each_pair{|k,v| lc[k.to_lsym].value = v}
      lc.parent = $env.last
      $env.push(lc)
      val = yield
      $env.pop
    when Cons
      lc = LexicalContext.new(nil)
      env_mod.to_list_a.each{|binding_list|lc[binding_list.car].value = lisp_eval(binding_list.cadr)}
      #lc[env_mod.caar].value = lisp_eval(env_mod.cadar)
      lc.parent = $env.last
      $env.push(lc)
      val = yield
      $env.pop
    else
      val = yield
    end
    val
end

class Array
  def to_list
   self.reverse.inject(nil){|list, el| Cons.new(Array===el ?
     el.to_list : el,list)}
  end
   
  def +@
    if size==1 and 
    (self[0])
      +self[0]
    else
      self
    end
  end
end

class NilClass
  def NilClass.define_method_equiv(name,val=nil)
    self.send("define_method", name, &(eval("proc{#{val.inspect}}")))
  end
  
  ["car","cdr"].each{|s| NilClass.define_method_equiv(s)}
  ["to_a","to_list_a"].each{|s| NilClass.define_method_equiv(s, [])}
end
    
class Cons
  attr_accessor :car, :cdr
  def initialize(car, cdr=nil)
    @car, @cdr = car, cdr
    @lisp_type = "cons".to_lsym
  end
  
  def to_a
    a=[car]
    if consp(cdr)
      a[1,1] = cdr.to_a
      a
    else
      a << cdr
    end
  end
  
  ###Excludes trailing nil
  def to_list_a
    a=[car]
    if consp(cdr)
      a[1,1] = cdr.to_list_a
      a
    else
      (cdr.nil?) ? a : a << cdr
    end
  end
  
  def deep_to_a
    to_a.map{|o| consp(o) ? o.to_a : o}
  end
  
  def inspect
    a=to_a
    if a.last == nil
      "(" + a[0...-1].map{|x| x.inspect}.join(" ") + ")"
    else
      "(" + a[0...-1].map{|x| x.inspect}.join(" ") + " . #{a[-1].inspect})"
    end
  end
  
  def each
    to_list_a.each{|x| yield x}
  end
  
  def each_returning_last
    v = nil
    each{|x| v = yield x}
    v
  end
  
  def reverse(prev=nil)
    if cdr
      cdr.reverse(Cons.new(car, prev))
    else
      Cons.new(car, prev)
    end
  end
  
  def +@
    to_list_a
  end
  
  ###Defines car and cdr compositions (cadr, cdadr, etc)
  ["a","d"].each do |a|
    ["a","d"].each do |b|
      ["a","d",""].each do |c|
        ["a","d",""].each do |d|
          h = {"a"=>".car", "d"=>".cdr", ""=>""}
          f = eval("proc{self#{h[d]}#{h[c]}#{h[b]}#{h[a]}}")
          self.send("define_method",("c"+a+b+c+d+"r").intern, &f)
        end
      end
    end
  end          
end

def consp(o)
  o.instance_variable_get("@lisp_type") == "cons".to_lsym
end

def atomp(o)
  !consp(o)
end

class Function
  attr_accessor :args, :body
  def initialize(args, body, env=$env.dup)
    @args, @body, @env = args, body, env
    @lisp_type = "fn".to_lsym
  end
  
  def apply(*args)
    args = args.flatten
    case body
      when Method
        body.call(*args)
      when Proc
        body.call(*args)
      ###For functions whose body is an atom, this doesn't work
      #when Cons
      else
        args_full = args.dup
        bindings = @args.inject({}){|h, arg|
          h.merge(arg.take_val!(args, args_full))}
        let(@env){let(bindings){lisp_eval(body)}}
    end
  end
end

class Method
  def to_func
    Function.new(nil, self)
  end
end

class Argument
  attr_accessor :name, :type
  def initialize(name, type=:normal, default=nil, givenp=nil)
    @name, @type, @default, @givenp = name, type, default, givenp
  end
  
  def take_val!(vals, allvals)
    case type
      when :normal
        {name => vals.shift}
      when :optional
        if @givenp
          {@givenp => vals.empty? ? nil : true,
            @name => vals.empty? ? @default : vals.shift}
        else
          {name => vals.empty? ? @default : vals.shift}
        end
      when :rest
        {name => vals.to_list}
      when :keyword
        {name => allvals.index(name) ?
          allvals[(allvals.index(name)+1)] : @default} +
          (@givenp ? {@givenp => allvals.index(name) ? true : nil} : {})
    end      
  end
end

def get_args(sexp)
  type = :normal
  args = []
  sexp.to_list_a.each do |v|
    if v.to_s =~ /&(\w+)/
      type = $1.to_sym
    elsif consp(v)
      args << Argument.new(v.car, type, v.cadr, v.caddr)
    else
      args << Argument.new(v, type)
    end
  end
  args
end

class Object
  def +@
    self
  end
end

class Hash
  alias + merge
end
  
class Symbol
  
  alias old_case_match ===
  def ===(oth)
    case oth
      when LispSymbol
        id2name == oth.name
      else
        old_case_match oth
    end
  end
  
  def to_lsym
    LispSymbol.new(self.id2name)
  end
end

class String
  def to_lsym
    LispSymbol.new(self)
  end
end


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

class Object 
  alias eq equal?
end

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
define_lisp_val("*file-class*", File)
define_lisp_val("nil", nil)
define_lisp_val("*gensym-counter*", 0)
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

def read(str=$stdin)
  true while ($_=str.read(1)) =~ /\s/
  if $macro_characters.has_key? $_
    $macro_characters[$_].apply(str, $_)
  elsif $macro_dispatch_characters.include? $_
    $macro_dispatch_character_combos[[(a=$_), (b=str.read(1))]
      ].apply(str, a, b)
  else
    read_primitive(str, $_)
  end
end

def read_primitive(str, last_char=nil)
  last_char = str.read(1) unless last_char
  case last_char
    when /\d/
      numstr = last_char+basic_read_sym(str)
        
      case numstr
        when /(\d+)\/(\d+)/
          Rational.new($1.to_i, $2.to_i)
        when /\d+\.\d+/
          numstr.to_f
        when /\d+/
          numstr.to_i
      end
    when /\|/
      symstr = str.read(1)
      loop do
        last_char = str.read(1)
        if last_char == "\\"
          symstr << str.read(1)
        elsif last_char == "|"
          return LispSymbol.new(symstr)
        else
          symstr << last_char
        end
      end
    else
      LispSymbol.new(last_char+basic_read_sym(str))
  end
end

def basic_read_sym(str)
  val = ""
  last_char = str.read(1)
  until last_char =~ /\s/ or ($macro_characters.has_key?(last_char) &&
    !$macro_characters_nonterm[last_char]) or 
      ($macro_dispatch_characters.index(last_char) &&
        !$macro_dispatch_characters_nonterm[last_char])
    
    val << last_char
    last_char = str.read(1)
  end
  
  str.ungetc(last_char[0])
  val
end

###To be called after the starting char has been read
def read_delimited_list(str, end_char)
  list =  nil
  
  old_f, old_nt = $macro_characters[end_char],
    $macro_characters_nonterm[end_char]
  
  $macro_characters[end_char] = Function.new(nil, proc{|a,b|
    throw :list_end})
  $macro_characters_nonterm[end_char] = false
  catch(:list_end) do
    loop do
      list = Cons.new(read(str), list)
    end
  end
  
  $macro_characters[end_char] = old_f
  $macro_characters_nonterm[end_char] = old_nt
  list.reverse
end

def read_from_file(file_name)
  str = File.open(file_name) {|f| StringIO.new(f.read)}
  until str.eof
    lisp_eval(read(str))
  end
end

$macro_characters['('] =
  Function.new(nil, proc{|str, ch| read_delimited_list(str, ')')})
$macro_characters_nonterm['('] = false

$macro_characters['"'] = Function.new(nil, proc do |str, ch|
    s = ""
    until (last_char=str.read(1)) == '"'
      if last_char == "\\"
        s << str.read(1)
      else
        s << last_char
      end
    end
    s
  end)
$macro_characters_nonterm['"'] = false