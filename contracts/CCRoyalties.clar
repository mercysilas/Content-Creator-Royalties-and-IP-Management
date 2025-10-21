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
(define-constant err-invalid-score (err u109))
(define-constant err-user-not-found (err u110))
(define-constant err-invalid-achievement (err u111))
(define-constant err-threshold-not-met (err u112))
(define-constant err-no-released-funds (err u113))

(define-constant reputation-multiplier u100)
(define-constant engagement-cost u1000)
(define-constant discount-threshold u5000)
(define-constant max-achievement-length u32)
(define-constant creator-discount u500)
(define-constant default-threshold-amount u1000000)
(define-constant max-threshold-amount u100000000)

(define-data-var last-token-id uint u0)
(define-data-var platform-fee-percentage uint u250)
(define-data-var total-platform-volume uint u0)
(define-data-var total-creators uint u0)

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

(define-map creator-reputation principal uint)
(define-map collector-reputation principal uint)

(define-map creator-stats principal 
  {
    total-sales: uint,
    total-revenue: uint,
    average-price: uint,
    engagement-score: uint,
    first-sale-block: uint,
    last-activity-block: uint,
    discount-earned: bool
  })

(define-map creator-achievements principal (string-utf8 32))

(define-map engagement-records
  {creator: principal, reporter: principal}
  uint)

(define-map user-threshold-settings principal
  {
    threshold-amount: uint,
    auto-release: bool
  })

(define-map user-pending-royalties principal uint)
(define-map user-released-royalties principal uint)

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

(define-read-only (get-creator-reputation (creator principal))
  (default-to u0 (map-get? creator-reputation creator)))

(define-read-only (get-collector-reputation (collector principal))
  (default-to u0 (map-get? collector-reputation collector)))

(define-read-only (get-creator-stats (creator principal))
  (map-get? creator-stats creator))

(define-read-only (get-creator-achievements (creator principal))
  (map-get? creator-achievements creator))

(define-read-only (get-trust-score (user principal))
  (let ((creator-rep (get-creator-reputation user))
        (collector-rep (get-collector-reputation user)))
    (+ creator-rep collector-rep)))

(define-read-only (qualifies-for-discount (user principal))
  (>= (get-trust-score user) discount-threshold))

(define-read-only (get-platform-analytics)
  {
    total-volume: (var-get total-platform-volume),
    total-creators: (var-get total-creators),
    platform-fee: (var-get platform-fee-percentage),
    discount-threshold: discount-threshold
  })

(define-read-only (get-user-threshold-setting (user principal))
  (default-to 
    {threshold-amount: default-threshold-amount, auto-release: true}
    (map-get? user-threshold-settings user)))

(define-read-only (get-pending-royalties (user principal))
  (default-to u0 (map-get? user-pending-royalties user)))

(define-read-only (get-released-royalties (user principal))
  (default-to u0 (map-get? user-released-royalties user)))

(define-read-only (get-royalty-status (user principal))
  (let ((settings (get-user-threshold-setting user))
        (pending (get-pending-royalties user))
        (released (get-released-royalties user))
        (threshold-amount (get threshold-amount settings))
        (threshold-met (>= pending threshold-amount)))
    {
      pending: pending,
      released: released,
      threshold-amount: threshold-amount,
      auto-release: (get auto-release settings),
      threshold-met: threshold-met
    }))

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
    (update-creator-first-mint tx-sender)
    (var-set last-token-id token-id)
    (ok token-id)))

(define-public (list-for-sale (token-id uint) (price uint) (duration uint))
  (let ((owner (unwrap! (nft-get-owner? content-nft token-id) err-nft-not-found))
        (final-price (if (qualifies-for-discount owner) 
                        (- price (/ (* price creator-discount) u10000)) 
                        price)))
    (asserts! (is-eq owner tx-sender) err-not-token-owner)
    (asserts! (> price u0) err-insufficient-funds)
    (map-set token-listings token-id
      {
        seller: tx-sender,
        price: final-price,
        expiration-block: (+ stacks-block-height duration),
        active: true
      })
    (ok true)))

(define-public (buy-token (token-id uint))
  (let ((listing (unwrap! (map-get? token-listings token-id) err-listing-not-found))
        (metadata (unwrap! (map-get? token-metadata token-id) err-nft-not-found))
        (royalty-info (unwrap! (map-get? token-royalties token-id) err-nft-not-found))
        (seller (get seller listing))
        (price (get price listing))
        (creator (get creator metadata)))
    (asserts! (get active listing) err-listing-not-found)
    (asserts! (<= stacks-block-height (get expiration-block listing)) err-listing-expired)
    (try! (stx-transfer? price tx-sender seller))
    (try! (distribute-royalties token-id price))
    (try! (nft-transfer? content-nft token-id seller tx-sender))
    (map-set token-listings token-id (merge listing {active: false}))
    (update-reputation-after-sale creator tx-sender price)
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? content-nft token-id sender recipient)))

(define-public (record-engagement (creator principal) (score uint))
  (let ((current-stats (get-creator-stats creator)))
    (asserts! (<= score u1000) err-invalid-score)
    (asserts! (is-some current-stats) err-user-not-found)
    (try! (stx-transfer? engagement-cost tx-sender contract-owner))
    
    (map-set creator-stats creator
      (merge (unwrap-panic current-stats)
        {engagement-score: (+ (get engagement-score (unwrap-panic current-stats)) score)}))
    
    (map-set engagement-records {creator: creator, reporter: tx-sender} score)
    
    (map-set creator-reputation creator
      (+ (get-creator-reputation creator) (/ score u10)))
    
    (ok true)))

(define-public (grant-achievement (creator principal) (achievement (string-utf8 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= (len achievement) max-achievement-length) err-invalid-achievement)
    (map-set creator-achievements creator achievement)
    (map-set creator-reputation creator (+ (get-creator-reputation creator) u1000))
    (ok true)))

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

(define-public (set-royalty-threshold (threshold-amount-input uint) (auto-release-input bool))
  (let ((user tx-sender)
        (validated-amount (if (< threshold-amount-input default-threshold-amount) 
                             default-threshold-amount 
                             (if (> threshold-amount-input max-threshold-amount)
                               max-threshold-amount
                               threshold-amount-input))))
    (map-set user-threshold-settings user {
      threshold-amount: validated-amount,
      auto-release: auto-release-input
    })
    (ok true)))

(define-public (release-accumulated-royalties)
  (let ((user tx-sender)
        (pending (get-pending-royalties user))
        (settings (get-user-threshold-setting user))
        (threshold (get threshold-amount settings))
        (current-released (get-released-royalties user)))
    (asserts! (>= pending threshold) err-threshold-not-met)
    (map-set user-released-royalties user (+ current-released pending))
    (map-set user-pending-royalties user u0)
    (ok pending)))

(define-public (claim-released-royalties)
  (let ((user tx-sender)
        (amount (get-released-royalties user)))
    (asserts! (> amount u0) err-no-released-funds)
    (try! (as-contract (stx-transfer? amount tx-sender user)))
    (map-set user-released-royalties user u0)
    (ok amount)))

(define-private (update-creator-first-mint (creator principal))
  (if (is-none (map-get? creator-stats creator))
    (begin
      (map-set creator-stats creator
        {
          total-sales: u0,
          total-revenue: u0,
          average-price: u0,
          engagement-score: u0,
          first-sale-block: stacks-block-height,
          last-activity-block: stacks-block-height,
          discount-earned: false
        })
      (var-set total-creators (+ (var-get total-creators) u1)))
    true))

(define-private (update-reputation-after-sale (creator principal) (buyer principal) (price uint))
  (let ((current-stats (default-to 
         {total-sales: u0, total-revenue: u0, average-price: u0, 
          engagement-score: u0, first-sale-block: stacks-block-height, 
          last-activity-block: stacks-block-height, discount-earned: false}
         (map-get? creator-stats creator)))
        (new-sales (+ (get total-sales current-stats) u1))
        (new-revenue (+ (get total-revenue current-stats) price))
        (new-avg (/ new-revenue new-sales))
        (rep-boost (/ (* price reputation-multiplier) u1000000))
        (earned-discount (>= (+ (get-creator-reputation creator) rep-boost) discount-threshold)))
    
    (map-set creator-stats creator
      (merge current-stats 
        {total-sales: new-sales,
         total-revenue: new-revenue,
         average-price: new-avg,
         last-activity-block: stacks-block-height,
         discount-earned: earned-discount}))
    
    (map-set creator-reputation creator
      (+ (get-creator-reputation creator) rep-boost))
    
    (map-set collector-reputation buyer
      (+ (get-collector-reputation buyer) (/ rep-boost u10)))
    
    (var-set total-platform-volume (+ (var-get total-platform-volume) price))
    true))

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
        (let ((creator-settings (get-user-threshold-setting creator))
              (current-pending (get-pending-royalties creator))
              (new-pending (+ current-pending creator-royalty))
              (threshold (get threshold-amount creator-settings))
              (auto-release (get auto-release creator-settings)))
          (if (and (>= new-pending threshold) auto-release)
            (begin
              (map-set user-released-royalties creator (+ (get-released-royalties creator) new-pending))
              (map-set user-pending-royalties creator u0)
              (map-set user-earnings creator 
                (+ (get-user-earnings creator) new-pending)))
            (map-set user-pending-royalties creator new-pending))))
      true)
    (unwrap-panic (distribute-collaborator-royalties collaborators sale-price))
    (ok true)))

(define-private (distribute-collaborator-royalties 
  (collaborators (list 10 {collaborator: principal, percentage: uint}))
  (sale-price uint))
  (ok (fold distribute-single-collaborator-royalty collaborators sale-price)))

(define-private (distribute-single-collaborator-royalty 
  (collab-info {collaborator: principal, percentage: uint})
  (sale-price uint))
  (let ((collaborator (get collaborator collab-info))
        (percentage (get percentage collab-info))
        (royalty-amount (/ (* sale-price percentage) u10000)))
    (if (> royalty-amount u0)
      (begin
        (map-set user-earnings collaborator 
          (+ (get-user-earnings collaborator) royalty-amount))
        (unwrap-panic (stx-transfer? royalty-amount tx-sender collaborator))
        sale-price)
      sale-price)))

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

(define-read-only (get-creator-dashboard (creator principal))
  (let ((stats (get-creator-stats creator))
        (reputation (get-creator-reputation creator))
        (achievements (get-creator-achievements creator)))
    {
      stats: stats,
      reputation: reputation,
      trust-score: (get-trust-score creator),
      qualifies-discount: (qualifies-for-discount creator),
      achievements: achievements
    }))