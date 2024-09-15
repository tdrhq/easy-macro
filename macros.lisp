;; Copyright 2018-Present Modern Interpreters Inc.
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

(defpackage :easy-macros
  (:use #:cl)
  (:export
   #:def-easy-macro))
(in-package :easy-macros)

(define-condition unsupported-lambda-list (error)
  ((reason :initarg :reason)))

(defun build-funcall (fn-name real-fn-args fn-arg-values body)
  `(,fn-name (lambda (,@ (loop for x in (get-bindings real-fn-args fn-arg-values)
                               if x collect x
                                 else collect (gensym))) ,@body)
             ,@ (get-non-bindings real-fn-args fn-arg-values)))

(defun remove-defaults (x)
  "Remove default values from an argument to just get the name"
  (etypecase x
    (symbol
     x)
    (list
     (car x))))

(defun get-bindings (real-fn-args fn-arg-values)
  (let ((fn-args (remove-&fn real-fn-args)))
    (let ((expr `(destructuring-bind
                     ,(loop for x in fn-args
                            if (binding-sym-p x)
                              collect (name x)
                            else
                              collect (remove-defaults x))
                     ',fn-arg-values
                   (list ,@ (let ((seen-&key nil))
                              (loop for x in fn-args
                                    if (eql '&key x)
                                      do
                                         (setf seen-&key t)
                                    if (and (binding-sym-p x))
                                      collect
                             (name x)))))))
      #+nil
      (log:info "Going to eval expr: ~s" expr)
      (eval expr))))

(defun get-non-bindings (real-fn-args fn-arg-values)
  "Carefully remove all the fn-arg-values that correspond to bindings"
  (let ((fn-args (remove-&fn real-fn-args)))
    (labels ((is-binding-key (name)
               (loop for x in fn-args
                     if (and
                         (binding-sym-p x)
                         (string= (string (name x)) (string name)))
                       return t))
             (%get-non-bindings (args value-exprs keysp)
               #+nil
               (log:info "Looking at ~a ~a" args value-exprs)
               (cond
                 ((null value-exprs)
                  value-exprs)
                 ((and (binding-sym-p (car args))
                       (not keysp))
                  (%get-non-bindings (cdr args)
                                     (cdr value-exprs)
                                     keysp))
                 ((and (eql (car args) 'cl:&key)
                       (not keysp))
                  (list*
                   (%get-non-bindings args
                                      value-exprs
                                      t)))
                 ((and keysp (is-binding-key (car value-exprs)))
                  (%get-non-bindings args
                                     (cddr value-exprs)
                                     t))
                 (keysp
                  (assert (not (is-binding-key (car value-exprs))))
                  (list*
                   (car value-exprs)
                   (cadr value-exprs)
                   (%get-non-bindings args
                                      (cddr value-exprs)
                                      t)))
                 (t
                  (list*
                   (car value-exprs)
                   (%get-non-bindings (cdr args)
                                      (cdr value-exprs)
                                      keysp))))))
      (%get-non-bindings fn-args fn-arg-values nil))))

(defun is-sym (sym looking-for)
  (when (and
         (symbolp sym)
         (symbolp looking-for))
    (string= (string sym) (string looking-for))))

(defclass binding-sym ()
  ((name :initarg :name
         :reader name)))

(defun binding-sym-p (x)
  (typep x 'binding-sym))

(defun check-validity (args)
  (labels ((%check (args seen-key seen-rest)
             (when args
              (destructuring-bind (next &rest rest) args
                (cond
                  ((is-sym next '&binding)
                   (when seen-rest
                     (error 'unsupported-lambda-list
                             :reason "&binding not supported after &rest"))
                   (%check (cdr rest) seen-key seen-rest))
                  ((eql next 'cl:&key)
                   (%check rest t seen-rest))
                  ((eql rest 'cl:&rest)
                   (%check rest seen-key t))
                  (t
                   (%check rest seen-key seen-rest))))))
           )
    (%check args nil nil)))

(defun remove-&fn (args)
  (check-validity args)
  (let ((fn nil))
    (let ((result
           (loop while args
                 for next = (car args)
                 if (is-sym next '&fn)
                   do
                      (setf fn (cadr args))
                      (setf args (cddr args))
                 else if (is-sym next '&binding)
                      collect
                      (prog1
                          (make-instance 'binding-sym :name (cadr args))
                        (setf args (cddr args)))
                 else
                   collect
                   (progn
                     (setf args (cdr args))
                     next))))
      (values result (or fn (gensym "fn"))))))

(defun remove-binding-syms (args)
  (loop for x in args
        if (not (typep x 'binding-sym))
          collect x into final-arg
        else
          collect x into binding-syms
        finally (return (values final-arg binding-syms))))

(defmacro def-easy-macro (name real-fn-args  &body body)
  (let ((fn-name (intern (format nil "CALL-~a" (string name)) *package*)))
    (multiple-value-bind (fn-args body-fn) (remove-&fn real-fn-args)
      (multiple-value-bind (body decl doc)
          (uiop:parse-body body :documentation t)
       `(progn
          (defun ,fn-name (,body-fn ,@ (remove-binding-syms fn-args))
            ,@decl
            (flet ((,body-fn (&rest args)
                     (declare (inline))
                     (apply ,body-fn args)))
              ,@body))
          (defmacro ,name ((&rest fn-arg-values) &body macro-body)
            ,doc
            (build-funcall ',fn-name ',real-fn-args fn-arg-values macro-body)))))))
