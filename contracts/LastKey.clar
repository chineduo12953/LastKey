
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

(define-public (delete-switch)
  (match (map-get? switches { owner: tx-sender })
    switch-data
    (begin
      (asserts! (not (get is-released switch-data)) ERR_ALREADY_RELEASED)
      (map-delete switches { owner: tx-sender })
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