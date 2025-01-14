#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre))

;; The `rhombus-forwarding-sequence` form handles definitions that are
;; only visible to later terms (as created with Rhombus `let`, say,
;; and exposed to here by a `rhombus-forward` wrapper). It also takes
;; care of making nested `import` work through lifting. The
;; `rhombus-nested-forwarding-sequence` form extends that to gather
;; `export` information for a nested context.

(provide rhombus-forwarding-sequence
         rhombus-nested-forwarding-sequence
         rhombus-mixed-forwarding-sequence
         rhombus-mixed-nested-forwarding-sequence

         ;; wrap `rhombus-forward` around a sequence of declarations
         ;; to make any bindings among the  declarations visible only
         ;; after the declarations
         rhombus-forward)

(define-syntax (rhombus-forwarding-sequence stx)
  (syntax-parse stx
    [(_ ctx mode orig . tail)
     #`(sequence ctx mode orig base-ctx add-ctx remove-ctx . tail)]))

(define-syntax (rhombus-nested-forwarding-sequence stx)
  ;; Used for something like `namespace`
  (syntax-parse stx
    [(_ final . tail)
     #`(sequence [final] #f #f base-ctx add-ctx remove-ctx . tail)]))

(define-syntax (rhombus-mixed-forwarding-sequence stx)
  ;; Used for something like `class`, where non-expression, non-definition
  ;; forms are expanded to `(quote-syntax (stop-id . _))` and gathered to
  ;; be passed along to `final`
  (syntax-parse stx
    [(_ (final . data) stop-id . tail)
     #`(sequence [(final . data) #:stop-at stop-id] #f #f base-ctx add-ctx remove-ctx . tail)]))

(define-syntax (rhombus-mixed-nested-forwarding-sequence stx)
  ;; Actually used by `class`, which acts like `namespace`, too
  (syntax-parse stx
    [(_ (final . data) stop-id . tail)
     #`(sequence [(final . data) #:stop-at* stop-id ()] #f #f base-ctx add-ctx remove-ctx . tail)]))

(define-syntax (sequence stx)
  (let loop ([stx stx] [accum null])
    (syntax-parse stx
      [(_ ctx mode orig base-ctx add-ctx remove-ctx)
       (when (and (eq? (syntax-e #'mode) '#:need-end-expr)
                  (syntax-e #'orig))
         (raise-syntax-error #f "block does not end with an expression" #'orig))
       (define forms #`(begin #,@(reverse accum)))
       (syntax-parse #'ctx
         [[(final ...) #:stop-at _ accum ...]
          #`(begin
              #,forms
              (final ... #,@(reverse (syntax->list #'(accum ...)))))]
         [[(final ...) #:stop-at* _ binds accum ...]
          #`(begin
              #,forms
              (final ... #,(reverse (syntax->list #'binds)) #,@(reverse (syntax->list #'(accum ...)))))]
         [[(final ...) bind ...]
          #`(begin
              #,forms
              (final ... #,@(reverse (syntax->list #'(bind ...)))))]
         [_ forms])]
      [(_ ctx mode orig base-ctx add-ctx remove-ctx (~and form ((~literal quote) v)) . forms)
       (loop #'(_ ctx mode orig base-ctx add-ctx remove-ctx . forms)
             (cons #'form accum))]
      [(_ ctx mode orig base-ctx add-ctx remove-ctx form . forms)
       (define exp-form (syntax-parse #'form
                          #:literals (module module*)
                          [(module . _) #'form]
                          [(module* . _) #'form]
                          [else
                           (local-expand #'form
                                         (syntax-local-context)
                                         (list #'rhombus-forward
                                               #'define-values
                                               #'define-syntaxes
                                               ;; etc.
                                               #'begin
                                               #'provide
                                               #'#%require
                                               #'begin-for-syntax)
                                         #f)]))
       (syntax-parse exp-form
         #:literals (begin define-values define-syntaxes rhombus-forward #%require provide #%provide quote-syntax)
         [(rhombus-forward . sub-forms)
          (define introducer (make-syntax-introducer #t))
          #`(begin
              #,@(reverse accum)
              (sequence ctx #f #f base-ctx #,(introducer #'add-ctx) base-ctx . sub-forms)
              (sequence ctx mode orig base-ctx add-ctx #,(introducer #'remove-ctx)
                        . #,(introducer #'forms)))]
         [(begin form ...)
          (define seq #`(sequence ctx mode orig base-ctx add-ctx remove-ctx form ... . forms))
          (if (null? accum)
              seq
              #`(begin #,@(reverse accum) #,seq))]
         [((~and def (~or define-values define-syntaxes)) (id ...) rhs)
          #:with (new-id ...) ((make-syntax-delta-introducer #'remove-ctx #'base-ctx)
                               ((make-syntax-delta-introducer #'add-ctx #'base-ctx)
                                #'(id ...)
                                'add)
                               'remove)
          #`(begin
              #,@(reverse accum)
              #,(datum->syntax exp-form
                               (syntax-e #'(def (new-id ...) rhs))
                               exp-form
                               exp-form)
              (sequence ctx #:need-end-expr orig base-ctx add-ctx remove-ctx . forms))]
         [(#%require req ...)
          (define intro (let ([sub (make-syntax-delta-introducer #'remove-ctx #'base-ctx)]
                              [add (make-syntax-delta-introducer #'add-ctx #'base-ctx)])
                          (lambda (stx)
                            (sub (add stx 'add) 'remove))))
          (define reqs
            (for/list ([req (in-list (cdr (syntax->list exp-form)))])
              (syntax-parse req
                #:datum-literals (portal)
                [((~and tag portal) id content) #`(tag #,(intro #'id) content)]
                [_ (intro req)])))
          (cond
            [(eq? (syntax-e #'ctx) '#:block)
             (for ([req (in-list reqs)])
               (syntax-local-lift-require (syntax-local-introduce req) #'use #f))
             #`(sequence ctx mode orig base-ctx add-ctx remove-ctx . forms)]
            [else
             #`(begin
                 (#%require #,@reqs)
                 (sequence ctx mode orig base-ctx add-ctx remove-ctx . forms))])]
         [(provide prov ...)
          #:when (not (keyword? (syntax-e #'ctx)))
          (define rev-prov (reverse (syntax->list #'(prov ...))))
          (define new-ctx
            (syntax-parse #'ctx
              [(head #:stop-at* stop-id binds-tail . tail)
               #`(head #:stop-at* stop-id (#,@rev-prov . binds-tail) . tail)]
              [(head . tail)
               #`(head #,@rev-prov . tail)]))
          #`(sequence #,new-ctx mode orig base-ctx add-ctx remove-ctx . forms)]
         [(#%provide . _)
          (raise-syntax-error #f "shouldn't happen" exp-form)]
         [(quote-syntax (~and keep (id:identifier . _)) #:local)
          #:do [(define next
                  (syntax-parse #'ctx
                    [(head #:stop-at stop-id . tail)
                     (free-identifier=? #'id #'stop-id)
                     #`(begin
                         #,@(reverse accum)
                         (sequence (head #:stop-at stop-id keep . tail) #:saw-non-defn #f base-ctx add-ctx remove-ctx . forms))]
                    [(head #:stop-at* stop-id binds . tail)
                     (free-identifier=? #'id #'stop-id)
                     #`(begin
                         #,@(reverse accum)
                         (sequence (head #:stop-at* stop-id binds keep . tail) #:saw-non-defn #f base-ctx add-ctx remove-ctx . forms))]
                    [_ #f]))]
          #:when next
          next]
         [_ #`(begin
                #,@(reverse accum)
                #,exp-form
                (sequence ctx #:saw-non-defn #f base-ctx add-ctx remove-ctx . forms))])])))

(define-syntax (rhombus-forward stx)
  (raise-syntax-error #f
                      "should not get expanded"
                      stx))
