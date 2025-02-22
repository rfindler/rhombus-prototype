#lang racket/base
(require (for-syntax racket/base
                     shrubbery/property
                     racket/syntax-srcloc)
         (only-in rhombus/private/name-root-ref
                  portal-syntax->lookup)
         (only-in rhombus/private/name-root-space
                  in-name-root-space))

(provide (for-syntax
          resolve-name-ref
          append-consecutive-syntax-objects))

(define-for-syntax (append-consecutive-syntax-objects datum pre t)
  (define pre-loc (syntax-srcloc pre))
  (define t-loc (syntax-srcloc pre))
  (define t/s (if (and pre-loc
                       t-loc
                       (equal? (srcloc-source pre-loc)
                               (srcloc-source t-loc))
                       (srcloc-position t-loc)
                       (srcloc-span t-loc)
                       (srcloc-position pre-loc)
                       ((srcloc-position pre-loc) . < . (srcloc-position t-loc)))
                  (datum->syntax t
                                 datum
                                 (struct-copy srcloc pre-loc
                                              [span (- (+ (srcloc-position t-loc)
                                                          (srcloc-span t-loc))
                                                       (srcloc-position pre-loc))])
                                 t
                                 t)
                  t))
  (syntax-raw-prefix-property t/s (syntax-raw-prefix-property pre)))

(define-for-syntax (resolve-name-ref space-name root fields
                                     #:parens [ptag #f])
  (let loop ([root root] [fields fields])
    (cond
      [(null? fields) #f]
      [else
       (define field (car fields))
       (define p (identifier-binding-portal-syntax (in-name-root-space root) #f))
       (define lookup (and p (portal-syntax->lookup p (lambda (self-id lookup) lookup))))
       (define intro (if space-name
                         (make-interned-syntax-introducer space-name)
                         (lambda (x) x)))
       (define dest (and lookup (lookup #f "identifier" field intro)))
       (define parens? (and ptag (null? (cdr fields))))
       (define raw (format "~a.~a~a~a"
                           (or (syntax-raw-property root)
                               (syntax-e root))
                           (if parens? "(" "")
                           (syntax-e field)
                           (if parens? ")" "")))
       (define (transfer-parens-suffix p)
         (if parens?
             (syntax-raw-suffix-property p (cons
                                            (or (syntax-raw-suffix-property p) '())
                                            (syntax-raw-tail-suffix-property ptag)))
             p))
       (define (add-rest p) (and p (cons p (cdr fields))))
       (cond
         [dest
          (define loc-stx
            (append-consecutive-syntax-objects
             'loc-stx
             (append-consecutive-syntax-objects 'loc-stx root #'dot)
             field))
          (define named-dest
            (transfer-parens-suffix
             (syntax-raw-property (datum->syntax dest (syntax-e dest) loc-stx loc-stx)
                                  raw)))
          (or (loop named-dest (cdr fields))
              (add-rest named-dest))]
         [else
          (define id (intro (datum->syntax root (string->symbol raw))))
          (and (identifier-binding id #f)
               (let ([named-id (transfer-parens-suffix
                                (syntax-raw-property
                                 (datum->syntax id (syntax-e id)
                                                (append-consecutive-syntax-objects
                                                 'loc-stx
                                                 (append-consecutive-syntax-objects 'loc-stx root #'dot)
                                                 field))
                                 raw))])
                 (or (loop named-id (cdr fields))
                     (add-rest named-id))))])])))
