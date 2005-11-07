;;; confinement.scm  --  Confinement of reader modifications.
;;;
;;; Copyright 2005  Ludovic Court�s <ludovic.courtes@laas.fr>
;;;
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

(define-module (system reader confinement)
  #:use-module (system reader)
  #:use-module (system reader compat)
  #:use-module (system reader library)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-11))

;;; Author:  Ludovic Court�s
;;;
;;; Commentary:
;;;
;;; This module provides a simple implementation of per-module reader
;;; settings (i.e. via `read-enable') and per-module readers.  In other
;;; words, it redefines `read-enable' to a side-effect-free version of it.
;;;
;;; Code:

;; Keep a copy of the original version of `read-options'.
(define %built-in-read-options-interface read-options-interface)

;; The current value of `read-options' within this module.
(define-public %module-read-options (make-object-property))

;; Information useful to `make-reader'.
(define-public %module-reader-specs         (make-object-property))
(define-public %module-reader-sharp-specs   (make-object-property))
(define-public %module-reader-make-options  (make-object-property))
(define-public %module-reader-fault-handler (make-object-property))
(define-public %module-reader               (make-object-property))

(define-macro (define-ensure what default-value)
  `(define (,(symbol-append 'ensure- what) module)
     (if (not (,(symbol-append '%module- what) module))
	 (set! (,(symbol-append '%module- what) module)
	       ,default-value))
     (,(symbol-append '%module- what) module)))

(define-ensure read-options (%built-in-read-options-interface))
(define-ensure reader-spec (default-reader-token-readers))
(define-ensure reader-make-options '())
(define-ensure reader-fault-handler #f)
(define-ensure reader (default-reader))


(define-public (compile-module-read-options! module read-options)
  "Set @var{module}'s read options to @var{read-options}, a list representing
standard Guile read options, and compile a new reader local to @var{module}
that implements those options."
  (format #t "compile-module-read-options! ~a ~a~%" module read-options)
  (set! (%module-read-options module) read-options)

  ;; Convert MODULE's read options into extended read options.
  (let-values (((extended-read-opts make-reader-opts)
		(read-options->extended-reader-options read-options)))
    (set! (%module-reader-make-options module) make-reader-opts)

    ;; Convert EXTENDED-READ-OPTS into lists of token readers.
    (let-values (((sharp-specs top-level-specs)
		  (alternate-guile-reader-token-readers
		   extended-read-opts)))
      (set! (%module-reader-sharp-specs module) sharp-specs)
      (let* ((sharp (apply make-reader `(,sharp-specs #f ,@make-reader-opts)))
	     (sharp-tr (make-token-reader #\# sharp)))
	(set! (%module-reader-specs module)
	      (cons sharp-tr
		    (filter (lambda (tr)
			      (not (eq? (token-reader-specification tr)
					#\#)))
			    top-level-specs)))
	(set! (%module-reader module)
	      (apply make-reader
		     `(,(%module-reader-specs module)
		       #f ;; default fault handler
		       ,@make-reader-opts)))

	(module-define! module 'read (%module-reader module))))))



;; A version of `read-options-interface' (and consequently `read-options',
;; `read-set!', `read-enable' and `read-disable') that is confined to a
;; module.
(set! read-options-interface
      (lambda args
	(format #t "confined `read-options-interface': ~a~%" args)
	(let* ((module (current-module))
	       (opts (ensure-read-options module)))
	  (cond ((null? args)
		 opts)
		((list? (car args))
		 (set! (%module-read-options module)
		       (clean-up-read-options (car args)))
		 (compile-module-read-options! module
					       (%module-read-options module)))

		(else
		 ;; FIXME: This could be implemented too.
		 (apply %built-in-read-options-interface args))))))


;;; arch-tag: 9eda977f-4edb-48c5-bdb7-28a6dd0850c6

;;; confinement.scm ends here
