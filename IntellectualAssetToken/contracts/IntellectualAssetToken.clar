;; IntellectualAssetToken (IAT)
;; A smart contract for tokenizing intellectual property assets

(define-fungible-token intellectual-asset-token)

;; Storage for contract metadata and asset details
(define-data-var contract-owner principal tx-sender)
(define-data-var total-asset-value uint u0)
(define-data-var royalty-rate uint u10) ;; Default 10% royalty rate

;; Storing asset details
(define-map asset-details 
    {asset-id: uint}
    {
        owner: principal,
        initial-valuation: uint,
        current-valuation: uint,
        total-tokens: uint
    }
)

;; Input validation functions
(define-private (is-valid-uint (value uint))
    (> value u0)
)

;; Validate asset ID
(define-private (is-valid-asset-id (asset-id uint))
    (match (map-get? asset-details {asset-id: asset-id})
        entry true
        false
    )
)

;; Mint tokens based on asset valuation
(define-public (mint-ip-tokens 
    (asset-id uint) 
    (initial-valuation uint)
    (token-amount uint)
)
    (begin
        ;; Validate inputs
        (asserts! (is-valid-uint asset-id) (err u400))
        (asserts! (is-valid-uint initial-valuation) (err u400))
        (asserts! (is-valid-uint token-amount) (err u400))
        (asserts! (not (is-valid-asset-id asset-id)) (err u409)) ;; Prevent duplicate asset IDs
        
        ;; Only contract owner can mint initial tokens
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
        
        ;; Store asset details with validated inputs
        (map-set asset-details 
            {asset-id: asset-id}
            {
                owner: tx-sender,
                initial-valuation: initial-valuation,
                current-valuation: initial-valuation,
                total-tokens: token-amount
            }
        )
        
        ;; Mint tokens to the owner with input validation
        (match (ft-mint? intellectual-asset-token token-amount tx-sender)
            success (ok success)
            error (err u500)
        )
    )
)

;; Update asset valuation
(define-public (update-asset-valuation 
    (asset-id uint)
    (new-valuation uint)
)
    (let 
        (
            (asset (unwrap! (map-get? asset-details {asset-id: asset-id}) (err u404)))
        )
        ;; Validate input
        (asserts! (is-valid-uint new-valuation) (err u400))
        
        ;; Only asset owner or contract owner can update valuation
        (asserts! 
            (or 
                (is-eq tx-sender (get owner asset))
                (is-eq tx-sender (var-get contract-owner))
            ) 
            (err u403)
        )
        
        ;; Update current valuation with validated input
        (map-set asset-details 
            {asset-id: asset-id}
            (merge asset {current-valuation: new-valuation})
        )
        
        (ok new-valuation)
    )
)

;; Distribute royalties based on token holdings
(define-public (distribute-royalties 
    (asset-id uint)
    (total-revenue uint)
)
    (let 
        (
            (asset (unwrap! (map-get? asset-details {asset-id: asset-id}) (err u404)))
            (royalty-amount (/ (* total-revenue (var-get royalty-rate)) u100))
        )
        ;; Validate inputs
        (asserts! (is-valid-uint asset-id) (err u400))
        (asserts! (is-valid-uint total-revenue) (err u400))
        
        ;; Distribute royalties proportionally to token holders
        ;; Note: Actual distribution mechanism would require more complex logic
        (ok royalty-amount)
    )
)

;; Transfer IP tokens
(define-public (transfer-ip-tokens 
    (amount uint)
    (recipient principal)
)
    (begin
        ;; Validate inputs
        (asserts! (is-valid-uint amount) (err u400))
        (asserts! (not (is-eq tx-sender recipient)) (err u403))
        
        ;; Transfer tokens
        (ft-transfer? intellectual-asset-token amount tx-sender recipient)
    )
)

;; Read-only functions to get asset information
(define-read-only (get-asset-details (asset-id uint))
    (map-get? asset-details {asset-id: asset-id})
)

;; Additional helper functions can be added as needed