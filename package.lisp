;;;; package.lisp

(defpackage #:cl-congregate
  (:use #:cl #:house #:anaphora #:cl-who)
  (:import-from #:alexandria :with-gensyms))

(in-package :cl-congregate)

(define-http-type (:group)
    :type-expression `(group-by-id (parse-integer ,parameter :junk-allowed t))
    :type-assertion `(not (null ,parameter)))

(define-http-type (:event)
    :type-expression `(get-event (parse-integer ,parameter :junk-allowed t))
    :type-assertion `(not (null ,parameter)))
