;; SECURESTACK DIGITAL BANKING PLATFORM SMART CONTRACT
;; Only state-modifying functions that require gas fees and write to blockchain

;; ERROR CONSTANTS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-INVALID-TRANSACTION-AMOUNT (err u102))
(define-constant ERR-DAILY-WITHDRAWAL-LIMIT-EXCEEDED (err u103))
(define-constant ERR-BANKING-SYSTEM-OFFLINE (err u104))
(define-constant ERR-CUSTOMER-ACCOUNT-NOT-EXISTS (err u106))
(define-constant ERR-CUSTOMER-ACCOUNT-ALREADY-EXISTS (err u107))
(define-constant ERR-SELF-TRANSFER-NOT-ALLOWED (err u108))
(define-constant ERR-TRANSACTION-FEE-TOO-HIGH (err u109))
(define-constant ERR-LIMIT-BELOW-MINIMUM-THRESHOLD (err u110))
(define-constant ERR-LIMIT-EXCEEDS-MAXIMUM-THRESHOLD (err u111))
(define-constant ERR-CUSTOMER-ACCOUNT-IS-LOCKED (err u112))
(define-constant ERR-INVALID-SECURITY-CODE (err u113))
(define-constant ERR-MAX-UNLOCK-ATTEMPTS-REACHED (err u114))
(define-constant ERR-SECURITY-ATTEMPT-LIMIT-OUT-OF-BOUNDS (err u116))
(define-constant ERR-ACCOUNT-FREEZE-ACTIVE (err u118))
(define-constant ERR-MAINTENANCE-MODE-ACTIVE (err u119))
(define-constant ERR-INVALID-SECURITY-LEVEL (err u120))

;; SYSTEM CONFIGURATION CONSTANTS

(define-constant platform-administrator tx-sender)
(define-constant stx-to-micro-stx-multiplier u1000000)
(define-constant standard-processing-fee stx-to-micro-stx-multiplier)
(define-constant default-withdrawal-limit (* u1000 stx-to-micro-stx-multiplier))
(define-constant maximum-fee-cap (* u10 stx-to-micro-stx-multiplier))
(define-constant minimum-withdrawal-threshold stx-to-micro-stx-multiplier)
(define-constant maximum-withdrawal-threshold (* u10000 stx-to-micro-stx-multiplier))
(define-constant daily-block-count u144)
(define-constant minimum-security-attempts u1)
(define-constant maximum-security-attempts u10)
(define-constant standard-unlock-attempt-limit u3)
(define-constant minimum-deposit-requirement (* u1 stx-to-micro-stx-multiplier))
(define-constant minimum-withdrawal-requirement (* u1 stx-to-micro-stx-multiplier))
(define-constant minimum-transfer-requirement (* u1 stx-to-micro-stx-multiplier))
(define-constant single-transaction-limit (* u100000 stx-to-micro-stx-multiplier))
(define-constant empty-security-hash 0x0000000000000000000000000000000000000000000000000000000000000000)
(define-constant fee-calculation-basis u100)

;; GLOBAL STATE VARIABLES

(define-data-var system-operational-status bool true)
(define-data-var platform-maintenance-mode bool false)
(define-data-var active-withdrawal-fee uint standard-processing-fee)
(define-data-var active-daily-withdrawal-limit uint default-withdrawal-limit)
(define-data-var total-deposits-processed uint u0)
(define-data-var total-withdrawals-processed uint u0)
(define-data-var total-transfers-processed uint u0)
(define-data-var transaction-sequence-number uint u0)
(define-data-var security-unlock-attempt-maximum uint standard-unlock-attempt-limit)
(define-data-var platform-user-count uint u0)
(define-data-var active-user-account-count uint u0)
(define-data-var locked-user-account-count uint u0)
(define-data-var emergency-system-halt bool false)
(define-data-var required-minimum-balance uint u0)

;; DATA STORAGE MAPS

(define-map user-account-balances principal uint)
(define-map user-daily-withdrawal-records { account-holder: principal, calendar-day: uint } uint)
(define-map platform-registered-users principal bool)
(define-map user-security-configurations principal { is-account-locked: bool, security-failure-count: uint, encrypted-security-hash: (buff 32), account-security-level: uint, most-recent-login-block: uint, registration-block-height: uint })
(define-map platform-transaction-ledger uint { transaction-identifier: uint, account-holder: principal, transaction-type: (string-ascii 30), transaction-amount: uint, block-timestamp: uint, blockchain-block-number: uint, applied-transaction-fee: uint, funds-recipient: (optional principal), processing-status: (string-ascii 20) })
(define-map user-account-analytics principal { membership-tier: (string-ascii 20), cumulative-deposits: uint, cumulative-withdrawals: uint, cumulative-outbound-transfers: uint, cumulative-inbound-transfers: uint, registration-timestamp: uint, latest-activity-block: uint, identity-verification-status: bool, account-suspension-status: bool })

;; UTILITY FUNCTIONS

(define-private (get-current-calendar-day)
  (/ block-height daily-block-count))

(define-private (compute-proportional-fee (transaction-amount uint))
  (let ((calculated-percentage-fee (/ (* transaction-amount fee-calculation-basis) u10000)))
    (if (> calculated-percentage-fee (var-get active-withdrawal-fee))
        (var-get active-withdrawal-fee)
        calculated-percentage-fee)))

(define-private (validate-account-lock-status (account-holder principal))
  (match (map-get? user-security-configurations account-holder)
    user-security-data (get is-account-locked user-security-data)
    false))

(define-private (validate-account-suspension-status (account-holder principal))
  (match (map-get? user-account-analytics account-holder)
    user-analytics (get account-suspension-status user-analytics)
    false))

(define-private (retrieve-security-failure-count (account-holder principal))
  (match (map-get? user-security-configurations account-holder)
    user-security-data (get security-failure-count user-security-data)
    u0))

(define-private (confirm-user-registration (account-holder principal))
  (default-to false (map-get? platform-registered-users account-holder)))

(define-private (retrieve-daily-withdrawal-amount (account-holder principal))
  (default-to u0 (map-get? user-daily-withdrawal-records { account-holder: account-holder, calendar-day: (get-current-calendar-day) })))

(define-private (update-withdrawal-daily-tracking (account-holder principal) (withdrawal-amount uint))
  (let ((todays-date (get-current-calendar-day))
        (current-daily-total (retrieve-daily-withdrawal-amount account-holder)))
    (map-set user-daily-withdrawal-records { account-holder: account-holder, calendar-day: todays-date } (+ current-daily-total withdrawal-amount))))

(define-private (create-transaction-record (account-holder principal) (transaction-type (string-ascii 30)) (amount uint) (processing-fee uint) (recipient-account (optional principal)))
  (let ((next-transaction-id (+ (var-get transaction-sequence-number) u1)))
    (map-set platform-transaction-ledger next-transaction-id
      { transaction-identifier: next-transaction-id, account-holder: account-holder, transaction-type: transaction-type, transaction-amount: amount, block-timestamp: block-height, blockchain-block-number: block-height, applied-transaction-fee: processing-fee, funds-recipient: recipient-account, processing-status: "completed" })
    (var-set transaction-sequence-number next-transaction-id)
    next-transaction-id))

(define-private (refresh-user-activity-timestamp (account-holder principal))
  (match (map-get? user-account-analytics account-holder)
    user-analytics (map-set user-account-analytics account-holder (merge user-analytics { latest-activity-block: block-height }))
    false))

(define-private (verify-transaction-amount-validity (amount uint))
  (and (>= amount minimum-deposit-requirement) (<= amount single-transaction-limit)))

(define-private (verify-system-maintenance-status)
  (not (var-get platform-maintenance-mode)))

;; ON-CHAIN FUNCTIONS (STATE-MODIFYING ONLY)

;; CUSTOMER ACCOUNT MANAGEMENT
(define-public (establish-customer-banking-account)
  (begin
    (asserts! (var-get system-operational-status) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-system-maintenance-status) ERR-MAINTENANCE-MODE-ACTIVE)
    (asserts! (not (confirm-user-registration tx-sender)) ERR-CUSTOMER-ACCOUNT-ALREADY-EXISTS)
    (map-set platform-registered-users tx-sender true)
    (map-set user-account-balances tx-sender u0)
    (map-set user-security-configurations tx-sender { is-account-locked: false, security-failure-count: u0, encrypted-security-hash: empty-security-hash, account-security-level: u1, most-recent-login-block: block-height, registration-block-height: block-height })
    (map-set user-account-analytics tx-sender { membership-tier: "standard", cumulative-deposits: u0, cumulative-withdrawals: u0, cumulative-outbound-transfers: u0, cumulative-inbound-transfers: u0, registration-timestamp: block-height, latest-activity-block: block-height, identity-verification-status: false, account-suspension-status: false })
    (var-set platform-user-count (+ (var-get platform-user-count) u1))
    (var-set active-user-account-count (+ (var-get active-user-account-count) u1))
    (create-transaction-record tx-sender "account-creation" u0 u0 none)
    (ok true)))

(define-public (configure-account-security-protection (security-hash (buff 32)) (protection-level uint))
  (begin
    (asserts! (confirm-user-registration tx-sender) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (asserts! (not (validate-account-lock-status tx-sender)) ERR-CUSTOMER-ACCOUNT-IS-LOCKED)
    (asserts! (not (validate-account-suspension-status tx-sender)) ERR-ACCOUNT-FREEZE-ACTIVE)
    (asserts! (not (is-eq security-hash empty-security-hash)) ERR-INVALID-SECURITY-CODE)
    (asserts! (and (>= protection-level u1) (<= protection-level u5)) ERR-INVALID-SECURITY-LEVEL)
    (let ((existing-security-config (unwrap-panic (map-get? user-security-configurations tx-sender))))
      (map-set user-security-configurations tx-sender (merge existing-security-config { is-account-locked: true, security-failure-count: u0, encrypted-security-hash: security-hash, account-security-level: protection-level, most-recent-login-block: block-height })))
    (var-set locked-user-account-count (+ (var-get locked-user-account-count) u1))
    (var-set active-user-account-count (- (var-get active-user-account-count) u1))
    (refresh-user-activity-timestamp tx-sender)
    (create-transaction-record tx-sender "security-enabled" u0 u0 none)
    (ok true)))

(define-public (authenticate-and-unlock-account (provided-security-credential (buff 32)))
  (begin
    (asserts! (confirm-user-registration tx-sender) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (asserts! (validate-account-lock-status tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (validate-account-suspension-status tx-sender)) ERR-ACCOUNT-FREEZE-ACTIVE)
    (let ((user-security-config (unwrap-panic (map-get? user-security-configurations tx-sender)))
          (stored-hash (get encrypted-security-hash user-security-config))
          (failed-attempts (get security-failure-count user-security-config))
          (attempt-threshold (var-get security-unlock-attempt-maximum)))
      (asserts! (< failed-attempts attempt-threshold) ERR-MAX-UNLOCK-ATTEMPTS-REACHED)
      (if (is-eq provided-security-credential stored-hash)
        (begin
          (map-set user-security-configurations tx-sender (merge user-security-config { is-account-locked: false, security-failure-count: u0, encrypted-security-hash: empty-security-hash, most-recent-login-block: block-height }))
          (var-set locked-user-account-count (- (var-get locked-user-account-count) u1))
          (var-set active-user-account-count (+ (var-get active-user-account-count) u1))
          (refresh-user-activity-timestamp tx-sender)
          (create-transaction-record tx-sender "account-unlocked" u0 u0 none)
          (ok true))
        (begin
          (map-set user-security-configurations tx-sender (merge user-security-config { security-failure-count: (+ failed-attempts u1), most-recent-login-block: block-height }))
          ERR-INVALID-SECURITY-CODE)))))

;; CORE BANKING TRANSACTIONS
(define-public (process-account-deposit (deposit-amount uint))
  (begin
    (asserts! (var-get system-operational-status) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-system-maintenance-status) ERR-MAINTENANCE-MODE-ACTIVE)
    (asserts! (not (var-get emergency-system-halt)) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-transaction-amount-validity deposit-amount) ERR-INVALID-TRANSACTION-AMOUNT)
    (asserts! (confirm-user-registration tx-sender) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (asserts! (not (validate-account-lock-status tx-sender)) ERR-CUSTOMER-ACCOUNT-IS-LOCKED)
    (asserts! (not (validate-account-suspension-status tx-sender)) ERR-ACCOUNT-FREEZE-ACTIVE)
    (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
    (let ((current-balance (default-to u0 (map-get? user-account-balances tx-sender)))
          (user-analytics (unwrap-panic (map-get? user-account-analytics tx-sender))))
      (map-set user-account-balances tx-sender (+ current-balance deposit-amount))
      (map-set user-account-analytics tx-sender (merge user-analytics { cumulative-deposits: (+ (get cumulative-deposits user-analytics) deposit-amount), latest-activity-block: block-height }))
      (var-set total-deposits-processed (+ (var-get total-deposits-processed) deposit-amount))
      (create-transaction-record tx-sender "funds-deposited" deposit-amount u0 none)
      (ok deposit-amount))))

(define-public (process-account-withdrawal (withdrawal-amount uint))
  (begin
    (asserts! (var-get system-operational-status) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-system-maintenance-status) ERR-MAINTENANCE-MODE-ACTIVE)
    (asserts! (not (var-get emergency-system-halt)) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-transaction-amount-validity withdrawal-amount) ERR-INVALID-TRANSACTION-AMOUNT)
    (asserts! (confirm-user-registration tx-sender) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (asserts! (not (validate-account-lock-status tx-sender)) ERR-CUSTOMER-ACCOUNT-IS-LOCKED)
    (asserts! (not (validate-account-suspension-status tx-sender)) ERR-ACCOUNT-FREEZE-ACTIVE)
    (let ((current-balance (default-to u0 (map-get? user-account-balances tx-sender)))
          (calculated-fee (compute-proportional-fee withdrawal-amount))
          (total-cost (+ withdrawal-amount calculated-fee))
          (todays-withdrawal-total (retrieve-daily-withdrawal-amount tx-sender))
          (withdrawal-limit (var-get active-daily-withdrawal-limit))
          (user-analytics (unwrap-panic (map-get? user-account-analytics tx-sender))))
      (asserts! (>= current-balance total-cost) ERR-INSUFFICIENT-FUNDS)
      (asserts! (<= (+ todays-withdrawal-total withdrawal-amount) withdrawal-limit) ERR-DAILY-WITHDRAWAL-LIMIT-EXCEEDED)
      (asserts! (>= (- current-balance total-cost) (var-get required-minimum-balance)) ERR-INSUFFICIENT-FUNDS)
      (map-set user-account-balances tx-sender (- current-balance total-cost))
      (update-withdrawal-daily-tracking tx-sender withdrawal-amount)
      (map-set user-account-analytics tx-sender (merge user-analytics { cumulative-withdrawals: (+ (get cumulative-withdrawals user-analytics) withdrawal-amount), latest-activity-block: block-height }))
      (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
      (var-set total-withdrawals-processed (+ (var-get total-withdrawals-processed) withdrawal-amount))
      (create-transaction-record tx-sender "funds-withdrawn" withdrawal-amount calculated-fee none)
      (ok withdrawal-amount))))

(define-public (execute-peer-to-peer-transfer (recipient-account principal) (transfer-amount uint))
  (begin
    (asserts! (var-get system-operational-status) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-system-maintenance-status) ERR-MAINTENANCE-MODE-ACTIVE)
    (asserts! (not (var-get emergency-system-halt)) ERR-BANKING-SYSTEM-OFFLINE)
    (asserts! (verify-transaction-amount-validity transfer-amount) ERR-INVALID-TRANSACTION-AMOUNT)
    (asserts! (confirm-user-registration tx-sender) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (asserts! (confirm-user-registration recipient-account) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (asserts! (not (is-eq tx-sender recipient-account)) ERR-SELF-TRANSFER-NOT-ALLOWED)
    (asserts! (not (validate-account-lock-status tx-sender)) ERR-CUSTOMER-ACCOUNT-IS-LOCKED)
    (asserts! (not (validate-account-lock-status recipient-account)) ERR-CUSTOMER-ACCOUNT-IS-LOCKED)
    (asserts! (not (validate-account-suspension-status tx-sender)) ERR-ACCOUNT-FREEZE-ACTIVE)
    (asserts! (not (validate-account-suspension-status recipient-account)) ERR-ACCOUNT-FREEZE-ACTIVE)
    (let ((sender-balance (default-to u0 (map-get? user-account-balances tx-sender)))
          (recipient-balance (default-to u0 (map-get? user-account-balances recipient-account)))
          (sender-analytics (unwrap-panic (map-get? user-account-analytics tx-sender)))
          (recipient-analytics (unwrap-panic (map-get? user-account-analytics recipient-account))))
      (asserts! (>= sender-balance transfer-amount) ERR-INSUFFICIENT-FUNDS)
      (asserts! (>= (- sender-balance transfer-amount) (var-get required-minimum-balance)) ERR-INSUFFICIENT-FUNDS)
      (map-set user-account-balances tx-sender (- sender-balance transfer-amount))
      (map-set user-account-balances recipient-account (+ recipient-balance transfer-amount))
      (map-set user-account-analytics tx-sender (merge sender-analytics { cumulative-outbound-transfers: (+ (get cumulative-outbound-transfers sender-analytics) transfer-amount), latest-activity-block: block-height }))
      (map-set user-account-analytics recipient-account (merge recipient-analytics { cumulative-inbound-transfers: (+ (get cumulative-inbound-transfers recipient-analytics) transfer-amount), latest-activity-block: block-height }))
      (var-set total-transfers-processed (+ (var-get total-transfers-processed) transfer-amount))
      (create-transaction-record tx-sender "funds-sent" transfer-amount u0 (some recipient-account))
      (create-transaction-record recipient-account "funds-received" transfer-amount u0 (some tx-sender))
      (ok transfer-amount))))

;; ADMINISTRATIVE CONTROLS
(define-public (modify-system-operational-state (new-operational-status bool))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (var-set system-operational-status new-operational-status)
    (create-transaction-record platform-administrator "system-status-updated" (if new-operational-status u1 u0) u0 none)
    (ok new-operational-status)))

(define-public (toggle-platform-maintenance-mode (maintenance-status bool))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (var-set platform-maintenance-mode maintenance-status)
    (create-transaction-record platform-administrator "maintenance-mode-updated" (if maintenance-status u1 u0) u0 none)
    (ok maintenance-status)))

(define-public (adjust-withdrawal-processing-fee (updated-fee uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= updated-fee maximum-fee-cap) ERR-TRANSACTION-FEE-TOO-HIGH)
    (var-set active-withdrawal-fee updated-fee)
    (create-transaction-record platform-administrator "withdrawal-fee-updated" updated-fee u0 none)
    (ok updated-fee)))

(define-public (configure-daily-withdrawal-threshold (updated-threshold uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (>= updated-threshold minimum-withdrawal-threshold) ERR-LIMIT-BELOW-MINIMUM-THRESHOLD)
    (asserts! (<= updated-threshold maximum-withdrawal-threshold) ERR-LIMIT-EXCEEDS-MAXIMUM-THRESHOLD)
    (var-set active-daily-withdrawal-limit updated-threshold)
    (create-transaction-record platform-administrator "daily-limit-updated" updated-threshold u0 none)
    (ok updated-threshold)))

(define-public (administrator-emergency-account-unlock (locked-user-account principal))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (confirm-user-registration locked-user-account) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (let ((user-security-config (unwrap-panic (map-get? user-security-configurations locked-user-account))))
      (map-set user-security-configurations locked-user-account (merge user-security-config { is-account-locked: false, security-failure-count: u0, encrypted-security-hash: empty-security-hash, most-recent-login-block: block-height })))
    (if (validate-account-lock-status locked-user-account)
        (begin
          (var-set locked-user-account-count (- (var-get locked-user-account-count) u1))
          (var-set active-user-account-count (+ (var-get active-user-account-count) u1)))
        true)
    (create-transaction-record locked-user-account "admin-emergency-unlock" u0 u0 none)
    (ok true)))

(define-public (configure-security-attempt-threshold (updated-attempt-limit uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and (>= updated-attempt-limit minimum-security-attempts) (<= updated-attempt-limit maximum-security-attempts)) ERR-SECURITY-ATTEMPT-LIMIT-OUT-OF-BOUNDS)
    (var-set security-unlock-attempt-maximum updated-attempt-limit)
    (create-transaction-record platform-administrator "unlock-limit-updated" updated-attempt-limit u0 none)
    (ok updated-attempt-limit)))

(define-public (execute-emergency-fund-extraction (extraction-amount uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> extraction-amount u0) ERR-INVALID-TRANSACTION-AMOUNT)
    (asserts! (<= extraction-amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? extraction-amount tx-sender platform-administrator)))
    (create-transaction-record platform-administrator "emergency-fund-recovery" extraction-amount u0 none)
    (ok extraction-amount)))

(define-public (administrator-account-suspension-control (target-user-account principal) (suspension-status bool))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (confirm-user-registration target-user-account) ERR-CUSTOMER-ACCOUNT-NOT-EXISTS)
    (let ((user-analytics (unwrap-panic (map-get? user-account-analytics target-user-account))))
      (map-set user-account-analytics target-user-account (merge user-analytics { account-suspension-status: suspension-status })))
    (create-transaction-record target-user-account (if suspension-status "account-frozen" "account-unfrozen") u0 u0 none)
    (ok suspension-status)))

(define-public (configure-minimum-balance-requirement (updated-minimum-balance uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= updated-minimum-balance (* u100 stx-to-micro-stx-multiplier)) ERR-LIMIT-EXCEEDS-MAXIMUM-THRESHOLD)
    (var-set required-minimum-balance updated-minimum-balance)
    (create-transaction-record platform-administrator "minimum-balance-updated" updated-minimum-balance u0 none)
    (ok updated-minimum-balance)))

(define-public (activate-emergency-system-shutdown (shutdown-status bool))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (var-set emergency-system-halt shutdown-status)
    (create-transaction-record platform-administrator "emergency-pause-toggled" (if shutdown-status u1 u0) u0 none)
    (ok shutdown-status)))