;; Veterinary Care Tracking Contract
;; Track vaccinations, medical treatments, and wellness checkups with veterinary provider verification

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_RECORD_NOT_FOUND (err u301))
(define-constant ERR_RECORD_EXISTS (err u302))
(define-constant ERR_INVALID_INPUT (err u303))
(define-constant ERR_VET_NOT_VERIFIED (err u304))
(define-constant ERR_APPOINTMENT_NOT_FOUND (err u305))
(define-constant ERR_INVALID_DATE (err u306))

;; Treatment Types
(define-constant TYPE_VACCINATION u0)
(define-constant TYPE_CHECKUP u1)
(define-constant TYPE_TREATMENT u2)
(define-constant TYPE_SURGERY u3)
(define-constant TYPE_EMERGENCY u4)

;; Appointment Status
(define-constant APPOINTMENT_SCHEDULED u0)
(define-constant APPOINTMENT_COMPLETED u1)
(define-constant APPOINTMENT_CANCELLED u2)
(define-constant APPOINTMENT_NO_SHOW u3)

;; Data Variables
(define-data-var medical-record-id-nonce uint u0)
(define-data-var appointment-id-nonce uint u0)
(define-data-var vaccination-schedule-id-nonce uint u0)
(define-data-var total-medical-records uint u0)
(define-data-var total-appointments uint u0)

;; Data Maps
(define-map medical-records
  { record-id: uint }
  {
    pet-id: uint,
    veterinarian: principal,
    clinic: (string-ascii 100),
    treatment-type: uint,
    treatment-date: uint,
    diagnosis: (string-ascii 300),
    treatment-description: (string-ascii 500),
    medications: (string-ascii 200),
    follow-up-required: bool,
    follow-up-date: (optional uint),
    cost: uint,
    verified: bool,
    created-date: uint,
    last-updated: uint
  }
)

(define-map vaccination-records
  { pet-id: uint, vaccine-type: (string-ascii 50) }
  {
    doses-given: uint,
    last-vaccination-date: uint,
    next-due-date: uint,
    veterinarian: principal,
    batch-number: (string-ascii 50),
    manufacturer: (string-ascii 100),
    is-current: bool,
    record-id: uint
  }
)

(define-map veterinary-appointments
  { appointment-id: uint }
  {
    pet-id: uint,
    owner: principal,
    veterinarian: principal,
    clinic: (string-ascii 100),
    appointment-date: uint,
    appointment-type: uint,
    status: uint,
    reason: (string-ascii 200),
    notes: (string-ascii 300),
    estimated-cost: uint,
    actual-cost: (optional uint),
    created-date: uint,
    last-updated: uint
  }
)

(define-map wellness-tracking
  { pet-id: uint, check-type: (string-ascii 30) }
  {
    last-check-date: uint,
    next-check-due: uint,
    frequency-months: uint,
    veterinarian: principal,
    result-status: (string-ascii 20),
    notes: (string-ascii 200),
    is-overdue: bool
  }
)

(define-map pet-health-summary
  { pet-id: uint }
  {
    total-visits: uint,
    last-visit-date: uint,
    vaccination-status: (string-ascii 20),
    health-status: (string-ascii 20),
    chronic-conditions: (string-ascii 300),
    allergies: (string-ascii 200),
    current-medications: (string-ascii 300),
    emergency-contact: (optional principal),
    last-updated: uint
  }
)

(define-map veterinarian-credentials
  { vet-address: principal }
  {
    license-number: (string-ascii 50),
    clinic-name: (string-ascii 100),
    specialization: (string-ascii 100),
    verified: bool,
    verification-date: (optional uint),
    total-patients: uint,
    registration-date: uint
  }
)

(define-map pet-medical-history
  { pet-id: uint, record-index: uint }
  { record-id: uint }
)

(define-map pet-record-count
  { pet-id: uint }
  { count: uint }
)

;; Private Functions
(define-private (get-next-record-id)
  (let ((current-id (var-get medical-record-id-nonce)))
    (var-set medical-record-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (get-next-appointment-id)
  (let ((current-id (var-get appointment-id-nonce)))
    (var-set appointment-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (increment-pet-record-count (pet-id uint))
  (let ((current-count (default-to u0 (get count (map-get? pet-record-count { pet-id: pet-id })))))
    (map-set pet-record-count { pet-id: pet-id } { count: (+ current-count u1) })
    current-count
  )
)

(define-private (is-valid-treatment-type (treatment-type uint))
  (and (>= treatment-type TYPE_VACCINATION) (<= treatment-type TYPE_EMERGENCY))
)

(define-private (is-valid-appointment-status (status uint))
  (and (>= status APPOINTMENT_SCHEDULED) (<= status APPOINTMENT_NO_SHOW))
)

(define-private (is-verified-veterinarian (vet-address principal))
  (match (map-get? veterinarian-credentials { vet-address: vet-address })
    vet-data (get verified vet-data)
    false
  )
)

(define-private (is-valid-string (input (string-ascii 500)) (max-length uint))
  (and 
    (> (len input) u0)
    (<= (len input) max-length)
  )
)

;; Read-Only Functions
(define-read-only (get-medical-record (record-id uint))
  (map-get? medical-records { record-id: record-id })
)

(define-read-only (get-pet-health-summary (pet-id uint))
  (map-get? pet-health-summary { pet-id: pet-id })
)

(define-read-only (get-vaccination-record (pet-id uint) (vaccine-type (string-ascii 50)))
  (map-get? vaccination-records { pet-id: pet-id, vaccine-type: vaccine-type })
)

(define-read-only (get-appointment-info (appointment-id uint))
  (map-get? veterinary-appointments { appointment-id: appointment-id })
)

(define-read-only (get-wellness-tracking (pet-id uint) (check-type (string-ascii 30)))
  (map-get? wellness-tracking { pet-id: pet-id, check-type: check-type })
)

(define-read-only (get-veterinarian-credentials (vet-address principal))
  (map-get? veterinarian-credentials { vet-address: vet-address })
)

(define-read-only (get-pet-record-count (pet-id uint))
  (default-to u0 (get count (map-get? pet-record-count { pet-id: pet-id })))
)

(define-read-only (get-pet-medical-record-by-index (pet-id uint) (index uint))
  (map-get? pet-medical-history { pet-id: pet-id, record-index: index })
)

(define-read-only (get-total-medical-records)
  (var-get total-medical-records)
)

(define-read-only (get-total-appointments)
  (var-get total-appointments)
)

(define-read-only (is-vaccination-current (pet-id uint) (vaccine-type (string-ascii 50)))
  (match (get-vaccination-record pet-id vaccine-type)
    vaccine-data 
      (and 
        (get is-current vaccine-data)
        (> (get next-due-date vaccine-data) stacks-block-height)
      )
    false
  )
)

;; Public Functions
(define-public (register-veterinarian
  (license-number (string-ascii 50))
  (clinic-name (string-ascii 100))
  (specialization (string-ascii 100))
  )
  (asserts! (is-valid-string license-number u50) ERR_INVALID_INPUT)
  (asserts! (is-valid-string clinic-name u100) ERR_INVALID_INPUT)
  (asserts! (is-valid-string specialization u100) ERR_INVALID_INPUT)
  
  (map-set veterinarian-credentials
    { vet-address: tx-sender }
    {
      license-number: license-number,
      clinic-name: clinic-name,
      specialization: specialization,
      verified: false,
      verification-date: none,
      total-patients: u0,
      registration-date: stacks-block-height
    }
  )
  
  (ok true)
)

(define-public (verify-veterinarian (vet-address principal))
  (let ((vet-data (unwrap! (get-veterinarian-credentials vet-address) ERR_RECORD_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set veterinarian-credentials
      { vet-address: vet-address }
      (merge vet-data {
        verified: true,
        verification-date: (some stacks-block-height)
      })
    )
    
    (ok true)
  )
)

(define-public (add-medical-record
  (pet-id uint)
  (clinic (string-ascii 100))
  (treatment-type uint)
  (diagnosis (string-ascii 300))
  (treatment-description (string-ascii 500))
  (medications (string-ascii 200))
  (follow-up-required bool)
  (follow-up-date (optional uint))
  (cost uint)
  )
  (let (
    (record-id (get-next-record-id))
    (record-index (increment-pet-record-count pet-id))
  )
    (asserts! (is-verified-veterinarian tx-sender) ERR_VET_NOT_VERIFIED)
    (asserts! (is-valid-treatment-type treatment-type) ERR_INVALID_INPUT)
    (asserts! (is-valid-string diagnosis u300) ERR_INVALID_INPUT)
    (asserts! (is-valid-string treatment-description u500) ERR_INVALID_INPUT)
    
    ;; Create medical record
    (map-set medical-records
      { record-id: record-id }
      {
        pet-id: pet-id,
        veterinarian: tx-sender,
        clinic: clinic,
        treatment-type: treatment-type,
        treatment-date: stacks-block-height,
        diagnosis: diagnosis,
        treatment-description: treatment-description,
        medications: medications,
        follow-up-required: follow-up-required,
        follow-up-date: follow-up-date,
        cost: cost,
        verified: true,
        created-date: stacks-block-height,
        last-updated: stacks-block-height
      }
    )
    
    ;; Add to pet's medical history
    (map-set pet-medical-history { pet-id: pet-id, record-index: record-index } { record-id: record-id })
    
    ;; Update pet health summary
    (match (get-pet-health-summary pet-id)
      health-data
        (map-set pet-health-summary
          { pet-id: pet-id }
          (merge health-data {
            total-visits: (+ (get total-visits health-data) u1),
            last-visit-date: stacks-block-height,
            last-updated: stacks-block-height
          })
        )
      ;; Create new health summary if none exists
      (map-set pet-health-summary
        { pet-id: pet-id }
        {
          total-visits: u1,
          last-visit-date: stacks-block-height,
          vaccination-status: "unknown",
          health-status: "active",
          chronic-conditions: "",
          allergies: "",
          current-medications: medications,
          emergency-contact: none,
          last-updated: stacks-block-height
        }
      )
    )
    
    ;; Increment totals
    (var-set total-medical-records (+ (var-get total-medical-records) u1))
    
    (ok record-id)
  )
)

(define-public (add-vaccination-record
  (pet-id uint)
  (vaccine-type (string-ascii 50))
  (batch-number (string-ascii 50))
  (manufacturer (string-ascii 100))
  (next-due-months uint)
  )
  (let ((record-id (get-next-record-id)))
    (asserts! (is-verified-veterinarian tx-sender) ERR_VET_NOT_VERIFIED)
    (asserts! (is-valid-string vaccine-type u50) ERR_INVALID_INPUT)
    (asserts! (is-valid-string batch-number u50) ERR_INVALID_INPUT)
    (asserts! (> next-due-months u0) ERR_INVALID_INPUT)
    
    ;; Get current vaccination record or create new
    (let (
      (current-record (map-get? vaccination-records { pet-id: pet-id, vaccine-type: vaccine-type }))
      (doses-count (match current-record record (+ (get doses-given record) u1) u1))
      (next-due-date (+ stacks-block-height (* next-due-months u144))) ;; Approximate blocks per month
    )
      (map-set vaccination-records
        { pet-id: pet-id, vaccine-type: vaccine-type }
        {
          doses-given: doses-count,
          last-vaccination-date: stacks-block-height,
          next-due-date: next-due-date,
          veterinarian: tx-sender,
          batch-number: batch-number,
          manufacturer: manufacturer,
          is-current: true,
          record-id: record-id
        }
      )
      
      ;; Update pet health summary vaccination status
      (match (get-pet-health-summary pet-id)
        health-data
          (map-set pet-health-summary
            { pet-id: pet-id }
            (merge health-data {
              vaccination-status: "current",
              last-updated: stacks-block-height
            })
          )
        false
      )
      
      (ok record-id)
    )
  )
)

(define-public (schedule-appointment
  (pet-id uint)
  (owner principal)
  (clinic (string-ascii 100))
  (appointment-date uint)
  (appointment-type uint)
  (reason (string-ascii 200))
  (estimated-cost uint)
  )
  (let ((appointment-id (get-next-appointment-id)))
    (asserts! (is-verified-veterinarian tx-sender) ERR_VET_NOT_VERIFIED)
    (asserts! (is-valid-treatment-type appointment-type) ERR_INVALID_INPUT)
    (asserts! (> appointment-date stacks-block-height) ERR_INVALID_DATE)
    (asserts! (is-valid-string reason u200) ERR_INVALID_INPUT)
    
    (map-set veterinary-appointments
      { appointment-id: appointment-id }
      {
        pet-id: pet-id,
        owner: owner,
        veterinarian: tx-sender,
        clinic: clinic,
        appointment-date: appointment-date,
        appointment-type: appointment-type,
        status: APPOINTMENT_SCHEDULED,
        reason: reason,
        notes: "",
        estimated-cost: estimated-cost,
        actual-cost: none,
        created-date: stacks-block-height,
        last-updated: stacks-block-height
      }
    )
    
    (var-set total-appointments (+ (var-get total-appointments) u1))
    
    (ok appointment-id)
  )
)

(define-public (update-appointment-status
  (appointment-id uint)
  (new-status uint)
  (notes (string-ascii 300))
  (actual-cost (optional uint))
  )
  (let ((appointment-data (unwrap! (get-appointment-info appointment-id) ERR_APPOINTMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get veterinarian appointment-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-valid-appointment-status new-status) ERR_INVALID_INPUT)
    
    (map-set veterinary-appointments
      { appointment-id: appointment-id }
      (merge appointment-data {
        status: new-status,
        notes: notes,
        actual-cost: actual-cost,
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)

(define-public (update-wellness-tracking
  (pet-id uint)
  (check-type (string-ascii 30))
  (frequency-months uint)
  (result-status (string-ascii 20))
  (notes (string-ascii 200))
  )
  (let ((next-due (+ stacks-block-height (* frequency-months u144))))
    (asserts! (is-verified-veterinarian tx-sender) ERR_VET_NOT_VERIFIED)
    (asserts! (is-valid-string check-type u30) ERR_INVALID_INPUT)
    (asserts! (> frequency-months u0) ERR_INVALID_INPUT)
    
    (map-set wellness-tracking
      { pet-id: pet-id, check-type: check-type }
      {
        last-check-date: stacks-block-height,
        next-check-due: next-due,
        frequency-months: frequency-months,
        veterinarian: tx-sender,
        result-status: result-status,
        notes: notes,
        is-overdue: false
      }
    )
    
    (ok true)
  )
)

(define-public (update-pet-health-summary
  (pet-id uint)
  (health-status (string-ascii 20))
  (chronic-conditions (string-ascii 300))
  (allergies (string-ascii 200))
  (current-medications (string-ascii 300))
  (emergency-contact (optional principal))
  )
  (let ((health-data (unwrap! (get-pet-health-summary pet-id) ERR_RECORD_NOT_FOUND)))
    (asserts! (is-verified-veterinarian tx-sender) ERR_VET_NOT_VERIFIED)
    
    (map-set pet-health-summary
      { pet-id: pet-id }
      (merge health-data {
        health-status: health-status,
        chronic-conditions: chronic-conditions,
        allergies: allergies,
        current-medications: current-medications,
        emergency-contact: emergency-contact,
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)
