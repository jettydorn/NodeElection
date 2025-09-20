
;; title: NodeElection
;; version: 1.0.0
;; summary: Stake-weighted voting system for blockchain validator selection and rotation
;; description: A smart contract that allows stakeholders to vote for validators based on their stake weight,
;;              managing validator elections and automatic rotation periods.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-stake (err u103))
(define-constant err-election-not-active (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-invalid-validator (err u106))
(define-constant err-election-ended (err u107))
(define-constant err-no-active-election (err u108))

;; Minimum stake required to become a validator candidate
(define-constant min-validator-stake u1000000) ;; 1 STX in micro-STX

;; Election duration in blocks
(define-constant election-duration u1008) ;; ~1 week (assuming 10min blocks)

;; Maximum number of active validators
(define-constant max-validators u21)

;; data vars
(define-data-var contract-admin principal contract-owner)
(define-data-var current-election-id uint u0)
(define-data-var validator-count uint u0)

;; data maps

;; Validator information
(define-map validators
  { validator: principal }
  {
    stake: uint,
    votes-received: uint,
    is-active: bool,
    joined-at: uint
  }
)

;; Election information
(define-map elections
  { election-id: uint }
  {
    start-block: uint,
    end-block: uint,
    total-votes: uint,
    is-finalized: bool
  }
)

;; Voter information for each election
(define-map voter-records
  { voter: principal, election-id: uint }
  {
    voted-for: principal,
    vote-weight: uint,
    voted-at: uint
  }
)

;; Validator votes in specific election
(define-map election-votes
  { validator: principal, election-id: uint }
  { vote-count: uint }
)

;; Active validator set
(define-map active-validators
  { index: uint }
  { validator: principal }
)

;; Staker balances
(define-map stakes
  { staker: principal }
  { amount: uint }
)

;; public functions

;; Stake STX to participate in voting
(define-public (stake-tokens (amount uint))
  (let
    (
      (current-stake (default-to u0 (get amount (map-get? stakes { staker: tx-sender }))))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set stakes
      { staker: tx-sender }
      { amount: (+ current-stake amount) }
    )
    (ok amount)
  )
)

;; Unstake STX (withdraw)
(define-public (unstake-tokens (amount uint))
  (let
    (
      (current-stake (default-to u0 (get amount (map-get? stakes { staker: tx-sender }))))
    )
    (asserts! (>= current-stake amount) err-insufficient-stake)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set stakes
      { staker: tx-sender }
      { amount: (- current-stake amount) }
    )
    (ok amount)
  )
)

;; Register as a validator candidate
(define-public (register-validator)
  (let
    (
      (stake-amount (default-to u0 (get amount (map-get? stakes { staker: tx-sender }))))
    )
    (asserts! (>= stake-amount min-validator-stake) err-insufficient-stake)
    (asserts! (is-none (map-get? validators { validator: tx-sender })) err-already-exists)

    (map-set validators
      { validator: tx-sender }
      {
        stake: stake-amount,
        votes-received: u0,
        is-active: false,
        joined-at: block-height
      }
    )
    (var-set validator-count (+ (var-get validator-count) u1))
    (ok true)
  )
)

;; Start a new election (admin only)
(define-public (start-election)
  (let
    (
      (new-election-id (+ (var-get current-election-id) u1))
      (start-block block-height)
      (end-block (+ block-height election-duration))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)

    ;; Check if there's an active election
    (match (map-get? elections { election-id: (var-get current-election-id) })
      current-election
      (asserts! (get is-finalized current-election) err-election-not-active)
      true
    )

    (map-set elections
      { election-id: new-election-id }
      {
        start-block: start-block,
        end-block: end-block,
        total-votes: u0,
        is-finalized: false
      }
    )
    (var-set current-election-id new-election-id)
    (ok new-election-id)
  )
)

;; Vote for a validator in current election
(define-public (vote-for-validator (validator principal))
  (let
    (
      (election-id (var-get current-election-id))
      (voter-stake (default-to u0 (get amount (map-get? stakes { staker: tx-sender }))))
      (election-info (unwrap! (map-get? elections { election-id: election-id }) err-no-active-election))
      (validator-info (unwrap! (map-get? validators { validator: validator }) err-invalid-validator))
      (current-votes (default-to u0 (get vote-count (map-get? election-votes { validator: validator, election-id: election-id }))))
    )

    ;; Verify election is active
    (asserts! (< block-height (get end-block election-info)) err-election-ended)
    (asserts! (not (get is-finalized election-info)) err-election-ended)

    ;; Verify voter hasn't already voted
    (asserts! (is-none (map-get? voter-records { voter: tx-sender, election-id: election-id })) err-already-voted)

    ;; Verify voter has stake
    (asserts! (> voter-stake u0) err-insufficient-stake)

    ;; Record the vote
    (map-set voter-records
      { voter: tx-sender, election-id: election-id }
      {
        voted-for: validator,
        vote-weight: voter-stake,
        voted-at: block-height
      }
    )

    ;; Update validator vote count
    (map-set election-votes
      { validator: validator, election-id: election-id }
      { vote-count: (+ current-votes voter-stake) }
    )

    ;; Update election total votes
    (map-set elections
      { election-id: election-id }
      (merge election-info { total-votes: (+ (get total-votes election-info) voter-stake) })
    )

    (ok true)
  )
)

;; Finalize election and select validators (admin only)
(define-public (finalize-election)
  (let
    (
      (election-id (var-get current-election-id))
      (election-info (unwrap! (map-get? elections { election-id: election-id }) err-no-active-election))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
    (asserts! (>= block-height (get end-block election-info)) err-election-not-active)
    (asserts! (not (get is-finalized election-info)) err-already-exists)

    ;; Mark election as finalized
    (map-set elections
      { election-id: election-id }
      (merge election-info { is-finalized: true })
    )

    ;; Note: In a full implementation, this would select top validators
    ;; and update the active validator set. For simplicity, we're just
    ;; marking the election as finalized.

    (ok true)
  )
)

;; Change contract admin (current admin only)
(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

;; read only functions

;; Get validator information
(define-read-only (get-validator (validator principal))
  (map-get? validators { validator: validator })
)

;; Get current election information
(define-read-only (get-current-election)
  (let
    (
      (election-id (var-get current-election-id))
    )
    (map-get? elections { election-id: election-id })
  )
)

;; Get election information by ID
(define-read-only (get-election (election-id uint))
  (map-get? elections { election-id: election-id })
)

;; Get voter record for specific election
(define-read-only (get-voter-record (voter principal) (election-id uint))
  (map-get? voter-records { voter: voter, election-id: election-id })
)

;; Get validator votes in specific election
(define-read-only (get-validator-votes (validator principal) (election-id uint))
  (default-to u0 (get vote-count (map-get? election-votes { validator: validator, election-id: election-id })))
)

;; Get staker balance
(define-read-only (get-stake (staker principal))
  (default-to u0 (get amount (map-get? stakes { staker: staker })))
)

;; Get current election ID
(define-read-only (get-current-election-id)
  (var-get current-election-id)
)

;; Get validator count
(define-read-only (get-validator-count)
  (var-get validator-count)
)

;; Get contract admin
(define-read-only (get-contract-admin)
  (var-get contract-admin)
)

;; Check if election is active
(define-read-only (is-election-active)
  (match (get-current-election)
    election-info
    (and
      (< block-height (get end-block election-info))
      (not (get is-finalized election-info))
    )
    false
  )
)

;; private functions
;;

