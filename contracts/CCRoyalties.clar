

(define-non-fungible-token content-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-nft-not-found (err u103))
(define-constant err-listing-expired (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-royalty (err u106))
(define-constant err-transfer-failed (err u107))
(define-constant err-invalid-collaborator (err u108))

(define-data-var last-token-id uint u0)
(define-data-var platform-fee-percentage uint u250)

(define-map token-metadata uint
  {
    creator: principal,
    title: (string-ascii 256),
    description: (string-ascii 512),
    metadata-uri: (string-ascii 256),
    creation-block: uint,
    royalty-percentage: uint
  })

(define-map token-royalties uint
  {
    total-percentage: uint,
    collaborators: (list 10 {collaborator: principal, percentage: uint})
  })

(define-map token-listings uint
  {
    seller: principal,
    price: uint,
    expiration-block: uint,
    active: bool
  })

(define-map user-earnings principal uint)

(define-read-only (get-last-token-id)
  (var-get last-token-id))

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (some (get metadata-uri metadata)))
    (ok none)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? content-nft token-id)))

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id))

(define-read-only (get-token-royalties (token-id uint))
  (map-get? token-royalties token-id))

(define-read-only (get-token-listing (token-id uint))
  (map-get? token-listings token-id))

(define-read-only (get-user-earnings (user principal))
  (default-to u0 (map-get? user-earnings user)))

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage))

(define-public (mint-nft 
  (title (string-ascii 256))
  (description (string-ascii 512))
  (metadata-uri (string-ascii 256))
  (royalty-percentage uint)
  (collaborators (list 10 {collaborator: principal, percentage: uint})))
  (let ((token-id (+ (var-get last-token-id) u1))
        (total-collab-percentage (fold calculate-total-percentage collaborators u0)))
    (asserts! (<= (+ royalty-percentage total-collab-percentage) u5000) err-invalid-royalty)
    (try! (nft-mint? content-nft token-id tx-sender))
    (map-set token-metadata token-id
      {
        creator: tx-sender,
        title: title,
        description: description,
        metadata-uri: metadata-uri,
        creation-block: stacks-block-height,
        royalty-percentage: royalty-percentage
      })
    (map-set token-royalties token-id
      {
        total-percentage: (+ royalty-percentage total-collab-percentage),
        collaborators: collaborators
      })
    (var-set last-token-id token-id)
    (ok token-id)))

(define-public (list-for-sale (token-id uint) (price uint) (duration uint))
  (let ((owner (unwrap! (nft-get-owner? content-nft token-id) err-nft-not-found)))
    (asserts! (is-eq owner tx-sender) err-not-token-owner)
    (asserts! (> price u0) err-insufficient-funds)
    (map-set token-listings token-id
      {
        seller: tx-sender,
        price: price,
        expiration-block: (+ stacks-block-height duration),
        active: true
      })
    (ok true)))

(define-public (unlist-token (token-id uint))
  (let ((listing (unwrap! (map-get? token-listings token-id) err-listing-not-found))
        (owner (unwrap! (nft-get-owner? content-nft token-id) err-nft-not-found)))
    (asserts! (is-eq owner tx-sender) err-not-token-owner)
    (map-set token-listings token-id (merge listing {active: false}))
    (ok true)))

(define-public (buy-token (token-id uint))
  (let ((listing (unwrap! (map-get? token-listings token-id) err-listing-not-found))
        (metadata (unwrap! (map-get? token-metadata token-id) err-nft-not-found))
        (royalty-info (unwrap! (map-get? token-royalties token-id) err-nft-not-found))
        (seller (get seller listing))
        (price (get price listing)))
    (asserts! (get active listing) err-listing-not-found)
    (asserts! (<= stacks-block-height (get expiration-block listing)) err-listing-expired)
    (try! (stx-transfer? price tx-sender seller))
    (try! (distribute-royalties token-id price))
    (try! (nft-transfer? content-nft token-id seller tx-sender))
    (map-set token-listings token-id (merge listing {active: false}))
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? content-nft token-id sender recipient)))

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-royalty)
    (ok (var-set platform-fee-percentage new-fee))))

(define-public (withdraw-earnings)
  (let ((earnings (get-user-earnings tx-sender)))
    (asserts! (> earnings u0) err-insufficient-funds)
    (map-delete user-earnings tx-sender)
    (stx-transfer? earnings (as-contract tx-sender) tx-sender)))

(define-private (distribute-royalties (token-id uint) (sale-price uint))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-nft-not-found))
        (royalty-info (unwrap! (map-get? token-royalties token-id) err-nft-not-found))
        (creator (get creator metadata))
        (creator-royalty-percentage (get royalty-percentage metadata))
        (collaborators (get collaborators royalty-info))
        (platform-fee (/ (* sale-price (var-get platform-fee-percentage)) u10000))
        (creator-royalty (/ (* sale-price creator-royalty-percentage) u10000)))
    (try! (stx-transfer? platform-fee tx-sender contract-owner))
    (if (> creator-royalty u0)
      (begin
        (map-set user-earnings creator 
          (+ (get-user-earnings creator) creator-royalty))
        (try! (stx-transfer? creator-royalty tx-sender creator)))
      true)
    (unwrap-panic (distribute-collaborator-royalties collaborators sale-price))
    (ok true)))

(define-private (distribute-collaborator-royalties 
  (collaborators (list 10 {collaborator: principal, percentage: uint}))
  (sale-price uint))
  (ok true))

(define-private (calculate-total-percentage 
  (collab-info {collaborator: principal, percentage: uint})
  (total uint))
  (+ total (get percentage collab-info)))

(define-public (get-token-history (token-id uint))
  (ok {
    metadata: (get-token-metadata token-id),
    royalties: (get-token-royalties token-id),
    current-owner: (nft-get-owner? content-nft token-id),
    listing: (get-token-listing token-id)
  }))

(define-public (update-metadata-uri (token-id uint) (new-uri (string-ascii 256)))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-nft-not-found))
        (owner (unwrap! (nft-get-owner? content-nft token-id) err-nft-not-found)))
    (asserts! (is-eq tx-sender owner) err-not-token-owner)
    (map-set token-metadata token-id (merge metadata {metadata-uri: new-uri}))
    (ok true)))

(define-public (batch-mint 
  (tokens (list 10 {
    title: (string-ascii 256),
    description: (string-ascii 512),
    metadata-uri: (string-ascii 256),
    royalty-percentage: uint,
    collaborators: (list 10 {collaborator: principal, percentage: uint})
  })))
  (ok (map mint-single-token tokens)))

(define-private (mint-single-token 
  (token-data {
    title: (string-ascii 256),
    description: (string-ascii 512),
    metadata-uri: (string-ascii 256),
    royalty-percentage: uint,
    collaborators: (list 10 {collaborator: principal, percentage: uint})
  }))
  (match (mint-nft 
    (get title token-data)
    (get description token-data)
    (get metadata-uri token-data)
    (get royalty-percentage token-data)
    (get collaborators token-data))
    success success
    error u0))

(define-read-only (get-creator-tokens (creator principal))
  (ok (var-get last-token-id)))
