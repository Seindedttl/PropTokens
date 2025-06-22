;; Tokenized Real Estate Marketplace
;; A smart contract for tokenizing real-world assets (real estate) and enabling fractional ownership
;; through secure trading, verification, and governance mechanisms

;; ===== CONSTANTS =====

;; Error codes for various failure scenarios
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ASSET-NOT-VERIFIED (err u104))
(define-constant ERR-ASSET-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-PRICE (err u106))
(define-constant ERR-LISTING-NOT-FOUND (err u107))
(define-constant ERR-CANNOT-BUY-OWN-LISTING (err u108))

;; Contract owner for administrative functions
(define-constant CONTRACT-OWNER tx-sender)

;; Minimum token amount for listings (prevents spam)
(define-constant MIN-LISTING-AMOUNT u1)

;; ===== DATA MAPS AND VARS =====

;; Asset registry: stores metadata for each tokenized real estate asset
(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    total-supply: uint,
    verified: bool,
    property-address: (string-ascii 256),
    property-type: (string-ascii 64),
    valuation: uint,
    created-at: uint
  }
)

;; Token balances: tracks fractional ownership of each asset
(define-map token-balances
  { asset-id: uint, holder: principal }
  { balance: uint }
)

;; Active marketplace listings for asset tokens
(define-map listings
  { listing-id: uint }
  {
    seller: principal,
    asset-id: uint,
    amount: uint,
    price-per-token: uint,
    active: bool,
    created-at: uint
  }
)

;; Authorized verifiers who can validate real-world assets
(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Global counters for unique IDs
(define-data-var next-asset-id uint u1)
(define-data-var next-listing-id uint u1)

;; Variable to store current holder for portfolio calculations
(define-data-var current-portfolio-holder principal 'SP000000000000000000002Q6VF78)

;; ===== PRIVATE FUNCTIONS =====

;; Internal function to validate asset existence and verification status
(define-private (validate-asset (asset-id uint))
  (match (map-get? assets { asset-id: asset-id })
    asset-data (if (get verified asset-data)
                  (ok asset-data)
                  ERR-ASSET-NOT-VERIFIED)
    ERR-ASSET-NOT-FOUND
  )
)

;; Internal function to get token balance with default of 0
(define-private (get-balance-or-default (asset-id uint) (holder principal))
  (default-to u0 (get balance (map-get? token-balances { asset-id: asset-id, holder: holder })))
)

;; Internal function to update token balances safely
(define-private (update-balance (asset-id uint) (holder principal) (new-balance uint))
  (map-set token-balances
    { asset-id: asset-id, holder: holder }
    { balance: new-balance }
  )
)

;; Helper function to calculate value for a single asset for a specific holder
(define-private (calculate-asset-value-for-holder (asset-id uint) (holder principal))
  (let ((balance (get-balance-or-default asset-id holder)))
    (match (map-get? assets { asset-id: asset-id })
      asset-data (if (> balance u0)
                    (/ (* balance (get valuation asset-data)) (get total-supply asset-data))
                    u0)
      u0
    )
  )
)

;; Helper function to get detailed holding information for a specific holder
(define-private (get-detailed-holding (asset-id uint) (holder principal))
  (let ((balance (get-balance-or-default asset-id holder)))
    (match (map-get? assets { asset-id: asset-id })
      asset-data {
        asset-id: asset-id,
        balance: balance,
        ownership-percentage: (if (> balance u0) 
                               (/ (* balance u10000) (get total-supply asset-data)) 
                               u0),
        estimated-value: (if (> balance u0)
                          (/ (* balance (get valuation asset-data)) (get total-supply asset-data))
                          u0),
        property-type: (get property-type asset-data),
        verified: (get verified asset-data)
      }
      {
        asset-id: asset-id,
        balance: u0,
        ownership-percentage: u0,
        estimated-value: u0,
        property-type: "",
        verified: false
      }
    )
  )
)

;; Helper function to sum up portfolio values
(define-private (sum-values (values (list 50 uint)))
  (fold + values u0)
)

;; Helper function to filter positive values
(define-private (is-positive (val uint))
  (> val u0)
)

;; Helper function to get max value
(define-private (get-max (a uint) (b uint))
  (if (> a b) a b)
)

;; Helper function to get min value  
(define-private (get-min (a uint) (b uint))
  (if (< a b) a b)
)

;; Helper function for map - calculates asset value using current holder
(define-private (calculate-single-asset-value (asset-id uint))
  (calculate-asset-value-for-holder asset-id (var-get current-portfolio-holder))
)

;; Helper function for map - gets detailed holding using current holder
(define-private (get-single-detailed-holding (asset-id uint))
  (get-detailed-holding asset-id (var-get current-portfolio-holder))
)

;; ===== PUBLIC FUNCTIONS =====

;; Create a new tokenized real estate asset (only contract owner initially)
(define-public (create-asset (total-supply uint) (property-address (string-ascii 256)) 
                           (property-type (string-ascii 64)) (valuation uint))
  (let ((asset-id (var-get next-asset-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> total-supply u0) ERR-INVALID-AMOUNT)
    (asserts! (> valuation u0) ERR-INVALID-PRICE)
    
    ;; Create asset record
    (map-set assets
      { asset-id: asset-id }
      {
        owner: tx-sender,
        total-supply: total-supply,
        verified: false,
        property-address: property-address,
        property-type: property-type,
        valuation: valuation,
        created-at: block-height
      }
    )
    
    ;; Assign all tokens to creator initially
    (update-balance asset-id tx-sender total-supply)
    
    ;; Increment asset counter
    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

;; Verify an asset (only authorized verifiers)
(define-public (verify-asset (asset-id uint))
  (let ((verifier-status (default-to false (get authorized (map-get? authorized-verifiers { verifier: tx-sender })))))
    (asserts! verifier-status ERR-NOT-AUTHORIZED)
    
    (match (map-get? assets { asset-id: asset-id })
      asset-data (begin
                   (map-set assets
                     { asset-id: asset-id }
                     (merge asset-data { verified: true })
                   )
                   (ok true))
      ERR-ASSET-NOT-FOUND
    )
  )
)

;; Add authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-verifiers { verifier: verifier } { authorized: true })
    (ok true)
  )
)

;; Create a marketplace listing for asset tokens
(define-public (create-listing (asset-id uint) (amount uint) (price-per-token uint))
  (let ((listing-id (var-get next-listing-id))
        (seller-balance (get-balance-or-default asset-id tx-sender)))
    
    ;; Validate inputs and asset
    (try! (validate-asset asset-id))
    (asserts! (>= amount MIN-LISTING-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (> price-per-token u0) ERR-INVALID-PRICE)
    (asserts! (>= seller-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Create listing
    (map-set listings
      { listing-id: listing-id }
      {
        seller: tx-sender,
        asset-id: asset-id,
        amount: amount,
        price-per-token: price-per-token,
        active: true,
        created-at: block-height
      }
    )
    
    ;; Increment listing counter
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

;; Purchase tokens from a marketplace listing
(define-public (buy-tokens (listing-id uint) (amount uint))
  (match (map-get? listings { listing-id: listing-id })
    listing-data
    (let ((seller (get seller listing-data))
          (asset-id (get asset-id listing-data))
          (available-amount (get amount listing-data))
          (price-per-token (get price-per-token listing-data))
          (total-cost (* amount price-per-token))
          (buyer-balance (get-balance-or-default asset-id tx-sender))
          (seller-balance (get-balance-or-default asset-id seller)))
      
      ;; Validation checks
      (asserts! (get active listing-data) ERR-LISTING-NOT-FOUND)
      (asserts! (not (is-eq tx-sender seller)) ERR-CANNOT-BUY-OWN-LISTING)
      (asserts! (<= amount available-amount) ERR-INVALID-AMOUNT)
      (asserts! (>= seller-balance amount) ERR-INSUFFICIENT-BALANCE)
      
      ;; Transfer STX payment to seller
      (try! (stx-transfer? total-cost tx-sender seller))
      
      ;; Update token balances
      (update-balance asset-id tx-sender (+ buyer-balance amount))
      (update-balance asset-id seller (- seller-balance amount))
      
      ;; Update or close listing
      (if (is-eq amount available-amount)
        ;; Close listing if fully purchased
        (map-set listings
          { listing-id: listing-id }
          (merge listing-data { active: false, amount: u0 }))
        ;; Reduce listing amount
        (map-set listings
          { listing-id: listing-id }
          (merge listing-data { amount: (- available-amount amount) }))
      )
      
      (ok true)
    )
    ERR-LISTING-NOT-FOUND
  )
)

;; Get asset information
(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

;; Get token balance for a holder
(define-read-only (get-token-balance (asset-id uint) (holder principal))
  (ok (get-balance-or-default asset-id holder))
)

;; Get listing information
(define-read-only (get-listing (listing-id uint))
  (map-get? listings { listing-id: listing-id })
)

;; Advanced portfolio analytics function for asset holders
(define-public (calculate-portfolio-value (holder principal) (asset-ids (list 50 uint)))
  (begin
    ;; Set the current holder for the helper functions to use
    (var-set current-portfolio-holder holder)
    
    (let ((portfolio-values (map calculate-single-asset-value asset-ids))
          (total-value (sum-values portfolio-values))
          (asset-count (len asset-ids))
          (holdings (map get-single-detailed-holding asset-ids))
          (positive-values (filter is-positive portfolio-values))
          (positive-count (len positive-values)))
      (ok {
        total-value: total-value,
        asset-count: asset-count,
        average-value: (if (> asset-count u0) (/ total-value asset-count) u0),
        holdings: holdings,
        portfolio-diversity: (if (> asset-count u0) 
                              (/ (* positive-count u100) asset-count)
                              u0),
        largest-holding: (fold get-max portfolio-values u0),
        smallest-holding: (if (> positive-count u0)
                            (fold get-min positive-values u999999999)
                            u0)
      })
    )
  )
)


