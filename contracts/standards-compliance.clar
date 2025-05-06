;; standards-compliance.clar
;; This contract records adherence to sustainability criteria

(define-data-var admin principal tx-sender)

;; Map to store sustainability standards
(define-map sustainability-standards uint
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    created-at: uint
  }
)

;; Map to store supplier compliance with standards
(define-map supplier-compliance (tuple (supplier principal) (standard-id uint))
  {
    compliant: bool,
    compliance-date: uint,
    evidence-hash: (buff 32),
    expiry-date: uint
  }
)

;; Counter for standard IDs
(define-data-var standard-id-counter uint u1)

;; Public function to add a new sustainability standard (only admin)
(define-public (add-standard (name (string-utf8 100)) (description (string-utf8 500)))
  (let ((new-id (var-get standard-id-counter)))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1))
      (map-set sustainability-standards new-id
        {
          name: name,
          description: description,
          created-at: block-height
        }
      )
      (var-set standard-id-counter (+ new-id u1))
      (ok new-id)
    )
  )
)

;; Public function to record compliance for a supplier
(define-public (record-compliance
                (supplier principal)
                (standard-id uint)
                (evidence-hash (buff 32))
                (validity-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (asserts! (is-some (map-get? sustainability-standards standard-id)) (err u2))
    (ok (map-set supplier-compliance {supplier: supplier, standard-id: standard-id}
      {
        compliant: true,
        compliance-date: block-height,
        evidence-hash: evidence-hash,
        expiry-date: (+ block-height validity-period)
      }
    ))
  )
)

;; Public function to verify compliance
(define-read-only (verify-compliance (supplier principal) (standard-id uint))
  (match (map-get? supplier-compliance {supplier: supplier, standard-id: standard-id})
    compliance-data
      (if (< (get expiry-date compliance-data) block-height)
        (err u3) ;; Compliance expired
        (ok compliance-data))
    (err u404)
  )
)

;; Public function to get standard details
(define-read-only (get-standard (standard-id uint))
  (match (map-get? sustainability-standards standard-id)
    standard-data (ok standard-data)
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
