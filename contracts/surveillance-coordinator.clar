;; Surveillance Coordinator Verification Contract
;; Manages verification and registration of security surveillance coordinators

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Coordinator status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map coordinators
  { coordinator: principal }
  {
    status: uint,
    registered-at: uint,
    verified-at: (optional uint),
    credentials-hash: (buff 32)
  }
)

(define-map coordinator-stats
  { coordinator: principal }
  {
    alerts-processed: uint,
    responses-coordinated: uint,
    evidence-managed: uint
  }
)

(define-data-var total-coordinators uint u0)

;; Register a new coordinator
(define-public (register-coordinator (credentials-hash (buff 32)))
  (let ((coordinator tx-sender))
    (asserts! (is-none (map-get? coordinators { coordinator: coordinator })) ERR_ALREADY_REGISTERED)
    (map-set coordinators
      { coordinator: coordinator }
      {
        status: STATUS_PENDING,
        registered-at: block-height,
        verified-at: none,
        credentials-hash: credentials-hash
      }
    )
    (map-set coordinator-stats
      { coordinator: coordinator }
      {
        alerts-processed: u0,
        responses-coordinated: u0,
        evidence-managed: u0
      }
    )
    (var-set total-coordinators (+ (var-get total-coordinators) u1))
    (ok coordinator)
  )
)

;; Verify a coordinator (only contract owner)
(define-public (verify-coordinator (coordinator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? coordinators { coordinator: coordinator })
      coordinator-data
      (begin
        (map-set coordinators
          { coordinator: coordinator }
          (merge coordinator-data { status: STATUS_VERIFIED, verified-at: (some block-height) })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

;; Update coordinator status
(define-public (update-coordinator-status (coordinator principal) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)
    (match (map-get? coordinators { coordinator: coordinator })
      coordinator-data
      (begin
        (map-set coordinators
          { coordinator: coordinator }
          (merge coordinator-data { status: new-status })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

;; Get coordinator info
(define-read-only (get-coordinator (coordinator principal))
  (map-get? coordinators { coordinator: coordinator })
)

;; Check if coordinator is verified
(define-read-only (is-verified-coordinator (coordinator principal))
  (match (map-get? coordinators { coordinator: coordinator })
    coordinator-data (is-eq (get status coordinator-data) STATUS_VERIFIED)
    false
  )
)

;; Get coordinator stats
(define-read-only (get-coordinator-stats (coordinator principal))
  (map-get? coordinator-stats { coordinator: coordinator })
)

;; Get total coordinators
(define-read-only (get-total-coordinators)
  (var-get total-coordinators)
)
