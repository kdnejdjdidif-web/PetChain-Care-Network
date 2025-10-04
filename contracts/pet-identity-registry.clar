;; Pet Identity Registry Contract
;; Digital pet passports with microchip data, breed information, and medical history tracking

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PET_NOT_FOUND (err u101))
(define-constant ERR_PET_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_OWNER (err u103))
(define-constant ERR_INVALID_INPUT (err u104))
(define-constant ERR_TRANSFER_FAILED (err u105))
(define-constant MAX_STRING_LENGTH u100)

;; Data Variables
(define-data-var pet-id-nonce uint u0)
(define-data-var total-registered-pets uint u0)

;; Data Maps
(define-map pets
  { pet-id: uint }
  {
    microchip-id: (string-ascii 50),
    name: (string-ascii 50),
    breed: (string-ascii 50),
    birth-date: uint,
    gender: (string-ascii 10),
    color: (string-ascii 50),
    weight: uint,
    owner: principal,
    veterinarian: (optional principal),
    registration-date: uint,
    last-updated: uint,
    is-active: bool,
    vaccination-status: (string-ascii 20),
    medical-notes: (string-ascii 200)
  }
)

(define-map pet-ownership-history
  { pet-id: uint, transfer-id: uint }
  {
    previous-owner: principal,
    new-owner: principal,
    transfer-date: uint,
    transfer-reason: (string-ascii 100),
    verified: bool
  }
)

(define-map microchip-to-pet
  { microchip-id: (string-ascii 50) }
  { pet-id: uint }
)

(define-map owner-pets
  { owner: principal, pet-index: uint }
  { pet-id: uint }
)

(define-map owner-pet-count
  { owner: principal }
  { count: uint }
)

(define-map veterinarian-registry
  { vet-address: principal }
  {
    license-number: (string-ascii 50),
    clinic-name: (string-ascii 100),
    verified: bool,
    registration-date: uint
  }
)

;; Private Functions
(define-private (get-next-pet-id)
  (let ((current-id (var-get pet-id-nonce)))
    (var-set pet-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (increment-owner-pet-count (owner principal))
  (let ((current-count (default-to u0 (get count (map-get? owner-pet-count { owner: owner })))))
    (map-set owner-pet-count { owner: owner } { count: (+ current-count u1) })
    current-count
  )
)

(define-private (is-valid-string (input (string-ascii 200)) (max-length uint))
  (and 
    (> (len input) u0)
    (<= (len input) max-length)
  )
)

(define-private (is-authorized-for-pet (pet-id uint) (caller principal))
  (match (map-get? pets { pet-id: pet-id })
    pet-data
      (or 
        (is-eq caller (get owner pet-data))
        (is-eq caller CONTRACT_OWNER)
        (match (get veterinarian pet-data)
          vet (is-eq caller vet)
          false
        )
      )
    false
  )
)

;; Read-Only Functions
(define-read-only (get-pet-info (pet-id uint))
  (map-get? pets { pet-id: pet-id })
)

(define-read-only (get-pet-by-microchip (microchip-id (string-ascii 50)))
  (match (map-get? microchip-to-pet { microchip-id: microchip-id })
    microchip-data (get-pet-info (get pet-id microchip-data))
    none
  )
)

(define-read-only (get-owner-pet-count (owner principal))
  (default-to u0 (get count (map-get? owner-pet-count { owner: owner })))
)

(define-read-only (get-owner-pet-by-index (owner principal) (index uint))
  (map-get? owner-pets { owner: owner, pet-index: index })
)

(define-read-only (get-pet-ownership-history (pet-id uint) (transfer-id uint))
  (map-get? pet-ownership-history { pet-id: pet-id, transfer-id: transfer-id })
)

(define-read-only (get-veterinarian-info (vet-address principal))
  (map-get? veterinarian-registry { vet-address: vet-address })
)

(define-read-only (get-total-registered-pets)
  (var-get total-registered-pets)
)

(define-read-only (is-pet-owner (pet-id uint) (owner principal))
  (match (get-pet-info pet-id)
    pet-data (is-eq owner (get owner pet-data))
    false
  )
)

;; Public Functions
(define-public (register-pet 
  (microchip-id (string-ascii 50))
  (name (string-ascii 50))
  (breed (string-ascii 50))
  (birth-date uint)
  (gender (string-ascii 10))
  (color (string-ascii 50))
  (weight uint)
  (vaccination-status (string-ascii 20))
  )
  (let (
    (pet-id (get-next-pet-id))
    (owner-index (increment-owner-pet-count tx-sender))
  )
    (asserts! (is-valid-string microchip-id u50) ERR_INVALID_INPUT)
    (asserts! (is-valid-string name u50) ERR_INVALID_INPUT)
    (asserts! (is-valid-string breed u50) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? microchip-to-pet { microchip-id: microchip-id })) ERR_PET_ALREADY_EXISTS)
    (asserts! (> weight u0) ERR_INVALID_INPUT)
    
    ;; Register the pet
    (map-set pets
      { pet-id: pet-id }
      {
        microchip-id: microchip-id,
        name: name,
        breed: breed,
        birth-date: birth-date,
        gender: gender,
        color: color,
        weight: weight,
        owner: tx-sender,
        veterinarian: none,
        registration-date: stacks-block-height,
        last-updated: stacks-block-height,
        is-active: true,
        vaccination-status: vaccination-status,
        medical-notes: ""
      }
    )
    
    ;; Map microchip to pet ID
    (map-set microchip-to-pet { microchip-id: microchip-id } { pet-id: pet-id })
    
    ;; Add to owner's pet list
    (map-set owner-pets { owner: tx-sender, pet-index: owner-index } { pet-id: pet-id })
    
    ;; Increment total registered pets
    (var-set total-registered-pets (+ (var-get total-registered-pets) u1))
    
    (ok pet-id)
  )
)

(define-public (update-pet-info
  (pet-id uint)
  (weight uint)
  (vaccination-status (string-ascii 20))
  (medical-notes (string-ascii 200))
  )
  (let ((pet-data (unwrap! (get-pet-info pet-id) ERR_PET_NOT_FOUND)))
    (asserts! (is-authorized-for-pet pet-id tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active pet-data) ERR_PET_NOT_FOUND)
    (asserts! (> weight u0) ERR_INVALID_INPUT)
    
    (map-set pets
      { pet-id: pet-id }
      (merge pet-data {
        weight: weight,
        vaccination-status: vaccination-status,
        medical-notes: medical-notes,
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)

(define-public (transfer-pet-ownership 
  (pet-id uint)
  (new-owner principal)
  (transfer-reason (string-ascii 100))
  )
  (let (
    (pet-data (unwrap! (get-pet-info pet-id) ERR_PET_NOT_FOUND))
    (current-owner (get owner pet-data))
    (new-owner-index (increment-owner-pet-count new-owner))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active pet-data) ERR_PET_NOT_FOUND)
    (asserts! (not (is-eq current-owner new-owner)) ERR_INVALID_OWNER)
    (asserts! (is-valid-string transfer-reason u100) ERR_INVALID_INPUT)
    
    ;; Update pet ownership
    (map-set pets
      { pet-id: pet-id }
      (merge pet-data {
        owner: new-owner,
        last-updated: stacks-block-height
      })
    )
    
    ;; Add to new owner's pet list
    (map-set owner-pets { owner: new-owner, pet-index: new-owner-index } { pet-id: pet-id })
    
    ;; Record ownership transfer history
    (map-set pet-ownership-history
      { pet-id: pet-id, transfer-id: stacks-block-height }
      {
        previous-owner: current-owner,
        new-owner: new-owner,
        transfer-date: stacks-block-height,
        transfer-reason: transfer-reason,
        verified: true
      }
    )
    
    (ok true)
  )
)

(define-public (assign-veterinarian (pet-id uint) (vet-address principal))
  (let ((pet-data (unwrap! (get-pet-info pet-id) ERR_PET_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner pet-data)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active pet-data) ERR_PET_NOT_FOUND)
    (asserts! (is-some (get-veterinarian-info vet-address)) ERR_INVALID_INPUT)
    
    (map-set pets
      { pet-id: pet-id }
      (merge pet-data {
        veterinarian: (some vet-address),
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)

(define-public (register-veterinarian
  (license-number (string-ascii 50))
  (clinic-name (string-ascii 100))
  )
  (asserts! (is-valid-string license-number u50) ERR_INVALID_INPUT)
  (asserts! (is-valid-string clinic-name u100) ERR_INVALID_INPUT)
  
  (map-set veterinarian-registry
    { vet-address: tx-sender }
    {
      license-number: license-number,
      clinic-name: clinic-name,
      verified: false,
      registration-date: stacks-block-height
    }
  )
  
  (ok true)
)

(define-public (verify-veterinarian (vet-address principal))
  (let ((vet-data (unwrap! (get-veterinarian-info vet-address) ERR_PET_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set veterinarian-registry
      { vet-address: vet-address }
      (merge vet-data { verified: true })
    )
    
    (ok true)
  )
)

(define-public (deactivate-pet (pet-id uint))
  (let ((pet-data (unwrap! (get-pet-info pet-id) ERR_PET_NOT_FOUND)))
    (asserts! (is-authorized-for-pet pet-id tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active pet-data) ERR_PET_NOT_FOUND)
    
    (map-set pets
      { pet-id: pet-id }
      (merge pet-data {
        is-active: false,
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)
