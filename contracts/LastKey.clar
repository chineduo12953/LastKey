
;; title: LastKey
;; version:
;; summary:
;; description:
;;   This contract provides a simple way to store and retrieve the last key



(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PERIOD (err u103))
(define-constant ERR_NOT_EXPIRED (err u104))
(define-constant ERR_ALREADY_RELEASED (err u105))
(define-constant ERR_VERSION_NOT_FOUND (err u106))
(define-constant ERR_INVALID_VERSION (err u107))
(define-constant ERR_VERSION_LIMIT_EXCEEDED (err u108))
(define-constant ERR_SAME_VERSION (err u109))
(define-constant ERR_BENEFICIARY_NOT_FOUND (err u110))
(define-constant ERR_BENEFICIARY_ALREADY_EXISTS (err u111))
(define-constant ERR_INVALID_WEIGHT (err u112))
(define-constant ERR_MAX_BENEFICIARIES_EXCEEDED (err u113))
(define-constant ERR_INSUFFICIENT_ACCESS_LEVEL (err u114))
(define-constant ERR_RECOVERY_NOT_ENABLED (err u115))
(define-constant ERR_ALREADY_GUARDIAN (err u116))
(define-constant ERR_NOT_GUARDIAN (err u117))
(define-constant ERR_MAX_GUARDIANS_EXCEEDED (err u118))
(define-constant ERR_THRESHOLD_TOO_HIGH (err u119))
(define-constant ERR_THRESHOLD_TOO_LOW (err u120))
(define-constant ERR_RECOVERY_ALREADY_ACTIVE (err u121))
(define-constant ERR_NO_ACTIVE_RECOVERY (err u122))
(define-constant ERR_ALREADY_SIGNED (err u123))
(define-constant ERR_INSUFFICIENT_SIGNATURES (err u124))
(define-constant ERR_RECOVERY_EXPIRED (err u125))
(define-constant ERR_CANNOT_REMOVE_SELF (err u126))

(define-map switches
  { owner: principal }
  {
    last-checkin: uint,
    inactivity-period: uint,
    beneficiary: principal,
    document-hash: (string-ascii 64),
    is-released: bool,
    created-at: uint
  }
)

(define-map released-documents
  { switch-id: principal }
  {
    document-hash: (string-ascii 64),
    released-at: uint,
    beneficiary: principal
  }
)

(define-data-var total-switches uint u0)
(define-data-var max-versions-per-switch uint u50)
(define-data-var max-guardians-per-switch uint u10)
(define-data-var recovery-period uint u604800)

(define-map document-versions
  { owner: principal, version: uint }
  {
    document-hash: (string-ascii 64),
    version-name: (string-ascii 32),
    created-at: uint,
    description: (string-ascii 128),
    is-active: bool
  }
)

(define-map version-metadata
  { owner: principal }
  {
    current-version: uint,
    total-versions: uint,
    active-version: uint
  }
)

(define-map recovery-settings
  { owner: principal }
  {
    is-enabled: bool,
    threshold: uint,
    guardian-count: uint
  }
)

(define-map guardians
  { owner: principal, guardian: principal }
  {
    is-active: bool,
    added-at: uint,
    added-by: principal
  }
)

(define-map recovery-proposals
  { owner: principal, proposal-id: uint }
  {
    initiated-by: principal,
    initiated-at: uint,
    expires-at: uint,
    action-type: (string-ascii 32),
    new-beneficiary: (optional principal),
    new-document-hash: (optional (string-ascii 64)),
    new-inactivity-period: (optional uint),
    signature-count: uint,
    is-executed: bool
  }
)

(define-map recovery-signatures
  { owner: principal, proposal-id: uint, guardian: principal }
  {
    signed-at: uint
  }
)

(define-map recovery-metadata
  { owner: principal }
  {
    current-proposal-id: uint,
    total-proposals: uint
  }
)

(define-read-only (get-switch (owner principal))
  (map-get? switches { owner: owner })
)

(define-read-only (get-released-document (switch-id principal))
  (map-get? released-documents { switch-id: switch-id })
)

(define-read-only (is-switch-expired (owner principal))
  (match (map-get? switches { owner: owner })
    switch-data
    (let
      (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (expiry-time (+ (get last-checkin switch-data) (get inactivity-period switch-data)))
      )
      (>= current-time expiry-time)
    )
    false
  )
)

(define-read-only (get-time-until-expiry (owner principal))
  (match (map-get? switches { owner: owner })
    switch-data
    (let
      (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (expiry-time (+ (get last-checkin switch-data) (get inactivity-period switch-data)))
      )
      (if (>= current-time expiry-time)
        u0
        (- expiry-time current-time)
      )
    )
    u0
  )
)

(define-read-only (get-total-switches)
  (var-get total-switches)
)

(define-read-only (get-document-version (owner principal) (version uint))
  (map-get? document-versions { owner: owner, version: version })
)

(define-read-only (get-version-metadata (owner principal))
  (map-get? version-metadata { owner: owner })
)

(define-read-only (get-active-document-version (owner principal))
  (match (map-get? version-metadata { owner: owner })
    metadata
    (map-get? document-versions { owner: owner, version: (get active-version metadata) })
    none
  )
)

(define-read-only (get-all-versions-for-switch (owner principal))
  (match (map-get? version-metadata { owner: owner })
    metadata
    (let
      (
        (total (get total-versions metadata))
        (active (get active-version metadata))
      )
      (ok {
        total-versions: total,
        active-version: active,
        current-version: (get current-version metadata)
      })
    )
    ERR_NOT_FOUND
  )
)

(define-read-only (is-version-active (owner principal) (version uint))
  (match (map-get? document-versions { owner: owner, version: version })
    version-data
    (get is-active version-data)
    false
  )
)

(define-read-only (get-recovery-settings (owner principal))
  (map-get? recovery-settings { owner: owner })
)

(define-read-only (get-guardian (owner principal) (guardian principal))
  (map-get? guardians { owner: owner, guardian: guardian })
)

(define-read-only (get-recovery-proposal (owner principal) (proposal-id uint))
  (map-get? recovery-proposals { owner: owner, proposal-id: proposal-id })
)

(define-read-only (get-recovery-signature (owner principal) (proposal-id uint) (guardian principal))
  (map-get? recovery-signatures { owner: owner, proposal-id: proposal-id, guardian: guardian })
)

(define-read-only (get-recovery-metadata (owner principal))
  (map-get? recovery-metadata { owner: owner })
)

(define-read-only (is-guardian (owner principal) (guardian principal))
  (match (map-get? guardians { owner: owner, guardian: guardian })
    guardian-data
    (get is-active guardian-data)
    false
  )
)

(define-public (create-switch (beneficiary principal) (document-hash (string-ascii 64)) (inactivity-period uint))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (> inactivity-period u0) ERR_INVALID_PERIOD)
    (asserts! (is-none (map-get? switches { owner: tx-sender })) ERR_ALREADY_EXISTS)
    (map-set switches
      { owner: tx-sender }
      {
        last-checkin: current-time,
        inactivity-period: inactivity-period,
        beneficiary: beneficiary,
        document-hash: document-hash,
        is-released: false,
        created-at: current-time
      }
    )
    (map-set version-metadata
      { owner: tx-sender }
      {
        current-version: u1,
        total-versions: u1,
        active-version: u1
      }
    )
    (map-set document-versions
      { owner: tx-sender, version: u1 }
      {
        document-hash: document-hash,
        version-name: "initial",
        created-at: current-time,
        description: "Initial document version",
        is-active: true
      }
    )
    (var-set total-switches (+ (var-get total-switches) u1))
    (ok true)
  )
)

(define-public (checkin)
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? switches { owner: tx-sender })
      switch-data
      (begin
        (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
        (map-set switches
          { owner: tx-sender }
          (merge switch-data { last-checkin: current-time })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (update-beneficiary (new-beneficiary principal))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (map-set switches
        { owner: tx-sender }
        (merge switch-data { beneficiary: new-beneficiary })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (update-document (new-document-hash (string-ascii 64)))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (map-set switches
        { owner: tx-sender }
        (merge switch-data { document-hash: new-document-hash })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (update-inactivity-period (new-period uint))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (> new-period u0) ERR_INVALID_PERIOD)
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (map-set switches
        { owner: tx-sender }
        (merge switch-data { inactivity-period: new-period })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (release-document (owner principal))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? switches { owner: owner })
      switch-data
      (let
        (
          (expiry-time (+ (get last-checkin switch-data) (get inactivity-period switch-data)))
        )
        (asserts! (>= current-time expiry-time) ERR_NOT_EXPIRED)
        (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
        (map-set switches
          { owner: owner }
          (merge switch-data { is-released: true })
        )
        (map-set released-documents
          { switch-id: owner }
          {
            document-hash: (get document-hash switch-data),
            released-at: current-time,
            beneficiary: (get beneficiary switch-data)
          }
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (create-document-version (document-hash (string-ascii 64)) (version-name (string-ascii 32)) (description (string-ascii 128)))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? switches { owner: tx-sender })
      switch-data
      (begin
        (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
        (match (map-get? version-metadata { owner: tx-sender })
          metadata
          (let
            (
              (next-version (+ (get current-version metadata) u1))
              (max-versions (var-get max-versions-per-switch))
            )
            (asserts! (<= next-version max-versions) ERR_VERSION_LIMIT_EXCEEDED)
            (map-set version-metadata
              { owner: tx-sender }
              (merge metadata { 
                current-version: next-version,
                total-versions: (+ (get total-versions metadata) u1)
              })
            )
            (map-set document-versions
              { owner: tx-sender, version: next-version }
              {
                document-hash: document-hash,
                version-name: version-name,
                created-at: current-time,
                description: description,
                is-active: false
              }
            )
            (ok next-version)
          )
          ERR_NOT_FOUND
        )
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (activate-version (version uint))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (match (map-get? document-versions { owner: tx-sender, version: version })
        version-data
        (match (map-get? version-metadata { owner: tx-sender })
          metadata
          (let
            (
              (old-active-version (get active-version metadata))
            )
            (asserts! (not (is-eq version old-active-version)) ERR_SAME_VERSION)
            (map-set version-metadata
              { owner: tx-sender }
              (merge metadata { active-version: version })
            )
            (map-set document-versions
              { owner: tx-sender, version: old-active-version }
              (merge (unwrap-panic (map-get? document-versions { owner: tx-sender, version: old-active-version })) { is-active: false })
            )
            (map-set document-versions
              { owner: tx-sender, version: version }
              (merge version-data { is-active: true })
            )
            (map-set switches
              { owner: tx-sender }
              (merge switch-data { document-hash: (get document-hash version-data) })
            )
            (ok version)
          )
          ERR_NOT_FOUND
        )
        ERR_VERSION_NOT_FOUND
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (rollback-to-version (version uint))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (match (map-get? document-versions { owner: tx-sender, version: version })
        version-data
        (match (map-get? version-metadata { owner: tx-sender })
          metadata
          (let
            (
              (old-active-version (get active-version metadata))
              (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
              (new-version (+ (get current-version metadata) u1))
            )
            (asserts! (not (is-eq version old-active-version)) ERR_SAME_VERSION)
            (map-set version-metadata
              { owner: tx-sender }
              (merge metadata { 
                active-version: new-version,
                current-version: new-version,
                total-versions: (+ (get total-versions metadata) u1)
              })
            )
            (map-set document-versions
              { owner: tx-sender, version: old-active-version }
              (merge (unwrap-panic (map-get? document-versions { owner: tx-sender, version: old-active-version })) { is-active: false })
            )
            (map-set document-versions
              { owner: tx-sender, version: new-version }
              {
                document-hash: (get document-hash version-data),
                version-name: (get version-name version-data),
                created-at: current-time,
                description: "Rollback version",
                is-active: true
              }
            )
            (map-set switches
              { owner: tx-sender }
              (merge switch-data { document-hash: (get document-hash version-data) })
            )
            (ok new-version)
          )
          ERR_NOT_FOUND
        )
        ERR_VERSION_NOT_FOUND
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (delete-version (version uint))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (match (map-get? version-metadata { owner: tx-sender })
        metadata
        (let
          (
            (active-version (get active-version metadata))
          )
          (asserts! (not (is-eq version active-version)) ERR_INVALID_VERSION)
          (asserts! (> version u0) ERR_INVALID_VERSION)
          (match (map-get? document-versions { owner: tx-sender, version: version })
            version-data
            (begin
              (map-delete document-versions { owner: tx-sender, version: version })
              (ok true)
            )
            ERR_VERSION_NOT_FOUND
          )
        )
        ERR_NOT_FOUND
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (delete-switch)
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (map-delete switches { owner: tx-sender })
      (map-delete version-metadata { owner: tx-sender })
      (var-set total-switches (- (var-get total-switches) u1))
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-read-only (get-switch-status (owner principal))
  (match (map-get? switches { owner: owner })
    switch-data
    (let
      (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (expiry-time (+ (get last-checkin switch-data) (get inactivity-period switch-data)))
        (is-expired (>= current-time expiry-time))
      )
      (ok {
        owner: owner,
        beneficiary: (get beneficiary switch-data),
        last-checkin: (get last-checkin switch-data),
        inactivity-period: (get inactivity-period switch-data),
        is-released: (get is-released switch-data),
        is-expired: is-expired,
        time-until-expiry: (if is-expired u0 (- expiry-time current-time)),
        created-at: (get created-at switch-data)
      })
    )
    ERR_NOT_FOUND
  )
)

(define-public (enable-recovery (threshold uint))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (asserts! (> threshold u0) ERR_THRESHOLD_TOO_LOW)
      (asserts! (<= threshold (var-get max-guardians-per-switch)) ERR_THRESHOLD_TOO_HIGH)
      (match (map-get? recovery-settings { owner: tx-sender })
        existing-settings
        ERR_RECOVERY_ALREADY_ACTIVE
        (begin
          (map-set recovery-settings
            { owner: tx-sender }
            {
              is-enabled: true,
              threshold: threshold,
              guardian-count: u0
            }
          )
          (map-set recovery-metadata
            { owner: tx-sender }
            {
              current-proposal-id: u0,
              total-proposals: u0
            }
          )
          (ok true)
        )
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (disable-recovery)
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (match (map-get? recovery-settings { owner: tx-sender })
        settings
        (begin
          (map-delete recovery-settings { owner: tx-sender })
          (map-delete recovery-metadata { owner: tx-sender })
          (ok true)
        )
        ERR_RECOVERY_NOT_ENABLED
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (add-guardian (guardian principal))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? switches { owner: tx-sender })
      switch-data
      (begin
        (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
        (asserts! (not (is-eq guardian tx-sender)) ERR_CANNOT_REMOVE_SELF)
        (match (map-get? recovery-settings { owner: tx-sender })
          settings
          (begin
            (asserts! (get is-enabled settings) ERR_RECOVERY_NOT_ENABLED)
            (asserts! (< (get guardian-count settings) (var-get max-guardians-per-switch)) ERR_MAX_GUARDIANS_EXCEEDED)
            (match (map-get? guardians { owner: tx-sender, guardian: guardian })
              existing-guardian
              ERR_ALREADY_GUARDIAN
              (begin
                (map-set guardians
                  { owner: tx-sender, guardian: guardian }
                  {
                    is-active: true,
                    added-at: current-time,
                    added-by: tx-sender
                  }
                )
                (map-set recovery-settings
                  { owner: tx-sender }
                  (merge settings { guardian-count: (+ (get guardian-count settings) u1) })
                )
                (ok true)
              )
            )
          )
          ERR_RECOVERY_NOT_ENABLED
        )
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (remove-guardian (guardian principal))
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (match (map-get? recovery-settings { owner: tx-sender })
        settings
        (begin
          (asserts! (get is-enabled settings) ERR_RECOVERY_NOT_ENABLED)
          (match (map-get? guardians { owner: tx-sender, guardian: guardian })
            guardian-data
            (begin
              (asserts! (get is-active guardian-data) ERR_NOT_GUARDIAN)
              (map-delete guardians { owner: tx-sender, guardian: guardian })
              (map-set recovery-settings
                { owner: tx-sender }
                (merge settings { guardian-count: (- (get guardian-count settings) u1) })
              )
              (ok true)
            )
            ERR_NOT_GUARDIAN
          )
        )
        ERR_RECOVERY_NOT_ENABLED
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (initiate-recovery (owner principal) (action-type (string-ascii 32)) (new-beneficiary (optional principal)) (new-document-hash (optional (string-ascii 64))) (new-inactivity-period (optional uint)))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? switches { owner: owner })
      switch-data
      (begin
        (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
        (match (map-get? recovery-settings { owner: owner })
          settings
          (begin
            (asserts! (get is-enabled settings) ERR_RECOVERY_NOT_ENABLED)
            (asserts! (is-guardian owner tx-sender) ERR_NOT_GUARDIAN)
            (match (map-get? recovery-metadata { owner: owner })
              metadata
              (let
                (
                  (next-proposal-id (+ (get current-proposal-id metadata) u1))
                  (expires-at (+ current-time (var-get recovery-period)))
                )
                (map-set recovery-metadata
                  { owner: owner }
                  (merge metadata { 
                    current-proposal-id: next-proposal-id,
                    total-proposals: (+ (get total-proposals metadata) u1)
                  })
                )
                (map-set recovery-proposals
                  { owner: owner, proposal-id: next-proposal-id }
                  {
                    initiated-by: tx-sender,
                    initiated-at: current-time,
                    expires-at: expires-at,
                    action-type: action-type,
                    new-beneficiary: new-beneficiary,
                    new-document-hash: new-document-hash,
                    new-inactivity-period: new-inactivity-period,
                    signature-count: u1,
                    is-executed: false
                  }
                )
                (map-set recovery-signatures
                  { owner: owner, proposal-id: next-proposal-id, guardian: tx-sender }
                  {
                    signed-at: current-time
                  }
                )
                (ok next-proposal-id)
              )
              ERR_NOT_FOUND
            )
          )
          ERR_RECOVERY_NOT_ENABLED
        )
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (sign-recovery (owner principal) (proposal-id uint))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? recovery-proposals { owner: owner, proposal-id: proposal-id })
      proposal
      (begin
        (asserts! (not (get is-executed proposal)) ERR_ALREADY_SIGNED)
        (asserts! (< current-time (get expires-at proposal)) ERR_RECOVERY_EXPIRED)
        (asserts! (is-guardian owner tx-sender) ERR_NOT_GUARDIAN)
        (match (map-get? recovery-signatures { owner: owner, proposal-id: proposal-id, guardian: tx-sender })
          existing-signature
          ERR_ALREADY_SIGNED
          (begin
            (map-set recovery-signatures
              { owner: owner, proposal-id: proposal-id, guardian: tx-sender }
              {
                signed-at: current-time
              }
            )
            (map-set recovery-proposals
              { owner: owner, proposal-id: proposal-id }
              (merge proposal { signature-count: (+ (get signature-count proposal) u1) })
            )
            (ok true)
          )
        )
      )
      ERR_NO_ACTIVE_RECOVERY
    )
  )
)

(define-public (execute-recovery (owner principal) (proposal-id uint))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (match (map-get? recovery-proposals { owner: owner, proposal-id: proposal-id })
      proposal
      (begin
        (asserts! (not (get is-executed proposal)) ERR_ALREADY_SIGNED)
        (asserts! (< current-time (get expires-at proposal)) ERR_RECOVERY_EXPIRED)
        (match (map-get? recovery-settings { owner: owner })
          settings
          (begin
            (asserts! (>= (get signature-count proposal) (get threshold settings)) ERR_INSUFFICIENT_SIGNATURES)
            (match (map-get? switches { owner: owner })
              switch-data
              (let
                (
                  (action (get action-type proposal))
                  (updated-switch
                    (if (is-eq action "update-beneficiary")
                      (merge switch-data { beneficiary: (unwrap-panic (get new-beneficiary proposal)) })
                      (if (is-eq action "update-document")
                        (merge switch-data { document-hash: (unwrap-panic (get new-document-hash proposal)) })
                        (if (is-eq action "update-period")
                          (merge switch-data { inactivity-period: (unwrap-panic (get new-inactivity-period proposal)) })
                          switch-data
                        )
                      )
                    )
                  )
                )
                (map-set switches
                  { owner: owner }
                  updated-switch
                )
                (map-set recovery-proposals
                  { owner: owner, proposal-id: proposal-id }
                  (merge proposal { is-executed: true })
                )
                (ok true)
              )
              ERR_NOT_FOUND
            )
          )
          ERR_RECOVERY_NOT_ENABLED
        )
      )
      ERR_NO_ACTIVE_RECOVERY
    )
  )
)




