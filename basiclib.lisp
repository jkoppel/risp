(set list (lambda (&rest lst) lst))

(set set-macro-char (lambda (char f &optional (nonterm t))
	(block
	  (store macro-characters char f)
	  (store macro-characters-nonterm char nonterm))))

(set-macro-char "'"
	(lambda (str ch) (list (quote quote) (read nil str)))
	nil)

(set-macro-char ";"
	(lambda (str ch) (block (gets str) (read nil str))))

(set strcat (lambda (str1 str2)
	(send str1 (to_sym '+) str2)))

(set fn->proc (lambda (fn)
	(eval nil (strcat
		(strcat "Proc.new{|*args| ObjectSpace._id2ref(" (to_s (__id__ fn)))
		").apply(*args)}"))))

(set rb-blockeval (lambda (meth-name obj block-fn  &rest args)
	(eval nil (strcat
			(strcat			
				(strcat "ObjectSpace._id2ref(" (to_s (__id__ obj)))
				(strcat ")." (to_s (to_sym meth-name))))
			;;I'm afraid inopportune garbage collection could break the _id2refs. We'll see.
			(strcat
				(strcat "(*ObjectSpace._id2ref(" (to_s (__id__ (to_list_a args))))
				(strcat 
					"), &ObjectSpace._id2ref("
					(strcat (to_s (__id__ (fn->proc block-fn))) "))")))))))
(p (defining_module (eval "String") (to_sym "==")))

(set method->fn (lambda (obj sym)
	(to_func (method obj (to_sym sym)))))

(set apply (lambda (fn lst)
	(call (method fn (to_sym 'apply)) (to_list_a lst))))

(set consp (lambda (cns)
	(eql? (type cns) 'cons)))

(let ((orig (method->fn nil 'lisp_eval)))
	(set lisp_eval (lambda (expr)
		(if (consp expr)
		  (if (eql? (type (value nil (car expr))) 'mac)
		    (orig (apply (value nil (car expr)) (cdr expr)))
		    (orig expr))
		  (orig expr)))))

(set defmacro (tag 'mac
		(lambda (name parms &rest body)
		  (list 'set name
		  	(list 'tag 'mac (list 'lambda
				    parms (cons 'block body)))))))

(set load-file (lambda (file-name)
	(rb-blockeval 'open *file-class*
		(lambda (str)
			(tagbody
				a
				(lisp_eval (read nil str))
				(if (eof? str) nil (go a))))
		file-name)))

(load-file "mainlib.lisp")