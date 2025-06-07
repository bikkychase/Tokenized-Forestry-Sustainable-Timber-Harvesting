;; Harvest Planning Contract
;; Plans and manages sustainable timber harvesting

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PLAN (err u202))
(define-constant ERR_PLAN_EXPIRED (err u203))

;; Data structures
(define-map harvest-plans uint {
  owner: principal,
  forest-area: uint,
  planned-volume: uint,
  harvest-method: (string-ascii 50),
  start-date: uint,
  end-date: uint,
  sustainability-score: uint,
  status: (string-ascii 20),
  created-at: uint
})

(define-map owner-plans principal (list 10 uint))
(define-data-var plan-counter uint u0)

;; Read-only functions
(define-read-only (get-plan (plan-id uint))
  (map-get? harvest-plans plan-id)
)

(define-read-only (get-owner-plans (owner principal))
  (default-to (list) (map-get? owner-plans owner))
)

(define-read-only (calculate-sustainability-score (forest-area uint) (planned-volume uint))
  (let ((harvest-ratio (/ (* planned-volume u100) forest-area)))
    (if (<= harvest-ratio u30)
      u100
      (if (<= harvest-ratio u50)
        u75
        (if (<= harvest-ratio u70)
          u50
          u25
        )
      )
    )
  )
)

;; Public functions
(define-public (create-harvest-plan
  (forest-area uint)
  (planned-volume uint)
  (harvest-method (string-ascii 50))
  (duration-blocks uint))
  (let (
    (plan-id (+ (var-get plan-counter) u1))
    (sustainability-score (calculate-sustainability-score forest-area planned-volume))
    (current-plans (get-owner-plans tx-sender))
  )
    (asserts! (> forest-area u0) ERR_INVALID_PLAN)
    (asserts! (> planned-volume u0) ERR_INVALID_PLAN)
    (asserts! (> duration-blocks u0) ERR_INVALID_PLAN)
    (asserts! (>= sustainability-score u50) ERR_INVALID_PLAN)

    (map-set harvest-plans plan-id {
      owner: tx-sender,
      forest-area: forest-area,
      planned-volume: planned-volume,
      harvest-method: harvest-method,
      start-date: block-height,
      end-date: (+ block-height duration-blocks),
      sustainability-score: sustainability-score,
      status: "pending",
      created-at: block-height
    })

    (map-set owner-plans tx-sender (unwrap! (as-max-len? (append current-plans plan-id) u10) ERR_INVALID_PLAN))
    (var-set plan-counter plan-id)
    (ok plan-id)
  )
)

(define-public (approve-plan (plan-id uint))
  (let ((plan (unwrap! (map-get? harvest-plans plan-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status plan) "pending") ERR_INVALID_PLAN)

    (map-set harvest-plans plan-id (merge plan { status: "approved" }))
    (ok true)
  )
)

(define-public (complete-plan (plan-id uint))
  (let ((plan (unwrap! (map-get? harvest-plans plan-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner plan)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status plan) "approved") ERR_INVALID_PLAN)

    (map-set harvest-plans plan-id (merge plan { status: "completed" }))
    (ok true)
  )
)
