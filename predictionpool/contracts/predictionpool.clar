;; Prediction Pool - Decentralized Prediction Markets with Automated Settlement
;; A production-ready smart contract for creating and trading prediction markets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-not-found (err u501))
(define-constant err-unauthorized (err u502))
(define-constant err-invalid-amount (err u503))
(define-constant err-market-closed (err u504))
(define-constant err-market-active (err u505))
(define-constant err-already-resolved (err u506))
(define-constant err-not-resolved (err u507))
(define-constant err-already-claimed (err u508))
(define-constant err-invalid-outcome (err u509))
(define-constant err-deadline-passed (err u510))
(define-constant err-insufficient-liquidity (err u511))
(define-constant err-invalid-price (err u512))

;; Platform fee (2% = 200 basis points)
(define-constant platform-fee-bp u200)
(define-constant basis-points u10000)

;; Price precision (multiply by 100 for 2 decimal places)
(define-constant price-precision u100)
(define-constant min-bet-amount u1000000)

;; Data Variables
(define-data-var market-nonce uint u0)
(define-data-var total-markets uint u0)
(define-data-var total-volume uint u0)
(define-data-var total-bets uint u0)
(define-data-var platform-treasury uint u0)

;; Market Structure
(define-map markets
    uint
    {
        creator: principal,
        question: (string-utf8 200),
        description: (string-utf8 500),
        resolution-source: (string-utf8 200),
        deadline: uint,
        resolution-time: uint,
        category: (string-ascii 30),
        yes-pool: uint,
        no-pool: uint,
        total-volume: uint,
        status: (string-ascii 20),
        outcome: (optional bool),
        created-at: uint,
        resolved-at: (optional uint),
        resolver: (optional principal)
    }
)

;; Position tracking
(define-map positions
    { market-id: uint, user: principal }
    {
        yes-amount: uint,
        no-amount: uint,
        yes-shares: uint,
        no-shares: uint,
        claimed: bool,
        total-invested: uint
    }
)

;; Market statistics
(define-map market-stats
    uint
    {
        total-participants: uint,
        yes-bettors: uint,
        no-bettors: uint,
        largest-position: uint,
        last-trade-price: uint
    }
)

;; User participation tracking
(define-map user-markets
    { user: principal, index: uint }
    uint
)

(define-map user-market-count
    principal
    uint
)

;; Read-Only Functions

(define-read-only (get-market (market-id uint))
    (ok (map-get? markets market-id))
)

(define-read-only (get-position (market-id uint) (user principal))
    (ok (map-get? positions { market-id: market-id, user: user }))
)

(define-read-only (get-market-stats (market-id uint))
    (ok (map-get? market-stats market-id))
)

(define-read-only (get-platform-stats)
    (ok {
        total-markets: (var-get total-markets),
        total-volume: (var-get total-volume),
        total-bets: (var-get total-bets),
        platform-treasury: (var-get platform-treasury)
    })
)

(define-read-only (calculate-yes-price (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (yes-pool (get yes-pool market))
        (no-pool (get no-pool market))
        (total-pool (+ yes-pool no-pool))
    )
        (if (is-eq total-pool u0)
            (ok u50)
            (ok (/ (* yes-pool price-precision) total-pool))
        )
    )
)

(define-read-only (calculate-no-price (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (yes-pool (get yes-pool market))
        (no-pool (get no-pool market))
        (total-pool (+ yes-pool no-pool))
    )
        (if (is-eq total-pool u0)
            (ok u50)
            (ok (/ (* no-pool price-precision) total-pool))
        )
    )
)

(define-read-only (calculate-potential-payout (market-id uint) (user principal))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (position (unwrap! (map-get? positions { market-id: market-id, user: user }) err-not-found))
        (outcome (get outcome market))
        (yes-pool (get yes-pool market))
        (no-pool (get no-pool market))
        (total-pool (+ yes-pool no-pool))
    )
        (match outcome
            result
            (if result
                ;; YES won - calculate YES payout
                (if (> (get yes-amount position) u0)
                    (ok (/ (* (get yes-amount position) total-pool) yes-pool))
                    (ok u0)
                )
                ;; NO won - calculate NO payout
                (if (> (get no-amount position) u0)
                    (ok (/ (* (get no-amount position) total-pool) no-pool))
                    (ok u0)
                )
            )
            err-not-resolved
        )
    )
)

(define-read-only (get-user-market-count (user principal))
    (ok (default-to u0 (map-get? user-market-count user)))
)

(define-read-only (get-user-market-id (user principal) (index uint))
    (ok (map-get? user-markets { user: user, index: index }))
)

;; Private helper functions

(define-private (add-to-user-markets (user principal) (market-id uint))
    (let (
        (current-count (default-to u0 (map-get? user-market-count user)))
    )
        (map-set user-markets
            { user: user, index: current-count }
            market-id
        )
        (map-set user-market-count user (+ current-count u1))
    )
)

(define-private (update-market-stats-for-bet 
    (market-id uint) 
    (is-new-participant bool)
    (bet-amount uint)
    (current-price uint))
    (let (
        (stats (default-to 
            { total-participants: u0, yes-bettors: u0, no-bettors: u0, largest-position: u0, last-trade-price: u50 }
            (map-get? market-stats market-id)))
    )
        (map-set market-stats market-id
            (merge stats {
                total-participants: (if is-new-participant 
                    (+ (get total-participants stats) u1)
                    (get total-participants stats)),
                largest-position: (if (> bet-amount (get largest-position stats))
                    bet-amount
                    (get largest-position stats)),
                last-trade-price: current-price
            })
        )
    )
)

;; Public Functions

;; Create a new prediction market
(define-public (create-market
    (question (string-utf8 200))
    (description (string-utf8 500))
    (resolution-source (string-utf8 200))
    (deadline-blocks uint)
    (resolution-blocks uint)
    (category (string-ascii 30)))
    (let (
        (market-id (+ (var-get market-nonce) u1))
        (deadline (+ stacks-block-height deadline-blocks))
        (resolution-time (+ deadline resolution-blocks))
    )
        (asserts! (> deadline-blocks u0) err-invalid-amount)
        (asserts! (> resolution-blocks u0) err-invalid-amount)
        (asserts! (> (len question) u0) err-invalid-amount)
        
        (map-set markets market-id {
            creator: tx-sender,
            question: question,
            description: description,
            resolution-source: resolution-source,
            deadline: deadline,
            resolution-time: resolution-time,
            category: category,
            yes-pool: u0,
            no-pool: u0,
            total-volume: u0,
            status: "active",
            outcome: none,
            created-at: stacks-block-height,
            resolved-at: none,
            resolver: none
        })
        
        (map-set market-stats market-id {
            total-participants: u0,
            yes-bettors: u0,
            no-bettors: u0,
            largest-position: u0,
            last-trade-price: u50
        })
        
        (var-set market-nonce market-id)
        (var-set total-markets (+ (var-get total-markets) u1))
        
        (ok market-id)
    )
)

;; Place a bet on YES outcome
(define-public (bet-yes (market-id uint) (amount uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (existing-position (map-get? positions { market-id: market-id, user: tx-sender }))
        (is-new-participant (is-none existing-position))
        (current-position (default-to 
            { yes-amount: u0, no-amount: u0, yes-shares: u0, no-shares: u0, claimed: false, total-invested: u0 }
            existing-position))
        (stats (unwrap! (map-get? market-stats market-id) err-not-found))
        (yes-price (unwrap! (calculate-yes-price market-id) err-invalid-price))
    )
        (asserts! (>= amount min-bet-amount) err-invalid-amount)
        (asserts! (is-eq (get status market) "active") err-market-closed)
        (asserts! (<= stacks-block-height (get deadline market)) err-deadline-passed)
        
        ;; Transfer bet amount to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update position
        (map-set positions
            { market-id: market-id, user: tx-sender }
            {
                yes-amount: (+ (get yes-amount current-position) amount),
                no-amount: (get no-amount current-position),
                yes-shares: (+ (get yes-shares current-position) amount),
                no-shares: (get no-shares current-position),
                claimed: false,
                total-invested: (+ (get total-invested current-position) amount)
            }
        )
        
        ;; Update market pools
        (map-set markets market-id
            (merge market {
                yes-pool: (+ (get yes-pool market) amount),
                total-volume: (+ (get total-volume market) amount)
            })
        )
        
        ;; Update statistics
        (if is-new-participant
            (begin
                (add-to-user-markets tx-sender market-id)
                (map-set market-stats market-id
                    (merge stats {
                        yes-bettors: (+ (get yes-bettors stats) u1)
                    })
                )
            )
            true
        )
        
        (update-market-stats-for-bet market-id is-new-participant amount yes-price)
        
        ;; Update global stats
        (var-set total-volume (+ (var-get total-volume) amount))
        (var-set total-bets (+ (var-get total-bets) u1))
        
        (ok true)
    )
)

;; Place a bet on NO outcome
(define-public (bet-no (market-id uint) (amount uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (existing-position (map-get? positions { market-id: market-id, user: tx-sender }))
        (is-new-participant (is-none existing-position))
        (current-position (default-to 
            { yes-amount: u0, no-amount: u0, yes-shares: u0, no-shares: u0, claimed: false, total-invested: u0 }
            existing-position))
        (stats (unwrap! (map-get? market-stats market-id) err-not-found))
        (no-price (unwrap! (calculate-no-price market-id) err-invalid-price))
    )
        (asserts! (>= amount min-bet-amount) err-invalid-amount)
        (asserts! (is-eq (get status market) "active") err-market-closed)
        (asserts! (<= stacks-block-height (get deadline market)) err-deadline-passed)
        
        ;; Transfer bet amount to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update position
        (map-set positions
            { market-id: market-id, user: tx-sender }
            {
                yes-amount: (get yes-amount current-position),
                no-amount: (+ (get no-amount current-position) amount),
                yes-shares: (get yes-shares current-position),
                no-shares: (+ (get no-shares current-position) amount),
                claimed: false,
                total-invested: (+ (get total-invested current-position) amount)
            }
        )
        
        ;; Update market pools
        (map-set markets market-id
            (merge market {
                no-pool: (+ (get no-pool market) amount),
                total-volume: (+ (get total-volume market) amount)
            })
        )
        
        ;; Update statistics
        (if is-new-participant
            (begin
                (add-to-user-markets tx-sender market-id)
                (map-set market-stats market-id
                    (merge stats {
                        no-bettors: (+ (get no-bettors stats) u1)
                    })
                )
            )
            true
        )
        
        (update-market-stats-for-bet market-id is-new-participant amount no-price)
        
        ;; Update global stats
        (var-set total-volume (+ (var-get total-volume) amount))
        (var-set total-bets (+ (var-get total-bets) u1))
        
        (ok true)
    )
)

;; Resolve market outcome
(define-public (resolve-market (market-id uint) (outcome bool))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get creator market)) err-unauthorized)
        (asserts! (is-eq (get status market) "active") err-already-resolved)
        (asserts! (> stacks-block-height (get deadline market)) err-market-active)
        
        (map-set markets market-id
            (merge market {
                status: "resolved",
                outcome: (some outcome),
                resolved-at: (some stacks-block-height),
                resolver: (some tx-sender)
            })
        )
        
        (ok true)
    )
)

;; Claim winnings
(define-public (claim-winnings (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (position (unwrap! (map-get? positions { market-id: market-id, user: tx-sender }) err-not-found))
        (outcome (unwrap! (get outcome market) err-not-resolved))
        (yes-pool (get yes-pool market))
        (no-pool (get no-pool market))
        (total-pool (+ yes-pool no-pool))
        (platform-fee (/ (* total-pool platform-fee-bp) basis-points))
        (prize-pool (- total-pool platform-fee))
    )
        (asserts! (is-eq (get status market) "resolved") err-not-resolved)
        (asserts! (not (get claimed position)) err-already-claimed)
        
        (let (
            (payout (if outcome
                ;; YES won
                (if (> yes-pool u0)
                    (/ (* (get yes-amount position) prize-pool) yes-pool)
                    u0
                )
                ;; NO won
                (if (> no-pool u0)
                    (/ (* (get no-amount position) prize-pool) no-pool)
                    u0
                )
            ))
        )
            (asserts! (> payout u0) err-invalid-amount)
            
            ;; Transfer payout
            (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
            
            ;; Mark as claimed
            (map-set positions
                { market-id: market-id, user: tx-sender }
                (merge position { claimed: true })
            )
            
            ;; Update platform treasury
            (var-set platform-treasury (+ (var-get platform-treasury) (/ platform-fee (if outcome
                (get yes-bettors (default-to { total-participants: u1, yes-bettors: u1, no-bettors: u1, largest-position: u0, last-trade-price: u50 }
                    (map-get? market-stats market-id)))
                (get no-bettors (default-to { total-participants: u1, yes-bettors: u1, no-bettors: u1, largest-position: u0, last-trade-price: u50 }
                    (map-get? market-stats market-id)))
            ))))
            
            (ok payout)
        )
    )
)

;; Cancel market (creator only, before any bets)
(define-public (cancel-market (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get creator market)) err-unauthorized)
        (asserts! (is-eq (get status market) "active") err-already-resolved)
        (asserts! (is-eq (get yes-pool market) u0) err-invalid-amount)
        (asserts! (is-eq (get no-pool market) u0) err-invalid-amount)
        
        (map-set markets market-id
            (merge market { status: "cancelled" })
        )
        
        (ok true)
    )
)

;; Emergency withdrawal for unresolved markets (after resolution deadline + 30 days)
(define-public (emergency-withdraw (market-id uint))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (position (unwrap! (map-get? positions { market-id: market-id, user: tx-sender }) err-not-found))
        (resolution-deadline (+ (get resolution-time market) u4320))
    )
        (asserts! (is-eq (get status market) "active") err-already-resolved)
        (asserts! (> stacks-block-height resolution-deadline) err-market-active)
        (asserts! (not (get claimed position)) err-already-claimed)
        
        (let (
            (refund-amount (+ (get yes-amount position) (get no-amount position)))
        )
            (asserts! (> refund-amount u0) err-invalid-amount)
            
            ;; Transfer refund
            (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
            
            ;; Mark as claimed
            (map-set positions
                { market-id: market-id, user: tx-sender }
                (merge position { claimed: true })
            )
            
            (ok refund-amount)
        )
    )
)

;; Admin: Withdraw platform fees
(define-public (withdraw-platform-fees (amount uint))
    (let (
        (treasury (var-get platform-treasury))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount treasury) err-invalid-amount)
        (asserts! (> amount u0) err-invalid-amount)
        
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (var-set platform-treasury (- treasury amount))
        
        (ok true)
    )
)

;; Admin: Emergency resolve market
(define-public (admin-resolve-market (market-id uint) (outcome bool))
    (let (
        (market (unwrap! (map-get? markets market-id) err-not-found))
        (resolution-deadline (+ (get resolution-time market) u2160))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status market) "active") err-already-resolved)
        (asserts! (> stacks-block-height resolution-deadline) err-market-active)
        
        (map-set markets market-id
            (merge market {
                status: "resolved",
                outcome: (some outcome),
                resolved-at: (some stacks-block-height),
                resolver: (some tx-sender)
            })
        )
        
        (ok true)
    )
)