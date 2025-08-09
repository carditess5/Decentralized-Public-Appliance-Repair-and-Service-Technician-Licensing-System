;; Consumer Complaint Resolution Contract
;; Handles disputes between customers and appliance repair companies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-COMPLAINT-NOT-FOUND (err u501))
(define-constant ERR-INVALID-STATUS (err u502))
(define-constant ERR-ALREADY-RESOLVED (err u503))
(define-constant ERR-INVALID-RATING (err u504))
(define-constant ERR-MEDIATOR-NOT-FOUND (err u505))

;; Data Variables
(define-data-var next-complaint-id uint u1)
(define-data-var next-mediator-id uint u1)

;; Data Maps
(define-map complaints
  { complaint-id: uint }
  {
    customer: principal,
    technician: principal,
    service-id: (optional uint),
    complaint-type: (string-ascii 30),
    description: (string-ascii 300),
    severity: (string-ascii 10),
    filed-date: uint,
    status: (string-ascii 15),
    assigned-mediator: (optional uint),
    resolution-date: (optional uint),
    resolution-details: (optional (string-ascii 200)),
    customer-satisfied: (optional bool),
    compensation-amount: uint
  }
)

(define-map mediators
  { mediator-id: uint }
  {
    mediator: principal,
    name: (string-ascii 50),
    specialization: (string-ascii 30),
    cases-handled: uint,
    success-rate: uint,
    active: bool
  }
)

(define-map complaint-evidence
  { complaint-id: uint, evidence-id: uint }
  {
    evidence-type: (string-ascii 20),
    description: (string-ascii 100),
    submitted-by: principal,
    timestamp: uint
  }
)

(define-map technician-performance
  { technician: principal }
  {
    total-complaints: uint,
    resolved-complaints: uint,
    average-resolution-time: uint,
    customer-satisfaction: uint
  }
)

(define-data-var next-evidence-id uint u1)

;; Private Functions
(define-private (is-valid-complaint-status (status (string-ascii 15)))
  (or
    (is-eq status "filed")
    (is-eq status "investigating")
    (is-eq status "mediation")
    (is-eq status "resolved")
    (is-eq status "closed")
  )
)

(define-private (update-technician-stats (technician principal) (resolved bool))
  (let
    (
      (current-stats (default-to
        { total-complaints: u0, resolved-complaints: u0, average-resolution-time: u0, customer-satisfaction: u0 }
        (map-get? technician-performance { technician: technician })
      ))
    )
    (map-set technician-performance
      { technician: technician }
      (merge current-stats {
        total-complaints: (+ (get total-complaints current-stats) u1),
        resolved-complaints: (if resolved (+ (get resolved-complaints current-stats) u1) (get resolved-complaints current-stats))
      })
    )
    (ok true)
  )
)

;; Public Functions

;; File a new complaint
(define-public (file-complaint (technician principal) (service-id (optional uint)) (complaint-type (string-ascii 30)) (description (string-ascii 300)) (severity (string-ascii 10)))
  (let
    (
      (complaint-id (var-get next-complaint-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (map-set complaints
      { complaint-id: complaint-id }
      {
        customer: tx-sender,
        technician: technician,
        service-id: service-id,
        complaint-type: complaint-type,
        description: description,
        severity: severity,
        filed-date: current-time,
        status: "filed",
        assigned-mediator: none,
        resolution-date: none,
        resolution-details: none,
        customer-satisfied: none,
        compensation-amount: u0
      }
    )

    (unwrap-panic (update-technician-stats technician false))
    (var-set next-complaint-id (+ complaint-id u1))
    (ok complaint-id)
  )
)

;; Register a mediator
(define-public (register-mediator (name (string-ascii 50)) (specialization (string-ascii 30)))
  (let
    (
      (mediator-id (var-get next-mediator-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set mediators
      { mediator-id: mediator-id }
      {
        mediator: tx-sender,
        name: name,
        specialization: specialization,
        cases-handled: u0,
        success-rate: u100,
        active: true
      }
    )

    (var-set next-mediator-id (+ mediator-id u1))
    (ok mediator-id)
  )
)

;; Assign mediator to complaint
(define-public (assign-mediator (complaint-id uint) (mediator-id uint))
  (let
    (
      (complaint-data (unwrap! (map-get? complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND))
      (mediator-data (unwrap! (map-get? mediators { mediator-id: mediator-id }) ERR-MEDIATOR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (get active mediator-data) ERR-MEDIATOR-NOT-FOUND)

    (map-set complaints
      { complaint-id: complaint-id }
      (merge complaint-data {
        status: "investigating",
        assigned-mediator: (some mediator-id)
      })
    )
    (ok true)
  )
)

;; Submit evidence for complaint
(define-public (submit-evidence (complaint-id uint) (evidence-type (string-ascii 20)) (description (string-ascii 100)))
  (let
    (
      (complaint-data (unwrap! (map-get? complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND))
      (evidence-id (var-get next-evidence-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or
      (is-eq tx-sender (get customer complaint-data))
      (is-eq tx-sender (get technician complaint-data))
    ) ERR-NOT-AUTHORIZED)

    (map-set complaint-evidence
      { complaint-id: complaint-id, evidence-id: evidence-id }
      {
        evidence-type: evidence-type,
        description: description,
        submitted-by: tx-sender,
        timestamp: current-time
      }
    )

    (var-set next-evidence-id (+ evidence-id u1))
    (ok evidence-id)
  )
)

;; Resolve complaint
(define-public (resolve-complaint (complaint-id uint) (resolution-details (string-ascii 200)) (compensation-amount uint))
  (let
    (
      (complaint-data (unwrap! (map-get? complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (mediator-id (unwrap! (get assigned-mediator complaint-data) ERR-NOT-AUTHORIZED))
      (mediator-data (unwrap! (map-get? mediators { mediator-id: mediator-id }) ERR-MEDIATOR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get mediator mediator-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status complaint-data) "resolved")) ERR-ALREADY-RESOLVED)

    (map-set complaints
      { complaint-id: complaint-id }
      (merge complaint-data {
        status: "resolved",
        resolution-date: (some current-time),
        resolution-details: (some resolution-details),
        compensation-amount: compensation-amount
      })
    )

    (map-set mediators
      { mediator-id: mediator-id }
      (merge mediator-data {
        cases-handled: (+ (get cases-handled mediator-data) u1)
      })
    )

    (unwrap-panic (update-technician-stats (get technician complaint-data) true))
    (ok true)
  )
)

;; Customer satisfaction rating
(define-public (rate-resolution (complaint-id uint) (satisfied bool))
  (let
    (
      (complaint-data (unwrap! (map-get? complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get customer complaint-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status complaint-data) "resolved") ERR-INVALID-STATUS)

    (map-set complaints
      { complaint-id: complaint-id }
      (merge complaint-data {
        customer-satisfied: (some satisfied),
        status: "closed"
      })
    )
    (ok true)
  )
)

;; Escalate complaint to mediation
(define-public (escalate-to-mediation (complaint-id uint))
  (let
    (
      (complaint-data (unwrap! (map-get? complaints { complaint-id: complaint-id }) ERR-COMPLAINT-NOT-FOUND))
    )
    (asserts! (or
      (is-eq tx-sender (get customer complaint-data))
      (is-eq tx-sender (get technician complaint-data))
    ) ERR-NOT-AUTHORIZED)

    (map-set complaints
      { complaint-id: complaint-id }
      (merge complaint-data { status: "mediation" })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get complaint information
(define-read-only (get-complaint (complaint-id uint))
  (map-get? complaints { complaint-id: complaint-id })
)

;; Get mediator information
(define-read-only (get-mediator (mediator-id uint))
  (map-get? mediators { mediator-id: mediator-id })
)

;; Get evidence for complaint
(define-read-only (get-evidence (complaint-id uint) (evidence-id uint))
  (map-get? complaint-evidence { complaint-id: complaint-id, evidence-id: evidence-id })
)

;; Get technician performance stats
(define-read-only (get-technician-performance (technician principal))
  (map-get? technician-performance { technician: technician })
)

;; Get total complaints filed
(define-read-only (get-total-complaints)
  (- (var-get next-complaint-id) u1)
)

;; Calculate complaint resolution rate
(define-read-only (get-resolution-rate (technician principal))
  (match (map-get? technician-performance { technician: technician })
    stats
      (if (> (get total-complaints stats) u0)
        (/ (* (get resolved-complaints stats) u100) (get total-complaints stats))
        u100
      )
    u100
  )
)
