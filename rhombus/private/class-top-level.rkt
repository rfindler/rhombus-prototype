#lang racket/base
(require (for-syntax racket/base
                     syntax/parse/pre)
         (only-in (submod "annotation.rkt" for-class)
                  define-annotation-syntax
                  define-annotation-constructor)
         (only-in "binding.rkt"
                  define-binding-syntax)
         (only-in (submod "dot.rkt" for-dot-provider)
                  define-dot-provider-syntax)
         (only-in "name-root.rkt"
                  define-name-root)
         (only-in "class-desc.rkt"
                  define-class-desc-syntax)
         (only-in "class-method-result.rkt"
                  define-method-result-syntax))

(provide (for-syntax top-level-declare
                     reorder-for-top-level))

(define-for-syntax (top-level-declare ids-stx)
  (cond
    [(eq? (syntax-local-context) 'top-level)
     ;; avoid duplicate definitions here; they'll get reported by later checking
     (define (remove-dups stx)
       (let loop ([ids (syntax->list stx)] [seen #hasheq()])
         (cond
           [(null? ids) null]
           [(hash-ref seen (syntax-e (car ids)) #f) (loop (cdr ids) seen)]
           [else (cons (car ids)
                       (loop (cdr ids) (hash-set seen (syntax-e (car ids)) #t)))])))
     (list #`(define-syntaxes #,(remove-dups ids-stx) (values)))]
    [else null]))

(define-for-syntax (reorder-for-top-level defs)
  (cond
    [(eq? (syntax-local-context) 'top-level)
     (let loop ([defs defs] [stxs '()] [vars '()] [var-names '()])
       (cond
         [(null? defs)
          (append
           (list #`(define-syntaxes #,var-names (values)))
           (reverse stxs)
           (reverse vars))]
         [else
          (define def (car defs))
          (define (keep-stx)
            (loop (cdr defs) (cons def stxs) vars var-names))
          (syntax-parse def
            [((~literal define) (id . _) . _)
             (loop (cdr defs) stxs (cons def vars) (cons #'id var-names))]
            [((~literal define) id rhs)
             (loop (cdr defs) stxs (cons def vars) (cons #'id var-names))]
            [((~literal define-values) (id ...) rhs)
             (loop (cdr defs) stxs (cons def vars) (append (syntax->list #'(id ...)) var-names))]
            [((~literal define-syntax) . _) (keep-stx)]
            [((~literal define-syntaxes) . _) (keep-stx)]
            [((~literal define-class-desc-syntax) . _) (keep-stx)]
            [((~literal define-name-root) . _) (keep-stx)]
            [((~literal define-binding-syntax) . _) (keep-stx)]
            [((~literal define-annotation-syntax) . _) (keep-stx)]
            [((~literal define-annotation-constructor) . _) (keep-stx)]
            [((~literal define-dot-provider-syntax) . _) (keep-stx)]
            [((~literal define-method-result-syntax) . _) (keep-stx)]
            [_
             (loop (cdr defs) stxs (cons def vars) var-names)])]))]
    [else defs]))
