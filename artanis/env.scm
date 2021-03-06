;;  -*-  indent-tabs-mode:nil; coding: utf-8 -*-
;;  Copyright (C) 2014,2015
;;      "Mu Lei" known as "NalaGinrut" <NalaGinrut@gmail.com>
;;  Artanis is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License and GNU
;;  Lesser General Public License published by the Free Software
;;  Foundation, either version 3 of the License, or (at your option)
;;  any later version.

;;  Artanis is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License and GNU Lesser General Public License
;;  for more details.

;;  You should have received a copy of the GNU General Public License
;;  and GNU Lesser General Public License along with this program.
;;  If not, see <http://www.gnu.org/licenses/>.

;; -----------------------------------------------------------------------
;; This is where all the global vars should be put.
;; Include global config table, and green-thread working queue in the future.
;; NOTE: This module should NEVER import any other modules in Artanis!!!

(define-module (artanis env)
  #:use-module (artanis version)
  #:use-module (ice-9 regex)
  #:re-export (artanis-version)
  #:export (*handlers-table*
            *conf-hash-table*
            *conn-pool*
            *before-response-hook*
            *after-request-hook*
            *before-run-hook*
            *sql-mapping-lookup-table*
            *artanis-entry*
            %current-toplevel
            current-toplevel
            find-ENTRY-path
            draw:is-dry-run?
            draw:is-force?
            draw:is-skip?
            draw:is-quiet?
            artanis-current-output
            *controllers-table*
            current-dbconn
            current-appname))

;; WARNING: For concurrency in green-thread, all these stuffs should be immutable
;;          IN THE RUN TIME!!!

;; table structure:
;; '((rule-handler-key (handler . keys)) ...)
;; for example:
;; `(("GET \"/photo/:id/edit\"" (,(lambda (req ..) ...) . id)))  
(define *handlers-table* (make-hash-table))
(define *conf-hash-table* (make-hash-table))

;; NOTE: pool size equals to workers (work queues)
;; TODO: Should be pool of pool.
;;       In principle, each worker need just one connection because of green-thread.
;;       But async needs non-block, so we need a pool for each worker since each conn
;;       could be scheduled when it encounters EWOULDBREAK.
(define *conn-pool* #f)

(define *before-response-hook* (make-hook 2))
(define *after-request-hook* (make-hook 2))
(define *before-run-hook* (make-hook))

;; TODO: I don't have much time for it but it should be RB-Tree in the future
(define *sql-mapping-lookup-table* (make-hash-table))

(define *artanis-entry* "ENTRY")

(define %current-toplevel (make-parameter #f))
(define* (find-ENTRY-path proc #:optional (check-only? #f))
  (define (-> p)
    (let ((ff (string-append p "/" *artanis-entry*)))
      (and (file-exists? ff) p)))
  (define (last-path pwd)
    (and=> (string-match "(.*)/.*$" pwd) (lambda (m) (match:substring m 1))))
  ;; FIXME: Maybe we should generate relative path?
  (let lp((pwd (getcwd)))
    (cond
     ((not (string? pwd)) (error find-ENTRY-path "BUG: please report it!" pwd))
     ((string-null? pwd)
      (if check-only?
          #f
          (error find-ENTRY-path
                 "No ENTRY! Are you in a legal Artanis app dir? Or maybe you need to create a new app?")))
     ((-> pwd) => proc)
     (else (lp (last-path pwd))))))
(define (current-toplevel)
  (or (%current-toplevel)
      (find-ENTRY-path identity #t)))

;; parameters for command
(define draw:is-dry-run? (make-parameter #f))
(define draw:is-force? (make-parameter #f))
(define draw:is-skip? (make-parameter #f))
(define draw:is-quiet? (make-parameter #f))

(define (artanis-current-output)
  (if (draw:is-quiet?)
      (open-output-file *null-device*)
      (current-output-port)))

(define *controllers-table* (make-hash-table))

(define current-dbconn (make-parameter #f))

(define (current-appname) (and=> (current-toplevel) basename))
