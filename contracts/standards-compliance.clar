;; audit-scheduling.clar
;; This contract manages regular compliance verification audits

(define-data-var admin principal tx-sender)

;; Map to store auditors
(define-map auditors principal
  {
    name: (string-utf8 100),
    active: bool,
    registered-at: uint
  }
)

;; Map to store scheduled audits
(define-map scheduled-audits uint
  {
    supplier: principal,
    auditor: principal,
    scheduled-date: uint,
    completed: bool,
    result-hash: (optional (buff 32))
  }
)

;; Counter for audit IDs
(define-data-var audit-id-counter uint u1)

;; Public function to register an auditor (only admin)
(define-public (register-auditor (auditor principal) (name (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (asserts! (is-none (map-get? auditors auditor)) (err u2))
    (ok (map-set auditors auditor
      {
        name: name,
        active: true,
        registered-at: block-height
      }
    ))
  )
)

;; Public function to schedule an audit
(define-public (schedule-audit (supplier principal) (auditor principal) (scheduled-date uint))
  (let ((audit-id (var-get audit-id-counter)))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u1))
      (asserts! (is-some (map-get? auditors auditor)) (err u2))
      (asserts! (> scheduled-date block-height) (err u3))
      (map-set scheduled-audits audit-id
        {
          supplier: supplier,
          auditor: auditor,
          scheduled-date: scheduled-date,
          completed: false,
          result-hash: none
        }
      )
      (var-set audit-id-counter (+ audit-id u1))
      (ok audit-id)
    )
  )
)

;; Public function to record audit results (only assigned auditor)
(define-public (record-audit-result (audit-id uint) (result-hash (buff 32)))
  (match (map-get? scheduled-audits audit-id)
    audit-data
      (begin
        (asserts! (is-eq tx-sender (get auditor audit-data)) (err u1))
        (asserts! (not (get completed audit-data)) (err u2))
        (ok (map-set scheduled-audits audit-id
          (merge audit-data
            {
              completed: true,
              result-hash: (some result-hash)
            }
          )
        )))
    (err u404)
  )
)

;; Public function to get audit details
(define-read-only (get-audit (audit-id uint))
  (match (map-get? scheduled-audits audit-id)
    audit-data (ok audit-data)
    (err u404)
  )
)

;; Public function to get auditor details
(define-read-only (get-auditor (auditor principal))
  (match (map-get? auditors auditor)
    auditor-data (ok auditor-data)
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
