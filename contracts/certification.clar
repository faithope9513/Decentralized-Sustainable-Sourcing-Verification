;; consumer-verification.clar
;; This contract enables confirmation of sustainability claims for consumers

(define-data-var admin principal tx-sender)

;; Map to store product sustainability claims
(define-map product-claims (buff 32)
  {
    supplier: principal,
    product-name: (string-utf8 100),
    certifications: (list 10 uint),
    standards-compliance: (list 10 (tuple (standard-id uint) (compliant bool))),
    created-at: uint,
    valid-until: uint
  }
)

;; Public function to register a product claim (suppliers only)
(define-public (register-product-claim
                (product-hash (buff 32))
                (product-name (string-utf8 100))
                (certifications (list 10 uint))
                (standards-compliance (list 10 (tuple (standard-id uint) (compliant bool))))
                (validity-period uint))
  (begin
    (asserts! (is-none (map-get? product-claims product-hash)) (err u1))
    (ok (map-set product-claims product-hash
      {
        supplier: tx-sender,
        product-name: product-name,
        certifications: certifications,
        standards-compliance: standards-compliance,
        created-at: block-height,
        valid-until: (+ block-height validity-period)
      }
    ))
  )
)

;; Public function to verify a product's sustainability claims
(define-read-only (verify-product (product-hash (buff 32)))
  (match (map-get? product-claims product-hash)
    product-data
      (if (< (get valid-until product-data) block-height)
        (err u2) ;; Claim expired
        (ok product-data))
    (err u404)
  )
)

;; Public function to update a product claim (only original supplier)
(define-public (update-product-claim
                (product-hash (buff 32))
                (certifications (list 10 uint))
                (standards-compliance (list 10 (tuple (standard-id uint) (compliant bool))))
                (validity-period uint))
  (match (map-get? product-claims product-hash)
    product-data
      (begin
        (asserts! (is-eq tx-sender (get supplier product-data)) (err u1))
        (ok (map-set product-claims product-hash
          (merge product-data
            {
              certifications: certifications,
              standards-compliance: standards-compliance,
              valid-until: (+ block-height validity-period)
            }
          ))))
    (err u404)
  )
)

;; Public function to invalidate a product claim (only admin or supplier)
(define-public (invalidate-product-claim (product-hash (buff 32)))
  (match (map-get? product-claims product-hash)
    product-data
      (begin
        (asserts! (or
                    (is-eq tx-sender (get supplier product-data))
                    (is-eq tx-sender (var-get admin)))
                  (err u1))
        (ok (map-set product-claims product-hash
          (merge product-data { valid-until: block-height }))))
    (err u404)
  )
)

;; Public function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (var-set admin new-admin))
  )
)
