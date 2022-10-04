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

(defpackage :easy-macros/test-macros
  (:use #:cl
        #:easy-macros
        #:fiveam)
  (:import-from #:easy-macros
                #:unsupported-lambda-list
                #:get-non-bindings
                #:get-bindings
                #:binding-sym
                #:remove-&fn)
  (:import-from #:fiveam-matchers/core
                #:equal-to
                #:has-all
                #:is-not
                #:has-typep
                #:assert-that)
  (:import-from #:fiveam-matchers/lists
                #:contains))
(in-package :easy-macros/test-macros)


(def-suite* :easy-macros/test-macros)

(def-easy-macro with-basic-stuff (&fn fn)
  (funcall fn))

(def-easy-macro with-return-something-else (&fn fn)
  (funcall fn)
  :another)

(test preconditions
  (is (equal :test
             (with-basic-stuff ()
               :test)))
  (is (equal :another
             (with-return-something-else ()
               :test))))

(def-easy-macro with-arg (add &fn fn)
  (+ add (funcall fn)))

(test can-use-arguments

  (is (equal 5 (with-arg (1)
                 4)))

  (let ((value 45))
    (is (equal 50 (with-arg (4)
                    (+ 1 value))))))

(def-easy-macro with-eval-arg (add &fn fn)
  (+ add (funcall fn)))

(test arguments-get-evaluated
  (let ((value 1))
    (is (equal 5 (with-eval-arg (value)
                   4)))))

(def-easy-macro with-multiple-args (one two &fn fn)
  (list one two))

(test multiple-arguments
  (is (equal (list :one :two)
             (with-multiple-args (:one :two)
               nil))))

(test remove-&fn
  (is (equal '(one two) (remove-&fn '(one two))))
  (is (equal '(one two) (remove-&fn '(one &fn fn two))))

  (assert-that (remove-&fn '(one &binding two))
               (contains
                'one
                 (has-typep 'binding-sym))))

(test get-bindings
  (is (equal '(aaa) (get-bindings
                   '(&binding one)
                    '(aaa))))
  (is (equal '(aaa) (get-bindings
                     '(&binding one &key two)
                      '(aaa))))
  (is (equal '() (get-bindings
                  '(one &key two)
                   '(aaa :two 2)))))

(test get-bindings-for-keys
  ;; Not that this would say &key foo, since this is the expression
  ;; that goes into the lamba-list for the user defined block
  (is (equal '(var)
              (get-bindings
               '(&key &binding foo)
                '(:foo var))))
  (is (equal '(aaa bbb) (get-bindings
                              '(&binding aaa &key &binding bbb)
                               '(aaa :bbb bbb)))))

(test get-non-bindings
  (is (equal '() (get-non-bindings
                  '(&binding one)
                   '(aaa))))
  (is (equal '(2) (get-non-bindings
                   '(&binding one two)
                    '(aaa 2))))
  (is (equal '(:foo 2) (get-non-bindings
                        '(&binding one &key foo)
                         '(aaa :foo 2)))))

(test get-non-bindings-for-keys
  (is (equal '() (get-non-bindings
                  '(&key &binding foo)
                   '(:foo var))))
  (is (equal '() (get-non-bindings
                  '(&binding aaa &key &binding bbb)
                   '(aaa :bbb bb))))
  (is (equal '(:foo 2)
              (get-non-bindings
               '(&binding aaa &key &binding bbb foo)
                '(aaa :bbb bbb :foo 2)))))

(def-easy-macro with-bindings (&binding a &binding b &key one two
                                  &fn fn)
  (funcall fn 1 2))

(def-easy-macro with-bindings-v2 (&binding a &binding b &key one two
                                           &fn fn)
  (fn 1 2))



(test bindings
  (is (equal 3
             (with-bindings (aaa bbb)
               (+ aaa bbb))))
  #+nil
  (signals unsupported-lambda-list
    (eval
     `(def-easy-macro with-key-bindings (&binding a &key &binding b)
        (funcall fn 1 3)))))

(test bindings-v2
  (is (equal 3
             (with-bindings (aaa bbb)
               (+ aaa bbb))))
  #+nil
  (signals unsupported-lambda-list
    (eval
     `(def-easy-macro with-key-bindings (&binding a &key &binding b)
        (funcall fn 1 3)))))


(def-easy-macro with-key-bindings (&binding a &key &binding b one two
                                            &fn fn)
  (funcall fn 1 2))


(test bindings-with-keys
  (is (equal 3
             (with-key-bindings (aaa :b bbb)
               (+ aaa bbb)))))

(def-easy-macro collect-loop (&binding item list &fn fn)
  (loop for x in list
        for i from 0
        collect (funcall fn x)))

(test default-binding-example
  (is
   (equal '(2 4 6)
    (collect-loop (item '(1 2 3))
      (* 2 item)))))

(def-easy-macro collect-loop-with-index (&binding item list &key &binding index &fn fn)
  (loop for x in list
        for i from 0
        collect (funcall fn x i)))

(test default-binding-example-with-index
  (is
   (equal '(0 2 6)
    (collect-loop-with-index (item '(1 2 3) :index i)
      (* item i))))
  (is
   (equal '(1 2 3)
    (collect-loop-with-index (item '(1 2 3))
      item))))


(def-easy-macro without-body (x)
  (+ 1 x))

(test no-&fn-provided
  (is (equal 3 (without-body (2))))
  (is (equal 3 (without-body (2)
                 (+ 4 5)))))

(def-easy-macro without-body-but-with-binding (&binding item x)
  (+ 1 x))

(test no-&fn-provided-but-there-is-a-binding
  (is (equal 3 (without-body-but-with-binding (unused 2)))))
