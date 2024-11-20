;; IntellectualAssetToken (IAT)
;; A smart contract for tokenizing intellectual property assets

(define-fungible-token ip-tokens)

;; Storage for contract metadata and asset details
(define-data-var contract-owner principal tx-sender)
(define-data-var total-asset-count uint u0)

;; Storing asset details with enhanced ownership tracking
(define-map asset-details 
    {asset-id: uint}
    {
        owner: principal,
        initial-valuation: uint,
        current-valuation: uint,
        total-tokens: uint,
        token-holders: (list 10 principal),
        transferable: bool
    }
)

;; Token holder tracking
(define-map token-balances 
    {asset-id: uint, holder: principal}
    uint
)

;; Input validation functions
(define-private (is-valid-uint (value uint))
    (> value u0)
)

;; Mint tokens for IP ownership
(define-public (register-ip-ownership 
    (asset-id uint) 
    (initial-valuation uint)
    (token-amount uint)
)
    (begin
        ;; Validate inputs
        (asserts! (is-valid-uint asset-id) (err u400))
        (asserts! (is-valid-uint initial-valuation) (err u400))
        (asserts! (is-valid-uint token-amount) (err u400))
        
        ;; Increment total asset count
        (var-set total-asset-count (+ (var-get total-asset-count) u1))
        
        ;; Store asset details
        (map-set asset-details 
            {asset-id: asset-id}
            {
                owner: tx-sender,
                initial-valuation: initial-valuation,
                current-valuation: initial-valuation,
                total-tokens: token-amount,
                token-holders: (list tx-sender),
                transferable: true
            }
        )
        
        ;; Mint tokens and track initial holder balance
        (match (ft-mint? ip-tokens token-amount tx-sender)
            success 
            (begin
                (map-set token-balances 
                    {asset-id: asset-id, holder: tx-sender} 
                    token-amount
                )
                (ok success)
            )
            error (err u500)
        )
    )
)

;; Transfer fractional IP tokens
(define-public (transfer-ip-tokens 
    (asset-id uint)
    (amount uint)
    (recipient principal)
)
    (let 
        (
            (asset (unwrap! (map-get? asset-details {asset-id: asset-id}) (err u404)))
            (sender-balance (default-to u0 (map-get? token-balances {asset-id: asset-id, holder: tx-sender})))
            (recipient-balance (default-to u0 (map-get? token-balances {asset-id: asset-id, holder: recipient})))
            (recipient-tokens (map-get? token-balances {asset-id: asset-id, holder: recipient}))
        )
        ;; Validate transfer conditions
        (asserts! (is-valid-uint amount) (err u400))
        (asserts! (<= amount sender-balance) (err u403))
        (asserts! (get transferable asset) (err u403))
        
        ;; Perform token transfer
        (match (ft-transfer? ip-tokens amount tx-sender recipient)
            success 
            (begin
                ;; Update sender and recipient balances
                (map-set token-balances 
                    {asset-id: asset-id, holder: tx-sender} 
                    (- sender-balance amount)
                )
                (map-set token-balances 
                    {asset-id: asset-id, holder: recipient} 
                    (+ (default-to u0 recipient-tokens) amount)
                )
                
                ;; Update token holders list if needed
                (if (is-some recipient-tokens)
                    true
                    (map-set asset-details 
                        {asset-id: asset-id}
                        (merge asset {
                            token-holders: (unwrap-panic 
                                (as-max-len? 
                                    (append (get token-holders asset) recipient) 
                                    u10
                                ))
                        })
                    )
                )
                
                (ok success)
            )
            error (err u500)
        )
    )
)

;; Update IP asset valuation
(define-public (update-asset-valuation 
    (asset-id uint)
    (new-valuation uint)
)
    (let 
        (
            (asset (unwrap! (map-get? asset-details {asset-id: asset-id}) (err u404)))
        )
        ;; Validate and restrict valuation updates
        (asserts! (is-valid-uint new-valuation) (err u400))
        (asserts! 
            (or 
                (is-eq tx-sender (get owner asset))
                (is-eq tx-sender (var-get contract-owner))
            ) 
            (err u403)
        )
        
        ;; Update asset valuation
        (map-set asset-details 
            {asset-id: asset-id}
            (merge asset {current-valuation: new-valuation})
        )
        
        (ok new-valuation)
    )
)

;; Get IP token balance
(define-read-only (get-token-balance 
    (asset-id uint)
    (holder principal)
)
    (default-to u0 (map-get? token-balances {asset-id: asset-id, holder: holder}))
)

;; Read asset details
(define-read-only (get-asset-details (asset-id uint))
    (map-get? asset-details {asset-id: asset-id})
)