;; Responsible Pet Rewards Contract
;; Token incentives for proper pet care, regular vet visits, and successful pet adoption facilitation

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_INSUFFICIENT_BALANCE (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_INVALID_INPUT (err u403))
(define-constant ERR_REWARD_NOT_FOUND (err u404))
(define-constant ERR_CHALLENGE_NOT_FOUND (err u405))
(define-constant ERR_CHALLENGE_COMPLETED (err u406))
(define-constant ERR_INVALID_PARTICIPANT (err u407))

;; Token Constants
(define-constant TOKEN_NAME "PetCare Token")
(define-constant TOKEN_SYMBOL "PCT")
(define-constant TOKEN_DECIMALS u8)
(define-constant MAX_SUPPLY u1000000000000000) ;; 100M tokens with 8 decimals

;; Reward Amounts
(define-constant REWARD_VET_VISIT u50000000) ;; 0.5 PCT
(define-constant REWARD_VACCINATION u75000000) ;; 0.75 PCT
(define-constant REWARD_ADOPTION_FACILITATION u200000000) ;; 2 PCT
(define-constant REWARD_WELLNESS_CHECKUP u25000000) ;; 0.25 PCT
(define-constant REWARD_SPAY_NEUTER u100000000) ;; 1 PCT
(define-constant REWARD_EMERGENCY_CARE u150000000) ;; 1.5 PCT

;; Challenge Types
(define-constant CHALLENGE_MONTHLY_CHECKUP u0)
(define-constant CHALLENGE_VACCINATION_SERIES u1)
(define-constant CHALLENGE_TRAINING_COMPLETION u2)
(define-constant CHALLENGE_COMMUNITY_SERVICE u3)
(define-constant CHALLENGE_ADOPTION_SUCCESS u4)

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var contract-balance uint u0)
(define-data-var reward-id-nonce uint u0)
(define-data-var challenge-id-nonce uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var total-active-challenges uint u0)

;; Data Maps
(define-map token-balances
  { holder: principal }
  { balance: uint }
)

(define-map reward-records
  { reward-id: uint }
  {
    recipient: principal,
    pet-id: uint,
    reward-type: (string-ascii 50),
    amount: uint,
    reason: (string-ascii 200),
    verified-by: principal,
    reward-date: uint,
    status: (string-ascii 20),
    transaction-hash: (optional (buff 32))
  }
)

(define-map care-challenges
  { challenge-id: uint }
  {
    challenge-type: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    reward-amount: uint,
    start-date: uint,
    end-date: uint,
    max-participants: uint,
    current-participants: uint,
    created-by: principal,
    is-active: bool,
    completion-requirements: (string-ascii 200)
  }
)

(define-map challenge-participants
  { challenge-id: uint, participant: principal }
  {
    pet-id: uint,
    joined-date: uint,
    progress: uint,
    completed: bool,
    completion-date: (optional uint),
    verification-status: (string-ascii 20),
    reward-claimed: bool
  }
)

(define-map user-reward-summary
  { user: principal }
  {
    total-earned: uint,
    total-challenges-completed: uint,
    vet-visit-rewards: uint,
    vaccination-rewards: uint,
    adoption-rewards: uint,
    bonus-rewards: uint,
    current-streak: uint,
    longest-streak: uint,
    last-reward-date: uint
  }
)

(define-map monthly-leaderboard
  { month: uint, rank: uint }
  {
    user: principal,
    points: uint,
    rewards-earned: uint,
    challenges-completed: uint
  }
)

(define-map redemption-catalog
  { item-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    cost: uint,
    category: (string-ascii 50),
    available-quantity: uint,
    total-redeemed: uint,
    is-active: bool,
    created-date: uint
  }
)

(define-map user-redemptions
  { user: principal, redemption-id: uint }
  {
    item-id: uint,
    quantity: uint,
    cost-paid: uint,
    redemption-date: uint,
    status: (string-ascii 20),
    delivery-info: (string-ascii 300)
  }
)

;; Private Functions
(define-private (get-next-reward-id)
  (let ((current-id (var-get reward-id-nonce)))
    (var-set reward-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (get-next-challenge-id)
  (let ((current-id (var-get challenge-id-nonce)))
    (var-set challenge-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let 
    (
      (current-balance (get-token-balance recipient))
      (new-total-supply (+ (var-get total-supply) amount))
    )
    (asserts! (<= new-total-supply MAX_SUPPLY) ERR_INVALID_AMOUNT)
    (map-set token-balances { holder: recipient } { balance: (+ current-balance amount) })
    (var-set total-supply new-total-supply)
    (ok amount)
  )
)

(define-private (transfer-tokens (sender principal) (recipient principal) (amount uint))
  (let 
    (
      (sender-balance (get-token-balance sender))
      (recipient-balance (get-token-balance recipient))
    )
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set token-balances { holder: sender } { balance: (- sender-balance amount) })
    (map-set token-balances { holder: recipient } { balance: (+ recipient-balance amount) })
    (ok amount)
  )
)

(define-private (is-valid-challenge-type (challenge-type uint))
  (and (>= challenge-type CHALLENGE_MONTHLY_CHECKUP) (<= challenge-type CHALLENGE_ADOPTION_SUCCESS))
)

(define-private (calculate-streak-bonus (current-streak uint))
  (if (>= current-streak u10) 
      u50000000 ;; 0.5 PCT bonus for 10+ streak
      (if (>= current-streak u5) 
          u25000000  ;; 0.25 PCT bonus for 5+ streak
          (if (>= current-streak u3) 
              u10000000  ;; 0.1 PCT bonus for 3+ streak
              u0
          )
      )
  )
)

(define-private (update-user-streak (user principal) (reward-date uint))
  (match (map-get? user-reward-summary { user: user })
    summary-data
      (let 
        (
          (days-diff (if (> reward-date (get last-reward-date summary-data))
                        (/ (- reward-date (get last-reward-date summary-data)) u144) ;; Approximate blocks per day
                        u0))
          (new-streak (if (<= days-diff u2) ;; Within 2 days maintains streak
                         (+ (get current-streak summary-data) u1)
                         u1)) ;; Reset to 1
        )
        (map-set user-reward-summary
          { user: user }
          (merge summary-data {
            current-streak: new-streak,
            longest-streak: (if (> new-streak (get longest-streak summary-data))
                               new-streak
                               (get longest-streak summary-data)),
            last-reward-date: reward-date
          })
        )
        new-streak
      )
    u1 ;; First reward, streak starts at 1
  )
)

;; Read-Only Functions
(define-read-only (get-token-balance (holder principal))
  (default-to u0 (get balance (map-get? token-balances { holder: holder })))
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-read-only (get-reward-record (reward-id uint))
  (map-get? reward-records { reward-id: reward-id })
)

(define-read-only (get-challenge-info (challenge-id uint))
  (map-get? care-challenges { challenge-id: challenge-id })
)

(define-read-only (get-challenge-participation (challenge-id uint) (participant principal))
  (map-get? challenge-participants { challenge-id: challenge-id, participant: participant })
)

(define-read-only (get-user-reward-summary (user principal))
  (map-get? user-reward-summary { user: user })
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (get-total-active-challenges)
  (var-get total-active-challenges)
)

(define-read-only (get-redemption-item (item-id uint))
  (map-get? redemption-catalog { item-id: item-id })
)

(define-read-only (get-user-redemption (user principal) (redemption-id uint))
  (map-get? user-redemptions { user: user, redemption-id: redemption-id })
)

(define-read-only (calculate-user-points (user principal))
  (match (get-user-reward-summary user)
    summary-data
      (+ 
        (* (get vet-visit-rewards summary-data) u2)
        (* (get vaccination-rewards summary-data) u3)
        (* (get adoption-rewards summary-data) u10)
        (* (get total-challenges-completed summary-data) u5)
        (get bonus-rewards summary-data)
      )
    u0
  )
)

;; Public Functions
(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    ;; Mint initial supply to contract for rewards distribution
    (unwrap! (mint-tokens CONTRACT_OWNER u50000000000000) ERR_INVALID_AMOUNT) ;; 500M tokens
    (var-set contract-balance u50000000000000)
    (ok true)
  )
)

(define-public (award-vet-visit-reward (pet-owner principal) (pet-id uint) (vet-address principal))
  (let 
    (
      (reward-id (get-next-reward-id))
      (current-streak (update-user-streak pet-owner stacks-block-height))
      (streak-bonus (calculate-streak-bonus current-streak))
      (total-reward (+ REWARD_VET_VISIT streak-bonus))
    )
    (asserts! (> (var-get contract-balance) total-reward) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer reward tokens
    (unwrap! (transfer-tokens CONTRACT_OWNER pet-owner total-reward) ERR_INSUFFICIENT_BALANCE)
    
    ;; Record the reward
    (map-set reward-records
      { reward-id: reward-id }
      {
        recipient: pet-owner,
        pet-id: pet-id,
        reward-type: "vet-visit",
        amount: total-reward,
        reason: "Regular veterinary visit completed",
        verified-by: vet-address,
        reward-date: stacks-block-height,
        status: "awarded",
        transaction-hash: none
      }
    )
    
    ;; Update user summary
    (match (get-user-reward-summary pet-owner)
      summary
        (map-set user-reward-summary
          { user: pet-owner }
          (merge summary {
            total-earned: (+ (get total-earned summary) total-reward),
            vet-visit-rewards: (+ (get vet-visit-rewards summary) u1),
            bonus-rewards: (+ (get bonus-rewards summary) streak-bonus)
          })
        )
      ;; Create new summary
      (map-set user-reward-summary
        { user: pet-owner }
        {
          total-earned: total-reward,
          total-challenges-completed: u0,
          vet-visit-rewards: u1,
          vaccination-rewards: u0,
          adoption-rewards: u0,
          bonus-rewards: streak-bonus,
          current-streak: current-streak,
          longest-streak: current-streak,
          last-reward-date: stacks-block-height
        }
      )
    )
    
    ;; Update contract balance and totals
    (var-set contract-balance (- (var-get contract-balance) total-reward))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) total-reward))
    
    (ok reward-id)
  )
)

(define-public (award-vaccination-reward (pet-owner principal) (pet-id uint) (vet-address principal) (vaccine-type (string-ascii 50)))
  (let 
    (
      (reward-id (get-next-reward-id))
      (current-streak (update-user-streak pet-owner stacks-block-height))
      (streak-bonus (calculate-streak-bonus current-streak))
      (total-reward (+ REWARD_VACCINATION streak-bonus))
    )
    (asserts! (> (var-get contract-balance) total-reward) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer reward tokens
    (unwrap! (transfer-tokens CONTRACT_OWNER pet-owner total-reward) ERR_INSUFFICIENT_BALANCE)
    
    ;; Record the reward
    (map-set reward-records
      { reward-id: reward-id }
      {
        recipient: pet-owner,
        pet-id: pet-id,
        reward-type: "vaccination",
        amount: total-reward,
        reason: (unwrap-panic (as-max-len? (concat "Vaccination completed: " vaccine-type) u200)),
        verified-by: vet-address,
        reward-date: stacks-block-height,
        status: "awarded",
        transaction-hash: none
      }
    )
    
    ;; Update user summary
    (match (get-user-reward-summary pet-owner)
      summary
        (map-set user-reward-summary
          { user: pet-owner }
          (merge summary {
            total-earned: (+ (get total-earned summary) total-reward),
            vaccination-rewards: (+ (get vaccination-rewards summary) u1),
            bonus-rewards: (+ (get bonus-rewards summary) streak-bonus)
          })
        )
      ;; Create new summary
      (map-set user-reward-summary
        { user: pet-owner }
        {
          total-earned: total-reward,
          total-challenges-completed: u0,
          vet-visit-rewards: u0,
          vaccination-rewards: u1,
          adoption-rewards: u0,
          bonus-rewards: streak-bonus,
          current-streak: current-streak,
          longest-streak: current-streak,
          last-reward-date: stacks-block-height
        }
      )
    )
    
    ;; Update contract balance and totals
    (var-set contract-balance (- (var-get contract-balance) total-reward))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) total-reward))
    
    (ok reward-id)
  )
)

(define-public (create-care-challenge
  (challenge-type uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (reward-amount uint)
  (end-date uint)
  (max-participants uint)
  (completion-requirements (string-ascii 200))
  )
  (let ((challenge-id (get-next-challenge-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-valid-challenge-type challenge-type) ERR_INVALID_INPUT)
    (asserts! (> end-date stacks-block-height) ERR_INVALID_INPUT)
    (asserts! (> max-participants u0) ERR_INVALID_INPUT)
    (asserts! (> reward-amount u0) ERR_INVALID_AMOUNT)
    
    (map-set care-challenges
      { challenge-id: challenge-id }
      {
        challenge-type: challenge-type,
        title: title,
        description: description,
        reward-amount: reward-amount,
        start-date: stacks-block-height,
        end-date: end-date,
        max-participants: max-participants,
        current-participants: u0,
        created-by: tx-sender,
        is-active: true,
        completion-requirements: completion-requirements
      }
    )
    
    (var-set total-active-challenges (+ (var-get total-active-challenges) u1))
    
    (ok challenge-id)
  )
)

(define-public (join-challenge (challenge-id uint) (pet-id uint))
  (let ((challenge-data (unwrap! (get-challenge-info challenge-id) ERR_CHALLENGE_NOT_FOUND)))
    (asserts! (get is-active challenge-data) ERR_CHALLENGE_NOT_FOUND)
    (asserts! (< (get current-participants challenge-data) (get max-participants challenge-data)) ERR_INVALID_PARTICIPANT)
    (asserts! (is-none (get-challenge-participation challenge-id tx-sender)) ERR_INVALID_PARTICIPANT)
    
    ;; Add participant to challenge
    (map-set challenge-participants
      { challenge-id: challenge-id, participant: tx-sender }
      {
        pet-id: pet-id,
        joined-date: stacks-block-height,
        progress: u0,
        completed: false,
        completion-date: none,
        verification-status: "in-progress",
        reward-claimed: false
      }
    )
    
    ;; Update challenge participant count
    (map-set care-challenges
      { challenge-id: challenge-id }
      (merge challenge-data {
        current-participants: (+ (get current-participants challenge-data) u1)
      })
    )
    
    (ok true)
  )
)

(define-public (complete-challenge (challenge-id uint) (participant principal))
  (let 
    (
      (challenge-data (unwrap! (get-challenge-info challenge-id) ERR_CHALLENGE_NOT_FOUND))
      (participation-data (unwrap! (get-challenge-participation challenge-id participant) ERR_INVALID_PARTICIPANT))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (get completed participation-data)) ERR_CHALLENGE_COMPLETED)
    (asserts! (> (var-get contract-balance) (get reward-amount challenge-data)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Mark as completed
    (map-set challenge-participants
      { challenge-id: challenge-id, participant: participant }
      (merge participation-data {
        completed: true,
        completion-date: (some stacks-block-height),
        verification-status: "completed",
        progress: u100
      })
    )
    
    ;; Award reward
    (unwrap! (transfer-tokens CONTRACT_OWNER participant (get reward-amount challenge-data)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update user summary
    (match (get-user-reward-summary participant)
      summary
        (map-set user-reward-summary
          { user: participant }
          (merge summary {
            total-earned: (+ (get total-earned summary) (get reward-amount challenge-data)),
            total-challenges-completed: (+ (get total-challenges-completed summary) u1)
          })
        )
      ;; Create new summary
      (map-set user-reward-summary
        { user: participant }
        {
          total-earned: (get reward-amount challenge-data),
          total-challenges-completed: u1,
          vet-visit-rewards: u0,
          vaccination-rewards: u0,
          adoption-rewards: u0,
          bonus-rewards: u0,
          current-streak: u1,
          longest-streak: u1,
          last-reward-date: stacks-block-height
        }
      )
    )
    
    ;; Update contract balance and totals
    (var-set contract-balance (- (var-get contract-balance) (get reward-amount challenge-data)))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) (get reward-amount challenge-data)))
    
    (ok true)
  )
)

(define-public (transfer (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (unwrap! (transfer-tokens tx-sender recipient amount) ERR_INSUFFICIENT_BALANCE)
    (ok amount)
  )
)
