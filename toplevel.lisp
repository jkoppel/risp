(block
	(tagbody
		a
		(print nil ">")
		(let ((r (read nil)))
			(if (eql? r (quote exit))
				(return)
				nil)
			(p nil (lisp_eval r))
			(go a))))