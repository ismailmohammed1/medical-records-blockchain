;; Medical Records Blockchain Platform - Health Records Contract
;; A comprehensive medical records management system with patient-controlled access

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-patient-not-found (err u104))
(define-constant err-provider-not-verified (err u105))
(define-constant err-access-denied (err u106))
(define-constant err-already-exists (err u107))

;; Data Variables
(define-data-var next-patient-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var next-provider-id uint u1)
(define-data-var emergency-mode bool false)

;; Data Maps - Patient Management
(define-map patients
  { patient-id: uint }
  {
    owner: principal,
    encrypted-personal-info: (buff 512),
    date-registered: uint,
    active: bool,
    privacy-level: uint  ;; 1=private, 2=limited, 3=open
  }
)

(define-map patient-by-principal
  { owner: principal }
  { patient-id: uint }
)

;; Medical Records Storage
(define-map medical-records
  { record-id: uint }
  {
    patient-id: uint,
    provider-id: uint,
    record-type: (string-ascii 50),
    encrypted-data-hash: (buff 32),
    timestamp: uint,
    severity: uint,  ;; 1=low, 2=medium, 3=high, 4=critical
    emergency-accessible: bool,
    archived: bool
  }
)

;; Patient Records Index
(define-map patient-records
  { patient-id: uint }
  { record-ids: (list 50 uint), total-records: uint }
)

;; Healthcare Provider Registry
(define-map healthcare-providers
  { provider-id: uint }
  {
    principal: principal,
    name: (string-ascii 100),
    specialty: (string-ascii 50),
    license-number: (string-ascii 50),
    verified: bool,
    active: bool
  }
)

(define-map provider-by-principal
  { principal: principal }
  { provider-id: uint }
)

;; Access Control Management
(define-map patient-provider-permissions
  { patient-id: uint, provider-id: uint }
  {
    access-level: uint,  ;; 1=read, 2=write, 3=full
    granted-date: uint,
    active: bool
  }
)

;; ========================================
;; PATIENT MANAGEMENT FUNCTIONS
;; ========================================

;; Register a new patient
(define-public (register-patient 
  (encrypted-personal-info (buff 512))
  (privacy-level uint))
  (let ((patient-id (var-get next-patient-id)))
    (asserts! (and (> privacy-level u0) (<= privacy-level u3)) err-invalid-input)
    (asserts! (is-none (map-get? patient-by-principal { owner: tx-sender })) err-already-exists)
    
    (map-set patients
      { patient-id: patient-id }
      {
        owner: tx-sender,
        encrypted-personal-info: encrypted-personal-info,
        date-registered: stacks-block-height,
        active: true,
        privacy-level: privacy-level
      })
    
    (map-set patient-by-principal
      { owner: tx-sender }
      { patient-id: patient-id })
    
    (map-set patient-records
      { patient-id: patient-id }
      { record-ids: (list), total-records: u0 })
    
    (var-set next-patient-id (+ patient-id u1))
    (ok patient-id)))

;; Update patient information
(define-public (update-patient-info
  (patient-id uint)
  (encrypted-personal-info (buff 512))
  (privacy-level uint))
  (let ((patient (unwrap! (map-get? patients { patient-id: patient-id }) err-patient-not-found)))
    (asserts! (is-eq tx-sender (get owner patient)) err-unauthorized)
    (asserts! (and (> privacy-level u0) (<= privacy-level u3)) err-invalid-input)
    
    (map-set patients
      { patient-id: patient-id }
      (merge patient {
        encrypted-personal-info: encrypted-personal-info,
        privacy-level: privacy-level
      }))
    
    (ok true)))

;; ========================================
;; PROVIDER MANAGEMENT FUNCTIONS
;; ========================================

;; Register healthcare provider
(define-public (register-provider
  (name (string-ascii 100))
  (specialty (string-ascii 50))
  (license-number (string-ascii 50)))
  (let ((provider-id (var-get next-provider-id)))
    (asserts! (is-none (map-get? provider-by-principal { principal: tx-sender })) err-already-exists)
    
    (map-set healthcare-providers
      { provider-id: provider-id }
      {
        principal: tx-sender,
        name: name,
        specialty: specialty,
        license-number: license-number,
        verified: false,
        active: true
      })
    
    (map-set provider-by-principal
      { principal: tx-sender }
      { provider-id: provider-id })
    
    (var-set next-provider-id (+ provider-id u1))
    (ok provider-id)))

;; Verify provider credentials (admin only)
(define-public (verify-provider (provider-id uint) (verified bool))
  (let ((provider (unwrap! (map-get? healthcare-providers { provider-id: provider-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set healthcare-providers
      { provider-id: provider-id }
      (merge provider { verified: verified }))
    
    (ok true)))

;; ========================================
;; MEDICAL RECORDS FUNCTIONS
;; ========================================

;; Create new medical record
(define-public (create-medical-record
  (patient-id uint)
  (record-type (string-ascii 50))
  (encrypted-data-hash (buff 32))
  (severity uint)
  (emergency-accessible bool))
  (let (
    (record-id (var-get next-record-id))
    (provider-data (unwrap! (map-get? provider-by-principal { principal: tx-sender }) err-provider-not-verified))
    (provider-id (get provider-id provider-data))
    (provider (unwrap! (map-get? healthcare-providers { provider-id: provider-id }) err-provider-not-verified))
    (patient-records-data (unwrap! (map-get? patient-records { patient-id: patient-id }) err-patient-not-found))
  )
    (asserts! (get verified provider) err-provider-not-verified)
    (asserts! (get active provider) err-provider-not-verified)
    (asserts! (and (> severity u0) (<= severity u4)) err-invalid-input)
    
    ;; Check if provider has write access
    (let ((permission (map-get? patient-provider-permissions { patient-id: patient-id, provider-id: provider-id })))
      (asserts! (is-some permission) err-access-denied)
      (let ((perm (unwrap-panic permission)))
        (asserts! (and (get active perm) (>= (get access-level perm) u2)) err-access-denied)))
    
    ;; Create the medical record
    (map-set medical-records
      { record-id: record-id }
      {
        patient-id: patient-id,
        provider-id: provider-id,
        record-type: record-type,
        encrypted-data-hash: encrypted-data-hash,
        timestamp: stacks-block-height,
        severity: severity,
        emergency-accessible: emergency-accessible,
        archived: false
      })
    
    ;; Update patient records index
    (let ((updated-record-ids (unwrap! (as-max-len? (append (get record-ids patient-records-data) record-id) u50) err-invalid-input)))
      (map-set patient-records
        { patient-id: patient-id }
        {
          record-ids: updated-record-ids,
          total-records: (+ (get total-records patient-records-data) u1)
        }))
    
    (var-set next-record-id (+ record-id u1))
    (ok record-id)))

;; Archive medical record
(define-public (archive-record (record-id uint))
  (let (
    (record (unwrap! (map-get? medical-records { record-id: record-id }) err-not-found))
    (patient (unwrap! (map-get? patients { patient-id: (get patient-id record) }) err-patient-not-found))
  )
    (asserts! (is-eq tx-sender (get owner patient)) err-unauthorized)
    
    (map-set medical-records
      { record-id: record-id }
      (merge record { archived: true }))
    
    (ok true)))

;; ========================================
;; ACCESS CONTROL FUNCTIONS
;; ========================================

;; Grant provider access to patient records
(define-public (grant-provider-access
  (provider-id uint)
  (access-level uint))
  (let (
    (patient-data (unwrap! (map-get? patient-by-principal { owner: tx-sender }) err-patient-not-found))
    (patient-id (get patient-id patient-data))
    (provider (unwrap! (map-get? healthcare-providers { provider-id: provider-id }) err-provider-not-verified))
  )
    (asserts! (get verified provider) err-provider-not-verified)
    (asserts! (get active provider) err-provider-not-verified)
    (asserts! (and (> access-level u0) (<= access-level u3)) err-invalid-input)
    
    (map-set patient-provider-permissions
      { patient-id: patient-id, provider-id: provider-id }
      {
        access-level: access-level,
        granted-date: stacks-block-height,
        active: true
      })
    
    (ok true)))

;; Revoke provider access
(define-public (revoke-provider-access (provider-id uint))
  (let (
    (patient-data (unwrap! (map-get? patient-by-principal { owner: tx-sender }) err-patient-not-found))
    (patient-id (get patient-id patient-data))
    (permission (unwrap! (map-get? patient-provider-permissions { patient-id: patient-id, provider-id: provider-id }) err-not-found))
  )
    (map-set patient-provider-permissions
      { patient-id: patient-id, provider-id: provider-id }
      (merge permission { active: false }))
    
    (ok true)))

;; ========================================
;; QUERY FUNCTIONS
;; ========================================

;; Get patient records
(define-read-only (get-patient-records (patient-id uint))
  (let (
    (patient-records-data (unwrap! (map-get? patient-records { patient-id: patient-id }) err-patient-not-found))
    (patient (unwrap! (map-get? patients { patient-id: patient-id }) err-patient-not-found))
  )
    ;; Only allow the patient to view their own records
    (asserts! (is-eq tx-sender (get owner patient)) err-unauthorized)
    (ok (get record-ids patient-records-data))))

;; Get medical record details
(define-read-only (get-medical-record (record-id uint))
  (let (
    (record (unwrap! (map-get? medical-records { record-id: record-id }) err-not-found))
    (patient (unwrap! (map-get? patients { patient-id: (get patient-id record) }) err-patient-not-found))
  )
    ;; Check if caller is the patient or has access
    (if (is-eq tx-sender (get owner patient))
      (ok record)
      (let (
        (provider-data (map-get? provider-by-principal { principal: tx-sender }))
      )
        (if (is-some provider-data)
          (let ((provider-id (get provider-id (unwrap-panic provider-data))))
            (let ((permission (map-get? patient-provider-permissions { patient-id: (get patient-id record), provider-id: provider-id })))
              (if (and (is-some permission) (get active (unwrap-panic permission)))
                (ok record)
                err-access-denied)))
          err-access-denied)))))

;; Get patient information (public basic info only)
(define-read-only (get-patient-info (patient-id uint))
  (let ((patient (map-get? patients { patient-id: patient-id })))
    (if (is-some patient)
      (let ((patient-data (unwrap-panic patient)))
        (ok {
          patient-id: patient-id,
          owner: (get owner patient-data),
          date-registered: (get date-registered patient-data),
          active: (get active patient-data),
          privacy-level: (get privacy-level patient-data)
        }))
      err-not-found)))

;; Get provider information
(define-read-only (get-provider-info (provider-id uint))
  (map-get? healthcare-providers { provider-id: provider-id }))

;; Get access permissions
(define-read-only (get-access-permissions (patient-id uint) (provider-id uint))
  (map-get? patient-provider-permissions { patient-id: patient-id, provider-id: provider-id }))

;; ========================================
;; ADMIN FUNCTIONS
;; ========================================

;; Toggle emergency mode
(define-public (toggle-emergency-mode (enabled bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set emergency-mode enabled)
    (ok true)))

;; Get contract statistics
(define-read-only (get-contract-stats)
  (ok {
    total-patients: (- (var-get next-patient-id) u1),
    total-records: (- (var-get next-record-id) u1),
    total-providers: (- (var-get next-provider-id) u1),
    emergency-mode: (var-get emergency-mode)
  }))
