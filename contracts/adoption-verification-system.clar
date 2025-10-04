;; Adoption Verification System Contract
;; Screen potential pet owners and track successful adoptions with follow-up care monitoring

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_APPLICATION_NOT_FOUND (err u201))
(define-constant ERR_APPLICATION_EXISTS (err u202))
(define-constant ERR_INVALID_STATUS (err u203))
(define-constant ERR_INVALID_INPUT (err u204))
(define-constant ERR_ADOPTION_NOT_FOUND (err u205))
(define-constant ERR_AGENCY_NOT_REGISTERED (err u206))

;; Status Constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_UNDER_REVIEW u1)
(define-constant STATUS_APPROVED u2)
(define-constant STATUS_REJECTED u3)
(define-constant STATUS_COMPLETED u4)

;; Data Variables
(define-data-var application-id-nonce uint u0)
(define-data-var adoption-id-nonce uint u0)
(define-data-var total-applications uint u0)
(define-data-var total-successful-adoptions uint u0)

;; Data Maps
(define-map adoption-applications
  { application-id: uint }
  {
    applicant: principal,
    pet-id: uint,
    agency: principal,
    application-date: uint,
    status: uint,
    housing-type: (string-ascii 50),
    experience-level: (string-ascii 20),
    household-size: uint,
    has-other-pets: bool,
    income-verification: bool,
    references: (string-ascii 200),
    reason-for-adoption: (string-ascii 300),
    reviewer: (optional principal),
    review-notes: (string-ascii 500),
    last-updated: uint
  }
)

(define-map adoption-records
  { adoption-id: uint }
  {
    application-id: uint,
    adopter: principal,
    pet-id: uint,
    agency: principal,
    adoption-date: uint,
    follow-up-required: bool,
    follow-up-date: (optional uint),
    follow-up-completed: bool,
    follow-up-notes: (string-ascii 300),
    satisfaction-score: (optional uint),
    is-successful: bool
  }
)

(define-map adoption-agencies
  { agency-address: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    location: (string-ascii 100),
    verified: bool,
    registration-date: uint,
    successful-adoptions: uint,
    total-applications: uint
  }
)

(define-map applicant-history
  { applicant: principal, application-index: uint }
  { application-id: uint }
)

(define-map applicant-application-count
  { applicant: principal }
  { count: uint }
)

(define-map follow-up-schedule
  { adoption-id: uint, follow-up-index: uint }
  {
    scheduled-date: uint,
    completed: bool,
    completion-date: (optional uint),
    notes: (string-ascii 200),
    inspector: (optional principal)
  }
)

;; Private Functions
(define-private (get-next-application-id)
  (let ((current-id (var-get application-id-nonce)))
    (var-set application-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (get-next-adoption-id)
  (let ((current-id (var-get adoption-id-nonce)))
    (var-set adoption-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (increment-applicant-count (applicant principal))
  (let ((current-count (default-to u0 (get count (map-get? applicant-application-count { applicant: applicant })))))
    (map-set applicant-application-count { applicant: applicant } { count: (+ current-count u1) })
    current-count
  )
)

(define-private (is-valid-status (status uint))
  (and (>= status STATUS_PENDING) (<= status STATUS_COMPLETED))
)

(define-private (is-valid-string (input (string-ascii 500)) (max-length uint))
  (and 
    (> (len input) u0)
    (<= (len input) max-length)
  )
)

(define-private (is-authorized-agency (agency principal))
  (match (map-get? adoption-agencies { agency-address: agency })
    agency-data (get verified agency-data)
    false
  )
)

;; Read-Only Functions
(define-read-only (get-application-info (application-id uint))
  (map-get? adoption-applications { application-id: application-id })
)

(define-read-only (get-adoption-record (adoption-id uint))
  (map-get? adoption-records { adoption-id: adoption-id })
)

(define-read-only (get-agency-info (agency-address principal))
  (map-get? adoption-agencies { agency-address: agency-address })
)

(define-read-only (get-applicant-application-count (applicant principal))
  (default-to u0 (get count (map-get? applicant-application-count { applicant: applicant })))
)

(define-read-only (get-applicant-application-by-index (applicant principal) (index uint))
  (map-get? applicant-history { applicant: applicant, application-index: index })
)

(define-read-only (get-follow-up-info (adoption-id uint) (follow-up-index uint))
  (map-get? follow-up-schedule { adoption-id: adoption-id, follow-up-index: follow-up-index })
)

(define-read-only (get-total-applications)
  (var-get total-applications)
)

(define-read-only (get-total-successful-adoptions)
  (var-get total-successful-adoptions)
)

(define-read-only (calculate-success-rate (agency-address principal))
  (match (get-agency-info agency-address)
    agency-data 
      (if (> (get total-applications agency-data) u0)
        (* (/ (get successful-adoptions agency-data) (get total-applications agency-data)) u100)
        u0)
    u0
  )
)

;; Public Functions
(define-public (register-adoption-agency
  (name (string-ascii 100))
  (license-number (string-ascii 50))
  (location (string-ascii 100))
  )
  (asserts! (is-valid-string name u100) ERR_INVALID_INPUT)
  (asserts! (is-valid-string license-number u50) ERR_INVALID_INPUT)
  (asserts! (is-valid-string location u100) ERR_INVALID_INPUT)
  
  (map-set adoption-agencies
    { agency-address: tx-sender }
    {
      name: name,
      license-number: license-number,
      location: location,
      verified: false,
      registration-date: stacks-block-height,
      successful-adoptions: u0,
      total-applications: u0
    }
  )
  
  (ok true)
)

(define-public (verify-adoption-agency (agency-address principal))
  (let ((agency-data (unwrap! (get-agency-info agency-address) ERR_AGENCY_NOT_REGISTERED)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set adoption-agencies
      { agency-address: agency-address }
      (merge agency-data { verified: true })
    )
    
    (ok true)
  )
)

(define-public (submit-adoption-application
  (pet-id uint)
  (agency principal)
  (housing-type (string-ascii 50))
  (experience-level (string-ascii 20))
  (household-size uint)
  (has-other-pets bool)
  (income-verification bool)
  (references (string-ascii 200))
  (reason-for-adoption (string-ascii 300))
  )
  (let (
    (application-id (get-next-application-id))
    (applicant-index (increment-applicant-count tx-sender))
  )
    (asserts! (is-authorized-agency agency) ERR_AGENCY_NOT_REGISTERED)
    (asserts! (is-valid-string housing-type u50) ERR_INVALID_INPUT)
    (asserts! (is-valid-string experience-level u20) ERR_INVALID_INPUT)
    (asserts! (> household-size u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-string reason-for-adoption u300) ERR_INVALID_INPUT)
    
    ;; Create application record
    (map-set adoption-applications
      { application-id: application-id }
      {
        applicant: tx-sender,
        pet-id: pet-id,
        agency: agency,
        application-date: stacks-block-height,
        status: STATUS_PENDING,
        housing-type: housing-type,
        experience-level: experience-level,
        household-size: household-size,
        has-other-pets: has-other-pets,
        income-verification: income-verification,
        references: references,
        reason-for-adoption: reason-for-adoption,
        reviewer: none,
        review-notes: "",
        last-updated: stacks-block-height
      }
    )
    
    ;; Add to applicant history
    (map-set applicant-history { applicant: tx-sender, application-index: applicant-index } { application-id: application-id })
    
    ;; Update agency statistics
    (match (get-agency-info agency)
      agency-data
        (map-set adoption-agencies
          { agency-address: agency }
          (merge agency-data { total-applications: (+ (get total-applications agency-data) u1) })
        )
      false
    )
    
    ;; Increment total applications
    (var-set total-applications (+ (var-get total-applications) u1))
    
    (ok application-id)
  )
)

(define-public (review-application
  (application-id uint)
  (new-status uint)
  (review-notes (string-ascii 500))
  )
  (let ((app-data (unwrap! (get-application-info application-id) ERR_APPLICATION_NOT_FOUND)))
    (asserts! (is-authorized-agency (get agency app-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-valid-status new-status) ERR_INVALID_STATUS)
    (asserts! (not (is-eq (get status app-data) STATUS_COMPLETED)) ERR_INVALID_STATUS)
    
    (map-set adoption-applications
      { application-id: application-id }
      (merge app-data {
        status: new-status,
        reviewer: (some tx-sender),
        review-notes: review-notes,
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)

(define-public (complete-adoption
  (application-id uint)
  (follow-up-required bool)
  (follow-up-date (optional uint))
  )
  (let (
    (app-data (unwrap! (get-application-info application-id) ERR_APPLICATION_NOT_FOUND))
    (adoption-id (get-next-adoption-id))
  )
    (asserts! (is-authorized-agency (get agency app-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status app-data) STATUS_APPROVED) ERR_INVALID_STATUS)
    
    ;; Update application status
    (map-set adoption-applications
      { application-id: application-id }
      (merge app-data {
        status: STATUS_COMPLETED,
        last-updated: stacks-block-height
      })
    )
    
    ;; Create adoption record
    (map-set adoption-records
      { adoption-id: adoption-id }
      {
        application-id: application-id,
        adopter: (get applicant app-data),
        pet-id: (get pet-id app-data),
        agency: (get agency app-data),
        adoption-date: stacks-block-height,
        follow-up-required: follow-up-required,
        follow-up-date: follow-up-date,
        follow-up-completed: false,
        follow-up-notes: "",
        satisfaction-score: none,
        is-successful: true
      }
    )
    
    ;; Update agency successful adoptions
    (match (get-agency-info (get agency app-data))
      agency-data
        (map-set adoption-agencies
          { agency-address: (get agency app-data) }
          (merge agency-data { successful-adoptions: (+ (get successful-adoptions agency-data) u1) })
        )
      false
    )
    
    ;; Increment total successful adoptions
    (var-set total-successful-adoptions (+ (var-get total-successful-adoptions) u1))
    
    (ok adoption-id)
  )
)

(define-public (schedule-follow-up
  (adoption-id uint)
  (follow-up-index uint)
  (scheduled-date uint)
  (inspector principal)
  )
  (let ((adoption-data (unwrap! (get-adoption-record adoption-id) ERR_ADOPTION_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get agency adoption-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (asserts! (get follow-up-required adoption-data) ERR_INVALID_INPUT)
    (asserts! (> scheduled-date stacks-block-height) ERR_INVALID_INPUT)
    
    (map-set follow-up-schedule
      { adoption-id: adoption-id, follow-up-index: follow-up-index }
      {
        scheduled-date: scheduled-date,
        completed: false,
        completion-date: none,
        notes: "",
        inspector: (some inspector)
      }
    )
    
    (ok true)
  )
)

(define-public (complete-follow-up
  (adoption-id uint)
  (follow-up-index uint)
  (notes (string-ascii 200))
  (satisfaction-score uint)
  )
  (let (
    (follow-up-data (unwrap! (get-follow-up-info adoption-id follow-up-index) ERR_ADOPTION_NOT_FOUND))
    (adoption-data (unwrap! (get-adoption-record adoption-id) ERR_ADOPTION_NOT_FOUND))
  )
    (asserts! (or 
      (is-some (get inspector follow-up-data))
      (is-eq tx-sender (get agency adoption-data))
      (is-eq tx-sender CONTRACT_OWNER)
    ) ERR_NOT_AUTHORIZED)
    (asserts! (not (get completed follow-up-data)) ERR_INVALID_STATUS)
    (asserts! (<= satisfaction-score u10) ERR_INVALID_INPUT)
    
    ;; Update follow-up record
    (map-set follow-up-schedule
      { adoption-id: adoption-id, follow-up-index: follow-up-index }
      (merge follow-up-data {
        completed: true,
        completion-date: (some stacks-block-height),
        notes: notes
      })
    )
    
    ;; Update adoption record
    (map-set adoption-records
      { adoption-id: adoption-id }
      (merge adoption-data {
        follow-up-completed: true,
        follow-up-notes: notes,
        satisfaction-score: (some satisfaction-score),
        is-successful: (>= satisfaction-score u7)
      })
    )
    
    (ok true)
  )
)
