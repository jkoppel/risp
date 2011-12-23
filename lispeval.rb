require 'lispenv.rb'
require 'lispfunctions.rb'
require 'lispobjects.rb'

class Module
  def defining_module(meth_sym)
    ancestors.each do |anc|
      return anc if (anc.public_instance_methods(false) +
                          anc.protected_instance_methods(false) +
                          anc.private_instance_methods(false)).
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