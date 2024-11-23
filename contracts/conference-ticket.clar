;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-sold-out (err u101))
(define-constant err-invalid-payment (err u102))
(define-constant err-ticket-not-found (err u103))
(define-constant err-already-checked-in (err u104))

;; Define data variables
(define-data-var ticket-price uint u100)
(define-data-var total-tickets uint u1000)
(define-data-var tickets-sold uint u0)

;; Define data maps
(define-map tickets principal 
    {
        ticket-id: uint,
        checked-in: bool
    }
)

;; Public functions
(define-public (buy-ticket)
    (let (
        (tickets-remaining (- (var-get total-tickets) (var-get tickets-sold)))
    )
    (if (> tickets-remaining u0)
        (let (
            (payment (stx-transfer? (var-get ticket-price) tx-sender contract-owner))
        )
        (if (is-ok payment)
            (begin
                (map-set tickets tx-sender {
                    ticket-id: (var-get tickets-sold),
                    checked-in: false
                })
                (var-set tickets-sold (+ (var-get tickets-sold) u1))
                (ok true)
            )
            err-invalid-payment
        ))
        err-sold-out
    ))
)

;; Only contract owner can check in tickets
(define-public (check-in-ticket (attendee principal))
    (if (is-eq tx-sender contract-owner)
        (match (map-get? tickets attendee)
            ticket-data (
                if (get checked-in ticket-data)
                    err-already-checked-in
                    (begin
                        (map-set tickets attendee 
                            {
                                ticket-id: (get ticket-id ticket-data),
                                checked-in: true
                            }
                        )
                        (ok true)
                    )
            )
            err-ticket-not-found
        )
        err-owner-only
    )
)

;; Owner functions
(define-public (update-ticket-price (new-price uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set ticket-price new-price)
            (ok true)
        )
        err-owner-only
    )
)

;; Read only functions
(define-read-only (get-ticket-info (attendee principal))
    (map-get? tickets attendee)
)

(define-read-only (get-ticket-price)
    (ok (var-get ticket-price))
)

(define-read-only (get-tickets-remaining)
    (ok (- (var-get total-tickets) (var-get tickets-sold)))
)
