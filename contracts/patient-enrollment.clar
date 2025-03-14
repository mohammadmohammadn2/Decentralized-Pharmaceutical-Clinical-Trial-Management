;; Patient Enrollment Contract
;; Manages participant recruitment and consent for clinical trials

;; Define data variables
(define-data-var trial-active bool true)
(define-map patients
  { patient-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    consent-provided: bool,
    enrollment-date: uint,
    status: (string-ascii 20)
  }
)

(define-map trial-admins principal bool)

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-PATIENT-EXISTS u2)
(define-constant ERR-PATIENT-NOT-FOUND u3)
(define-constant ERR-TRIAL-INACTIVE u4)

;; Initialize contract with contract deployer as admin
(define-data-var contract-owner principal tx-sender)

;; Check if caller is an admin
(define-private (is-admin)
  (or
    (is-eq tx-sender (var-get contract-owner))
    (default-to false (map-get? trial-admins tx-sender))
  )
)

;; Add a new admin
(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (ok (map-set trial-admins new-admin true))
  )
)

;; Remove an admin
(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (ok (map-delete trial-admins admin))
  )
)

;; Set trial active status
(define-public (set-trial-active (active bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (ok (var-set trial-active active))
  )
)

;; Enroll a new patient
(define-public (enroll-patient
  (patient-id (string-ascii 36))
  (name (string-ascii 100))
)
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (var-get trial-active) (err ERR-TRIAL-INACTIVE))
    (asserts! (is-none (map-get? patients { patient-id: patient-id })) (err ERR-PATIENT-EXISTS))

    (ok (map-set patients
      { patient-id: patient-id }
      {
        name: name,
        consent-provided: false,
        enrollment-date: block-height,
        status: "enrolled"
      }
    ))
  )
)

;; Record patient consent
(define-public (provide-consent (patient-id (string-ascii 36)))
  (let (
    (patient (unwrap! (map-get? patients { patient-id: patient-id }) (err ERR-PATIENT-NOT-FOUND)))
  )
    (asserts! (var-get trial-active) (err ERR-TRIAL-INACTIVE))

    (ok (map-set patients
      { patient-id: patient-id }
      (merge patient { consent-provided: true })
    ))
  )
)

;; Update patient status
(define-public (update-patient-status
  (patient-id (string-ascii 36))
  (new-status (string-ascii 20))
)
  (let (
    (patient (unwrap! (map-get? patients { patient-id: patient-id }) (err ERR-PATIENT-NOT-FOUND)))
  )
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (var-get trial-active) (err ERR-TRIAL-INACTIVE))

    (ok (map-set patients
      { patient-id: patient-id }
      (merge patient { status: new-status })
    ))
  )
)

;; Read-only function to get patient details
(define-read-only (get-patient (patient-id (string-ascii 36)))
  (map-get? patients { patient-id: patient-id })
)

;; Read-only function to check if trial is active
(define-read-only (is-trial-active)
  (var-get trial-active)
)
