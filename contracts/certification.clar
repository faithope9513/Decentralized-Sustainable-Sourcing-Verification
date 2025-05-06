;; certification.clar
;; This contract records authenticated sustainability claims

(define-data-var admin principal tx-sender)

;; Map to store certifications
(define-map certifications uint
  {
    supplier: principal,
    certification-type: (string-utf8 100),
    issue-date: uint,
    expiry-date: uint,
    certifier: principal,
    certification-hash: (buff 32),
    revoked: bool
  }
)

;; Map to store authorized certifiers
(define-map certifiers principal
  {
    name: (string-utf8 100),
    active: bool
  }
)

;; Counter for certification IDs
(define-data-var certification-id-counter uint u1)

;; Public function to register a certifier (only admin)
(define-public (register-certifier (certifier principal) (name (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok (map-set certifiers certifier
      {
        name: name,
        active: true
      }
    ))
  )
)

;; Public function to issue a certification (only certifiers)
(define-public (issue-certification
                (supplier principal)
                (certification-type (string-utf8 100))
                (validity-period uint)
                (certification-hash (buff 32)))
  (let ((cert-id (var-get certification-id-counter)))
    (begin
      (match (map-get? certifiers tx-sender)
        certifier-data
          (begin
            (asserts! (get active certifier-data) (err u2))
            (map-set certifications cert-id
              {
                supplier: supplier,
                certification-type: certification-type,
                issue-date: block-height,
                expiry-date: (+ block-height validity-period),
                certifier: tx-sender,
                certification-hash: certification-hash,
                revoked: false
              }
            )
            (var-set certification-id-counter (+ cert-id u1))
            (ok cert-id))
        (err u1)
      )
    )
  )
)

;; Public function to revoke a certification (only issuing certifier or admin)
(define-public (revoke-certification (certification-id uint))
  (match (map-get? certifications certification-id)
    cert-data
      (begin
        (asserts! (or
                    (is-eq tx-sender (get certifier cert-data))
                    (is-eq tx-sender (var-get admin)))
                  (err u1))
        (ok (map-set certifications certification-id
          (merge cert-data { revoked: true }))))
    (err u404)
  )
)

;; Public function to verify a certification
(define-read-only (verify-certification (certification-id uint))
  (match (map-get? certifications certification-id)
    cert-data
      (if (get revoked cert-data)
        (err u2) ;; Certification revoked
        (if (< (get expiry-date cert-data) block-height)
          (err u3) ;; Certification expired
          (ok cert-data)))
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
