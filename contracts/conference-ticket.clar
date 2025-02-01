;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-sold-out (err u101)) 
(define-constant err-invalid-payment (err u102))
(define-constant err-ticket-not-found (err u103))
(define-constant err-already-checked-in (err u104))
(define-constant err-refund-window-expired (err u105))
(define-constant err-already-refunded (err u106))

;; Define data variables
(define-data-var ticket-price uint u100)
(define-data-var total-tickets uint u1000)
(define-data-var tickets-sold uint u0)
(define-data-var refund-window uint u72) ;; Hours after purchase that refund is allowed

;; Define data maps
(define-map tickets principal 
    {
        ticket-id: uint,
        checked-in: bool,
        purchase-height: uint,
        refunded: bool
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
                    checked-in: false,
                    purchase-height: block-height,
                    refunded: false
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
                    (if (get refunded ticket-data)
                        (err u107)
                        (begin
                            (map-set tickets attendee 
                                {
                                    ticket-id: (get ticket-id ticket-data),
                                    checked-in: true,
                                    purchase-height: (get purchase-height ticket-data),
                                    refunded: false
                                }
                            )
                            (ok true)
                        )
                    )
            )
            err-ticket-not-found
        )
        err-owner-only
    )
)

;; Request refund within refund window
(define-public (request-refund)
    (match (map-get? tickets tx-sender)
        ticket-data (
            (let (
                (blocks-since-purchase (- block-height (get purchase-height ticket-data)))
                (refund-blocks (* (var-get refund-window) u144)) ;; ~10 mins per block = 144 blocks per day
            )
            (if (> blocks-since-purchase refund-blocks)
                err-refund-window-expired
                (if (get refunded ticket-data)
                    err-already-refunded
                    (if (get checked-in ticket-data)
                        (err u108)
                        (begin
                            (try! (as-contract (stx-transfer? (var-get ticket-price) contract-owner tx-sender)))
                            (map-set tickets tx-sender
                                {
                                    ticket-id: (get ticket-id ticket-data),
                                    checked-in: false,
                                    purchase-height: (get purchase-height ticket-data),
                                    refunded: true
                                }
                            )
                            (var-set tickets-sold (- (var-get tickets-sold) u1))
                            (ok true)
                        )
                    )
                )
            ))
        )
        err-ticket-not-found
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

(define-public (update-refund-window (hours uint))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set refund-window hours)
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

(define-read-only (get-refund-window)
    (ok (var-get refund-window))
)
