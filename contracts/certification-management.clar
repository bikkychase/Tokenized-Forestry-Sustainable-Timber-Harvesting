;; Certification Management Contract
;; Manages forest certifications and compliance

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_EXPIRED (err u402))
(define-constant ERR_INVALID_DATA (err u403))

;; Data structures
(define-map certifications uint {
  owner: principal,
  cert-type: (string-ascii 50),
  issuing-body: (string-ascii 100),
  issue-date: uint,
  expiry-date: uint,
  status: (string-ascii 20),
  compliance-score: uint
})

(define-map owner-certifications principal (list 5 uint))
(define-data-var cert-counter uint u0)

;; Certification types
(define-constant FSC-CERT "FSC")
(define-constant PEFC-CERT "PEFC")
(define-constant SFI-CERT "SFI")

;; Read-only functions
(define-read-only (get-certification (cert-id uint))
  (map-get? certifications cert-id)
)

(define-read-only (get-owner-certifications (owner principal))
  (default-to (list) (map-get? owner-certifications owner))
)

(define-read-only (is-certification-valid (cert-id uint))
  (match (map-get? certifications cert-id)
    cert (and
      (is-eq (get status cert) "active")
      (> (get expiry-date cert) block-height)
    )
    false
  )
)

(define-read-only (has-valid-certification (owner principal) (cert-type (string-ascii 50)))
  (let ((owner-certs (get-owner-certifications owner)))
    (is-some (filter check-cert-type-and-validity owner-certs))
  )
)

(define-private (check-cert-type-and-validity (cert-id uint))
  (match (map-get? certifications cert-id)
    cert (and
      (is-eq (get cert-type cert) cert-type)
      (is-certification-valid cert-id)
    )
    false
  )
)

;; Public functions
(define-public (issue-certification
  (owner principal)
  (cert-type (string-ascii 50))
  (issuing-body (string-ascii 100))
  (validity-blocks uint)
  (compliance-score uint))
  (let (
    (cert-id (+ (var-get cert-counter) u1))
    (owner-certs (get-owner-certifications owner))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len cert-type) u0) ERR_INVALID_DATA)
    (asserts! (> (len issuing-body) u0) ERR_INVALID_DATA)
    (asserts! (> validity-blocks u0) ERR_INVALID_DATA)
    (asserts! (<= compliance-score u100) ERR_INVALID_DATA)

    (map-set certifications cert-id {
      owner: owner,
      cert-type: cert-type,
      issuing-body: issuing-body,
      issue-date: block-height,
      expiry-date: (+ block-height validity-blocks),
      status: "active",
      compliance-score: compliance-score
    })

    (map-set owner-certifications owner
      (unwrap! (as-max-len? (append owner-certs cert-id) u5) ERR_INVALID_DATA))

    (var-set cert-counter cert-id)
    (ok cert-id)
  )
)

(define-public (renew-certification (cert-id uint) (validity-blocks uint))
  (let ((cert (unwrap! (map-get? certifications cert-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> validity-blocks u0) ERR_INVALID_DATA)

    (map-set certifications cert-id (merge cert {
      issue-date: block-height,
      expiry-date: (+ block-height validity-blocks),
      status: "active"
    }))
    (ok true)
  )
)

(define-public (revoke-certification (cert-id uint))
  (let ((cert (unwrap! (map-get? certifications cert-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set certifications cert-id (merge cert { status: "revoked" }))
    (ok true)
  )
)

(define-public (update-compliance-score (cert-id uint) (new-score uint))
  (let ((cert (unwrap! (map-get? certifications cert-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-score u100) ERR_INVALID_DATA)

    (map-set certifications cert-id (merge cert { compliance-score: new-score }))
    (ok true)
  )
)
