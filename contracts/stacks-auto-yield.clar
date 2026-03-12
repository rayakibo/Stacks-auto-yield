;; Stacks-Auto-Yield: Fixed Yield Vault Contract

;; Define the yield strategy trait
(define-trait yield-strategy-trait (
    (harvest () (response uint uint))
))

(define-constant ADMIN tx-sender)
(define-constant contract-owner tx-sender)

(define-data-var total-deposits uint u0)
(define-data-var reward-pool uint u0)
(define-data-var strategy-contract (optional principal) none)

(define-map user-balances { user: principal } uint)

;; -------------------------------
;; Deposit STX into Yield Vault
;; -------------------------------
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) (err u100))
    ;; FIXED: Corrected match syntax (removed parentheses around ok/err branch names)
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success-val (let ((current-balance (default-to u0 (map-get? user-balances { user: tx-sender }))))
                    (map-set user-balances { user: tx-sender } (+ current-balance amount))
                    (var-set total-deposits (+ (var-get total-deposits) amount))
                    (ok true))
      error-val (err error-val)
    )
  )
)

;; -------------------------------
;; Withdraw STX
;; -------------------------------
(define-public (withdraw (amount uint))
  (let ((balance (default-to u0 (map-get? user-balances { user: tx-sender }))))
    (begin
      (asserts! (> amount u0) (err u107))
      (asserts! (>= balance amount) (err u102))
      ;; FIXED: Replaced '_' with 'success' (Clarity doesn't support wildcards)
      (match (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender))
        success (begin
                  (map-set user-balances { user: tx-sender } (- balance amount))
                  (var-set total-deposits (- (var-get total-deposits) amount))
                  (ok true))
        error (err error)
      )
    )
  )
)

;; -------------------------------
;; Auto-Compounding Function
;; -------------------------------
;; FIXED: Strategy calls require passing the contract as a trait parameter
(define-public (auto-compound (strategy <yield-strategy-trait>))
  (let ((stored-strategy (unwrap! (var-get strategy-contract) (err u105))))
    (begin
      ;; Security check: Ensure provided trait matches the stored strategy address
      (asserts! (is-eq (contract-of strategy) stored-strategy) (err u106))
      
      (match (contract-call? strategy harvest)
        reward (begin
                (var-set reward-pool (+ (var-get reward-pool) reward))
                (ok true))
        error (err error))
    )
  )
)

;; ------------------------------- 
;; Set Yield Strategy Contract (Admin Only)
;; -------------------------------
(define-public (set-strategy (new-strategy <yield-strategy-trait>))
  (begin
    (asserts! (is-eq tx-sender ADMIN) (err u104))
    ;; Call harvest to ensure it works before setting it
    (try! (contract-call? new-strategy harvest))
    (var-set strategy-contract (some (contract-of new-strategy)))
    (ok true)
  )
)

;; -------------------------------
;; Read-Only Functions
;; -------------------------------

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances { user: user }))
)

(define-read-only (get-total-deposits)
  (var-get total-deposits)
)

(define-read-only (get-strategy)
  (var-get strategy-contract)
)

(define-read-only (get-reward-pool)
  (var-get reward-pool)
)