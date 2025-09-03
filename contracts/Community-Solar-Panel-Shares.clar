(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-shares (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-panel-inactive (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-invalid-price (err u107))
(define-constant err-no-dividend-pool (err u108))

(define-data-var next-panel-id uint u1)
(define-data-var dividend-rate uint u10)
(define-data-var total-energy-produced uint u0)
(define-data-var total-rewards-distributed uint u0)

(define-map panels
    uint
    {
        owner: principal,
        location: (string-ascii 100),
        capacity: uint,
        installation-date: uint,
        total-shares: uint,
        available-shares: uint,
        energy-produced: uint,
        active: bool,
        share-price: uint,
    }
)

(define-map panel-shares
    {
        panel-id: uint,
        holder: principal,
    }
    {
        shares: uint,
        last-claim: uint,
    }
)

(define-map user-total-shares
    principal
    uint
)

(define-map share-offers
    {
        panel-id: uint,
        seller: principal,
    }
    {
        shares: uint,
        price-per-share: uint,
    }
)

(define-map energy-records
    {
        panel-id: uint,
        height: uint,
    }
    uint
)

(define-map dividend-pool
    uint
    uint
)

(define-map shareholder-registry
    uint
    (list 100 principal)
)

(define-public (register-panel
        (location (string-ascii 100))
        (capacity uint)
        (total-shares uint)
        (share-price uint)
    )
    (let ((panel-id (var-get next-panel-id)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> capacity u0) err-invalid-amount)
        (asserts! (> total-shares u0) err-invalid-amount)
        (asserts! (> share-price u0) err-invalid-price)
        (map-set panels panel-id {
            owner: tx-sender,
            location: location,
            capacity: capacity,
            installation-date: stacks-block-height,
            total-shares: total-shares,
            available-shares: total-shares,
            energy-produced: u0,
            active: true,
            share-price: share-price,
        })
        (var-set next-panel-id (+ panel-id u1))
        (ok panel-id)
    )
)

(define-public (buy-shares
        (panel-id uint)
        (shares-amount uint)
    )
    (let (
            (panel-data (unwrap! (map-get? panels panel-id) err-not-found))
            (total-cost (* shares-amount (get share-price panel-data)))
            (current-user-shares (default-to u0 (map-get? user-total-shares tx-sender)))
            (current-panel-shares (default-to {
                shares: u0,
                last-claim: u0,
            }
                (map-get? panel-shares {
                    panel-id: panel-id,
                    holder: tx-sender,
                })
            ))
        )
        (asserts! (get active panel-data) err-panel-inactive)
        (asserts! (>= (get available-shares panel-data) shares-amount)
            err-insufficient-shares
        )
        (asserts! (> shares-amount u0) err-invalid-amount)

        (try! (stx-transfer? total-cost tx-sender (get owner panel-data)))

        (map-set panels panel-id
            (merge panel-data { available-shares: (- (get available-shares panel-data) shares-amount) })
        )

        (map-set panel-shares {
            panel-id: panel-id,
            holder: tx-sender,
        } {
            shares: (+ (get shares current-panel-shares) shares-amount),
            last-claim: stacks-block-height,
        })

        (map-set user-total-shares tx-sender
            (+ current-user-shares shares-amount)
        )

        (let ((current-shareholders (default-to (list) (map-get? shareholder-registry panel-id))))
            (if (is-none (index-of? current-shareholders tx-sender))
                (map-set shareholder-registry panel-id
                    (unwrap!
                        (as-max-len? (append current-shareholders tx-sender) u100)
                        err-invalid-amount
                    ))
                true
            )
        )

        (ok shares-amount)
    )
)

(define-public (record-energy-production
        (panel-id uint)
        (energy-amount uint)
    )
    (let ((panel-data (unwrap! (map-get? panels panel-id) err-not-found)))
        (asserts! (is-eq tx-sender (get owner panel-data)) err-unauthorized)
        (asserts! (get active panel-data) err-panel-inactive)
        (asserts! (> energy-amount u0) err-invalid-amount)

        (map-set energy-records {
            panel-id: panel-id,
            height: stacks-block-height,
        }
            energy-amount
        )

        (map-set panels panel-id
            (merge panel-data { energy-produced: (+ (get energy-produced panel-data) energy-amount) })
        )

        (var-set total-energy-produced
            (+ (var-get total-energy-produced) energy-amount)
        )

        (let ((dividend-amount (/ (* energy-amount (var-get dividend-rate)) u100)))
            (if (> dividend-amount u0)
                (begin
                    (map-set dividend-pool panel-id
                        (+ (default-to u0 (map-get? dividend-pool panel-id))
                            dividend-amount
                        ))
                    (try! (distribute-dividends panel-id))
                )
                true
            )
        )

        (ok energy-amount)
    )
)

(define-public (claim-rewards (panel-id uint))
    (let (
            (panel-data (unwrap! (map-get? panels panel-id) err-not-found))
            (user-shares-data (unwrap!
                (map-get? panel-shares {
                    panel-id: panel-id,
                    holder: tx-sender,
                })
                err-not-found
            ))
            (user-shares (get shares user-shares-data))
            (total-shares (get total-shares panel-data))
            (panel-energy (get energy-produced panel-data))
            (reward-per-share (/ panel-energy total-shares))
            (user-reward (/ (* reward-per-share user-shares) u1000))
        )
        (asserts! (get active panel-data) err-panel-inactive)
        (asserts! (> user-shares u0) err-insufficient-shares)
        (asserts! (< (get last-claim user-shares-data) stacks-block-height)
            err-invalid-amount
        )

        (map-set panel-shares {
            panel-id: panel-id,
            holder: tx-sender,
        }
            (merge user-shares-data { last-claim: stacks-block-height })
        )

        (var-set total-rewards-distributed
            (+ (var-get total-rewards-distributed) user-reward)
        )

        (ok user-reward)
    )
)

(define-public (create-share-offer
        (panel-id uint)
        (shares-amount uint)
        (price-per-share uint)
    )
    (let (
            (user-shares-data (unwrap!
                (map-get? panel-shares {
                    panel-id: panel-id,
                    holder: tx-sender,
                })
                err-not-found
            ))
            (user-shares (get shares user-shares-data))
        )
        (asserts! (>= user-shares shares-amount) err-insufficient-shares)
        (asserts! (> shares-amount u0) err-invalid-amount)
        (asserts! (> price-per-share u0) err-invalid-price)

        (map-set share-offers {
            panel-id: panel-id,
            seller: tx-sender,
        } {
            shares: shares-amount,
            price-per-share: price-per-share,
        })

        (ok true)
    )
)

(define-public (accept-share-offer
        (panel-id uint)
        (seller principal)
        (shares-amount uint)
    )
    (let (
            (offer-data (unwrap!
                (map-get? share-offers {
                    panel-id: panel-id,
                    seller: seller,
                })
                err-not-found
            ))
            (seller-shares-data (unwrap!
                (map-get? panel-shares {
                    panel-id: panel-id,
                    holder: seller,
                })
                err-not-found
            ))
            (buyer-shares-data (default-to {
                shares: u0,
                last-claim: stacks-block-height,
            }
                (map-get? panel-shares {
                    panel-id: panel-id,
                    holder: tx-sender,
                })
            ))
            (total-cost (* shares-amount (get price-per-share offer-data)))
            (seller-total-shares (default-to u0 (map-get? user-total-shares seller)))
            (buyer-total-shares (default-to u0 (map-get? user-total-shares tx-sender)))
        )
        (asserts! (>= (get shares offer-data) shares-amount)
            err-insufficient-shares
        )
        (asserts! (>= (get shares seller-shares-data) shares-amount)
            err-insufficient-shares
        )
        (asserts! (> shares-amount u0) err-invalid-amount)

        (try! (stx-transfer? total-cost tx-sender seller))

        (map-set panel-shares {
            panel-id: panel-id,
            holder: seller,
        }
            (merge seller-shares-data { shares: (- (get shares seller-shares-data) shares-amount) })
        )

        (map-set panel-shares {
            panel-id: panel-id,
            holder: tx-sender,
        }
            (merge buyer-shares-data { shares: (+ (get shares buyer-shares-data) shares-amount) })
        )

        (map-set user-total-shares seller (- seller-total-shares shares-amount))
        (map-set user-total-shares tx-sender (+ buyer-total-shares shares-amount))

        (let ((current-shareholders (default-to (list) (map-get? shareholder-registry panel-id))))
            (if (is-none (index-of? current-shareholders tx-sender))
                (map-set shareholder-registry panel-id
                    (unwrap!
                        (as-max-len? (append current-shareholders tx-sender) u100)
                        err-invalid-amount
                    ))
                true
            )
        )

        (if (is-eq (get shares offer-data) shares-amount)
            (map-delete share-offers {
                panel-id: panel-id,
                seller: seller,
            })
            (map-set share-offers {
                panel-id: panel-id,
                seller: seller,
            }
                (merge offer-data { shares: (- (get shares offer-data) shares-amount) })
            )
        )

        (ok shares-amount)
    )
)

(define-public (cancel-share-offer (panel-id uint))
    (begin
        (asserts!
            (is-some (map-get? share-offers {
                panel-id: panel-id,
                seller: tx-sender,
            }))
            err-not-found
        )
        (map-delete share-offers {
            panel-id: panel-id,
            seller: tx-sender,
        })
        (ok true)
    )
)

(define-public (deactivate-panel (panel-id uint))
    (let ((panel-data (unwrap! (map-get? panels panel-id) err-not-found)))
        (asserts! (is-eq tx-sender (get owner panel-data)) err-unauthorized)
        (map-set panels panel-id (merge panel-data { active: false }))
        (ok true)
    )
)

(define-public (reactivate-panel (panel-id uint))
    (let ((panel-data (unwrap! (map-get? panels panel-id) err-not-found)))
        (asserts! (is-eq tx-sender (get owner panel-data)) err-unauthorized)
        (map-set panels panel-id (merge panel-data { active: true }))
        (ok true)
    )
)

(define-public (update-share-price
        (panel-id uint)
        (new-price uint)
    )
    (let ((panel-data (unwrap! (map-get? panels panel-id) err-not-found)))
        (asserts! (is-eq tx-sender (get owner panel-data)) err-unauthorized)
        (asserts! (> new-price u0) err-invalid-price)
        (map-set panels panel-id (merge panel-data { share-price: new-price }))
        (ok new-price)
    )
)

(define-read-only (get-panel-info (panel-id uint))
    (map-get? panels panel-id)
)

(define-read-only (get-user-panel-shares
        (panel-id uint)
        (user principal)
    )
    (map-get? panel-shares {
        panel-id: panel-id,
        holder: user,
    })
)

(define-read-only (get-user-total-shares (user principal))
    (default-to u0 (map-get? user-total-shares user))
)

(define-read-only (get-share-offer
        (panel-id uint)
        (seller principal)
    )
    (map-get? share-offers {
        panel-id: panel-id,
        seller: seller,
    })
)

(define-read-only (get-energy-record
        (panel-id uint)
        (height uint)
    )
    (map-get? energy-records {
        panel-id: panel-id,
        height: height,
    })
)

(define-read-only (get-contract-stats)
    {
        next-panel-id: (var-get next-panel-id),
        total-energy-produced: (var-get total-energy-produced),
        total-rewards-distributed: (var-get total-rewards-distributed),
    }
)

(define-read-only (calculate-potential-reward
        (panel-id uint)
        (user principal)
    )
    (let (
            (panel-data (unwrap! (map-get? panels panel-id) (err u0)))
            (user-shares-data (unwrap!
                (map-get? panel-shares {
                    panel-id: panel-id,
                    holder: user,
                })
                (err u0)
            ))
            (user-shares (get shares user-shares-data))
            (total-shares (get total-shares panel-data))
            (panel-energy (get energy-produced panel-data))
            (reward-per-share (/ panel-energy total-shares))
        )
        (ok (/ (* reward-per-share user-shares) u1000))
    )
)

(define-read-only (get-available-shares (panel-id uint))
    (match (map-get? panels panel-id)
        panel-data (ok (get available-shares panel-data))
        err-not-found
    )
)

(define-read-only (is-panel-active (panel-id uint))
    (match (map-get? panels panel-id)
        panel-data (ok (get active panel-data))
        err-not-found
    )
)

(define-private (distribute-dividends (panel-id uint))
    (let (
            (panel-data (unwrap! (map-get? panels panel-id) err-not-found))
            (shareholders (default-to (list) (map-get? shareholder-registry panel-id)))
            (pool-amount (default-to u0 (map-get? dividend-pool panel-id)))
            (total-shares (get total-shares panel-data))
        )
        (asserts! (> pool-amount u0) err-no-dividend-pool)
        (map-set dividend-pool panel-id u0)
        (fold distribute-to-shareholder shareholders {
            panel-id: panel-id,
            pool-amount: pool-amount,
            total-shares: total-shares,
            remaining-pool: pool-amount,
        })
        (ok true)
    )
)

(define-private (distribute-to-shareholder
        (shareholder principal)
        (context {
            panel-id: uint,
            pool-amount: uint,
            total-shares: uint,
            remaining-pool: uint,
        })
    )
    (let (
            (user-shares-data (default-to {
                shares: u0,
                last-claim: u0,
            }
                (map-get? panel-shares {
                    panel-id: (get panel-id context),
                    holder: shareholder,
                })
            ))
            (user-shares (get shares user-shares-data))
            (dividend (/ (* (get pool-amount context) user-shares)
                (get total-shares context)
            ))
        )
        (if (and (> user-shares u0) (> dividend u0))
            (begin
                (var-set total-rewards-distributed
                    (+ (var-get total-rewards-distributed) dividend)
                )
                context
            )
            context
        )
    )
)

(define-public (set-dividend-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u50) err-invalid-amount)
        (var-set dividend-rate new-rate)
        (ok new-rate)
    )
)

(define-read-only (get-dividend-rate)
    (var-get dividend-rate)
)

(define-read-only (get-dividend-pool (panel-id uint))
    (default-to u0 (map-get? dividend-pool panel-id))
)

(define-read-only (get-panel-shareholders (panel-id uint))
    (default-to (list) (map-get? shareholder-registry panel-id))
)
