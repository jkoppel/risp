require 'lispobjects.rb'
require 'lisp_eval.rb'
require 'lisp_env.rb'

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
      env_mod.each {|lc| $env.push(lc)}
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
      env_mod.each{|binding_list| lc[binding_list.car].value = lisp_eval(binding_list.cadr)}
      lc.parent = $env.last
      $env.push(lc)
      val = yield
      $env.pop
    else
      val = yield
    end
    val
end