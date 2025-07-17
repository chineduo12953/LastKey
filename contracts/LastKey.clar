
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