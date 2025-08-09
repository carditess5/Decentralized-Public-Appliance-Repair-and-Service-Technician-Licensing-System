;; Parts Inventory Tracking Contract
;; Monitors availability of replacement parts for common appliance repairs

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-PART-NOT-FOUND (err u301))
(define-constant ERR-INSUFFICIENT-STOCK (err u302))
(define-constant ERR-INVALID-QUANTITY (err u303))
(define-constant ERR-SUPPLIER-NOT-FOUND (err u304))

;; Data Variables
(define-data-var next-part-id uint u1)
(define-data-var next-supplier-id uint u1)

;; Data Maps
(define-map parts-inventory
  { part-number: (string-ascii 30) }
  {
    part-id: uint,
    name: (string-ascii 50),
    category: (string-ascii 20),
    compatible-appliances: (string-ascii 100),
    current-stock: uint,
    reorder-point: uint,
    unit-price: uint,
    supplier-id: uint,
    last-updated: uint
  }
)

(define-map suppliers
  { supplier-id: uint }
  {
    name: (string-ascii 50),
    contact-info: (string-ascii 100),
    reliability-score: uint,
    active: bool
  }
)

(define-map stock-movements
  { movement-id: uint }
  {
    part-number: (string-ascii 30),
    movement-type: (string-ascii 10),
    quantity: uint,
    timestamp: uint,
    technician: (optional principal)
  }
)

(define-data-var next-movement-id uint u1)

;; Private Functions
(define-private (update-stock (part-number (string-ascii 30)) (new-quantity uint))
  (let
    (
      (part-data (unwrap! (map-get? parts-inventory { part-number: part-number }) ERR-PART-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (map-set parts-inventory
      { part-number: part-number }
      (merge part-data {
        current-stock: new-quantity,
        last-updated: current-time
      })
    )
    (ok true)
  )
)

(define-private (record-movement (part-number (string-ascii 30)) (movement-type (string-ascii 10)) (quantity uint) (technician (optional principal)))
  (let
    (
      (movement-id (var-get next-movement-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (map-set stock-movements
      { movement-id: movement-id }
      {
        part-number: part-number,
        movement-type: movement-type,
        quantity: quantity,
        timestamp: current-time,
        technician: technician
      }
    )
    (var-set next-movement-id (+ movement-id u1))
    (ok movement-id)
  )
)

;; Public Functions

;; Add a new part to inventory
(define-public (add-part (part-number (string-ascii 30)) (name (string-ascii 50)) (category (string-ascii 20)) (compatible-appliances (string-ascii 100)) (initial-stock uint) (reorder-point uint) (unit-price uint) (supplier-id uint))
  (let
    (
      (part-id (var-get next-part-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? parts-inventory { part-number: part-number })) ERR-PART-NOT-FOUND)
    (asserts! (is-some (map-get? suppliers { supplier-id: supplier-id })) ERR-SUPPLIER-NOT-FOUND)

    (map-set parts-inventory
      { part-number: part-number }
      {
        part-id: part-id,
        name: name,
        category: category,
        compatible-appliances: compatible-appliances,
        current-stock: initial-stock,
        reorder-point: reorder-point,
        unit-price: unit-price,
        supplier-id: supplier-id,
        last-updated: current-time
      }
    )

    (unwrap-panic (record-movement part-number "restock" initial-stock none))
    (var-set next-part-id (+ part-id u1))
    (ok part-id)
  )
)

;; Add a new supplier
(define-public (add-supplier (name (string-ascii 50)) (contact-info (string-ascii 100)))
  (let
    (
      (supplier-id (var-get next-supplier-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set suppliers
      { supplier-id: supplier-id }
      {
        name: name,
        contact-info: contact-info,
        reliability-score: u100,
        active: true
      }
    )

    (var-set next-supplier-id (+ supplier-id u1))
    (ok supplier-id)
  )
)

;; Restock parts
(define-public (restock-part (part-number (string-ascii 30)) (quantity uint))
  (let
    (
      (part-data (unwrap! (map-get? parts-inventory { part-number: part-number }) ERR-PART-NOT-FOUND))
      (new-stock (+ (get current-stock part-data) quantity))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> quantity u0) ERR-INVALID-QUANTITY)

    (unwrap-panic (update-stock part-number new-stock))
    (unwrap-panic (record-movement part-number "restock" quantity none))
    (ok new-stock)
  )
)

;; Use parts (for technicians)
(define-public (use-part (part-number (string-ascii 30)) (quantity uint))
  (let
    (
      (part-data (unwrap! (map-get? parts-inventory { part-number: part-number }) ERR-PART-NOT-FOUND))
      (current-stock (get current-stock part-data))
    )
    (asserts! (> quantity u0) ERR-INVALID-QUANTITY)
    (asserts! (>= current-stock quantity) ERR-INSUFFICIENT-STOCK)

    (let
      (
        (new-stock (- current-stock quantity))
      )
      (unwrap-panic (update-stock part-number new-stock))
      (unwrap-panic (record-movement part-number "used" quantity (some tx-sender)))
      (ok new-stock)
    )
  )
)

;; Update part price
(define-public (update-part-price (part-number (string-ascii 30)) (new-price uint))
  (let
    (
      (part-data (unwrap! (map-get? parts-inventory { part-number: part-number }) ERR-PART-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set parts-inventory
      { part-number: part-number }
      (merge part-data { unit-price: new-price })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get part information
(define-read-only (get-part (part-number (string-ascii 30)))
  (map-get? parts-inventory { part-number: part-number })
)

;; Check part availability
(define-read-only (get-part-availability (part-number (string-ascii 30)))
  (match (map-get? parts-inventory { part-number: part-number })
    part-data (get current-stock part-data)
    u0
  )
)

;; Check if part needs reordering
(define-read-only (needs-reorder (part-number (string-ascii 30)))
  (match (map-get? parts-inventory { part-number: part-number })
    part-data (<= (get current-stock part-data) (get reorder-point part-data))
    false
  )
)

;; Get supplier information
(define-read-only (get-supplier (supplier-id uint))
  (map-get? suppliers { supplier-id: supplier-id })
)

;; Get stock movement
(define-read-only (get-movement (movement-id uint))
  (map-get? stock-movements { movement-id: movement-id })
)

;; Get total parts count
(define-read-only (get-total-parts)
  (- (var-get next-part-id) u1)
)
