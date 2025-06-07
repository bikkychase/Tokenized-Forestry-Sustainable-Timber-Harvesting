;; Forest Owner Verification Contract
;; Validates and manages forest landowners

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_DATA (err u103))

;; Data maps
(define-map verified-owners principal {
  name: (string-ascii 100),
  location: (string-ascii 200),
  forest-size: uint,
  verification-date: uint,
  is-active: bool
})

(define-map pending-verifications principal {
  name: (string-ascii 100),
  location: (string-ascii 200),
  forest-size: uint,
  submitted-date: uint
})

;; Read-only functions
(define-read-only (get-owner-info (owner principal))
  (map-get? verified-owners owner)
)

(define-read-only (is-verified-owner (owner principal))
  (is-some (map-get? verified-owners owner))
)

(define-read-only (get-pending-verification (owner principal))
  (map-get? pending-verifications owner)
)

;; Public functions
(define-public (submit-verification (name (string-ascii 100)) (location (string-ascii 200)) (forest-size uint))
  (begin
    (asserts! (> (len name) u0) ERR_INVALID_DATA)
    (asserts! (> (len location) u0) ERR_INVALID_DATA)
    (asserts! (> forest-size u0) ERR_INVALID_DATA)
    (asserts! (is-none (map-get? verified-owners tx-sender)) ERR_ALREADY_VERIFIED)

    (map-set pending-verifications tx-sender {
      name: name,
      location: location,
      forest-size: forest-size,
      submitted-date: block-height
    })
    (ok true)
  )
)

(define-public (approve-verification (owner principal))
  (let ((pending-info (unwrap! (map-get? pending-verifications owner) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set verified-owners owner {
      name: (get name pending-info),
      location: (get location pending-info),
      forest-size: (get forest-size pending-info),
      verification-date: block-height,
      is-active: true
    })

    (map-delete pending-verifications owner)
    (ok true)
  )
)

(define-public (deactivate-owner (owner principal))
  (let ((owner-info (unwrap! (map-get? verified-owners owner) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set verified-owners owner (merge owner-info { is-active: false }))
    (ok true)
  )
)
