require 'lispeval.rb'

class Array
  def to_list
   self.reverse.inject(nil){|list, el| Cons.new(Array===el ?
     el.to_list : el,list)}
  end
   
  def +@
    if size==1 and consp(self[0])
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
  alias rinspect inspect
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