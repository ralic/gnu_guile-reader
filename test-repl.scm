(use-modules (reader))

;;(kill (getpid) SIGTSTP)
;;(do-stuff (current-input-port))

(format #t "Hello, this is your friendly REPL using a dynamically\n\
defined reader for Guile!~%~%")

(define *ws* " \n\t")

(define sharp-reader (make-reader *ws*
				  (map standard-token-reader
				       '(character srfi-4 number+radix
					 extended-symbol
					 boolean keyword block-comment))
				  #f))

(let loop ((reader (make-reader *ws*
				(cons (make-token-reader #\# sharp-reader)
				      (map standard-token-reader
					   `(sexp string number
					     symbol-lower-case
					     symbol-upper-case
					     symbol-misc-chars
					     quote-quasiquote-unquote
					     semicolon-comment
					     skribe-exp))))))
  (display "guile-reader> ")
  (let ((sexp (reader (current-input-port))))
    (if (eof-object? sexp)
	(quit))
    (write (eval sexp (interaction-environment))))
  (display "\n")
  (loop reader))

