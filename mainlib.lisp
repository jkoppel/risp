(set listp (lambda (lst)
  (if (consp lst)
    t
    (if (nil? lst)
     t
     nil))))


(defmacro defun (name parms &rest body)
  (if (listp name)
    (list 'set-setf-expansion
    	(cadr name)
    	(list 'lambda parms (cons 'block body)))
    (list 'set name
    	(list 'lambda parms (cons 'block body)))))

(defmacro aif (test then &optional else)
		(list 'let (list (list 'it test))
			(list 'if 'it then else)))

(defmacro and (&rest expressions)
  (if (nil? (cdr expressions))
	(list 'aif (car expressions) 'it nil)
	(list 'if (car expressions) (apply and (cdr expressions)) nil)))

(defmacro while (test &rest body)
  (let ((g (gensym)))
	(list 'tagbody
		g
		(list 'if test
			(append '(block) body (list (list 'go g)))
			nil))))

(defun min (&rest nums)
 (if (nil? (cdr nums))
    (car nums)
    (let ((mn (if (< (car nums) (cadr nums)) (car nums) (cadr nums))))
	(apply min (cons mn (cddr nums))))))

(defun global-intern (sym)
	(intern *global-env* sym))

(defun last (lst)
  (car (last-cons lst)))

(defun last-cons (lst)
  (if (nil? (cdr lst))
    lst
    (last-cons (cdr lst))))
 

(defun last-1 (lst)
  (if (nil? (cdr lst))
  	nil
  	(if (nil? (cddr lst))
  	  (car lst)
  	  (last-1 (cdr lst)))))

(defun list-copy (lst)
  (if (nil? lst)
  	nil
	(cons (car lst) (list-copy (cdr lst)))))

(defun length (lst)
  (if (nil? lst)
    0
    (+ 1 (length (cdr lst)))))

(defun append (&rest prolists)
  (if (nil? (cdr prolists))
  	(car prolists)
	(if (nil? (car prolists))
		(apply append (cdr prolists))
		;needed due to some weird scoping bug
		(let ((cdr=last-cons-returning-list (lambda (lst val) (block (cdr= (last-cons lst) val) lst))))
		  	(cdr=last-cons-returning-list (list-copy (car prolists)) (apply append (cdr prolists)))))))

;(defun mapcar (fn &rest args)
;  (if (eql? (length args) 1)
;	(if (nil? args)
;	  nil
;	  (cons (fn (caar args)) (mapcar fn (cdar args))))
;	(cons (apply fn (mapcar (lambda (a) (car a)) args)))

(defun progn (&rest actions) (last actions))

(defun progn-1 (&rest actions) (last-1 actions))

(defmacro setq (&rest args)
  (if (nil? args)
	nil
	(append (list 'set (cons 'quote (car args)) (cdr args)) (setq (cddr args)))))

(defun symbol-plist (sym)
  (plist ([] (send *env* (to_sym 'last)) sym)))

(defun get-setf-expansion (sym)
	(let ((look (lambda (lst) (if (eql? (car lst) 'setf-expander)
			(cadr lst)
			(if (nil? lst)
			  nil
			  (look (cddr lst)))))))
	  (look (symbol-plist sym))))

(defun set-setf-expansion (sym f)
  (plist= sym (cons 'setf-expander (cons f (symbol-plist sym)))))

(set-setf-expansion (global-intern 'car) 
	(lambda (cns val) (car= cns val)))

(set-setf-expansion (global-intern 'cdr) 
	(lambda (cns val) (cdr= cns val)))

(defmacro setf (place val &rest args)
  (list (if (nil? args) 'progn-1 'progn)
  	(if (listp place)
  	  (append (list (get-setf-expansion (car place))) (list (cadr place)) (list val))
  	  (list 'set place val))
  	(if (nil? args)
	  nil
  	  (apply setf args))))

;(defun acons (key value alist)
; (cons (cons key value) alist)))

(+ 1 2)