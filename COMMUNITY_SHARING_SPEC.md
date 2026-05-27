# E-Telly — Community Resource Sharing: Developer Specification

**Version:** 1.0  
**Audience:** Web Developer (React/Node.js) · Mobile Developer (Flutter)  
**Status:** Ready for implementation

---

## 1. Goal

The title of the system is:
> **E-TELLY: A Smart Progressive Web and Mobile Disaster Preparedness and Community Resource Sharing System**

The current implementation is a managed relief distribution system — CDRRMO mediates everything, residents never interact with each other. This specification upgrades the Community Resource Sharing module so that:

1. **Residents** can post what they need and browse what their community is offering.
2. **Other residents** can pledge to help a specific request.
3. **The requester** picks who helps them (like Facebook Marketplace — the seller chooses the buyer).
4. **The helper and requester** can message each other to coordinate delivery.
5. **CDRRMO/admin** oversees everything, can intervene in any thread, and can also post official supply offers from their stockpile.

This is genuine peer-to-peer community resource sharing, with CDRRMO as the accountability layer — not the bottleneck.

---

## 2. How It Works (Concept)

### Resident Perspective (Mobile)

```
Person A (needs something)          Person B (can help)
─────────────────────────           ─────────────────────────
1. Posts a request on the board     3. Sees the need on the board
2. Waits for offers to arrive       4. Taps "I can help" (pledges)
                                    5. Writes a short message + phone
   ← Notified: "Person B offered"
6. Sees all offers, picks Person B
   → Request moves to "Matched"
   ← Person B notified: "You were chosen"
7. They chat to coordinate
8. Person B delivers in real life
                                    9. Taps "I've delivered it"
   ← Notified: "Person B says delivered"
10. Confirms receipt                
    → Request marked Fulfilled      ← Both get confirmation notification
```

### Admin/CDRRMO Perspective (Web)

- Sees all requests, pledges, and message threads in real time
- Can post official CDRRMO supply offers on the community board (from their stockpile)
- Can write in any message thread to help coordinate
- Can force-mark a request as fulfilled if parties are unresponsive
- Can cancel any request if needed

---

## 3. Status Flows

### Resource Request Statuses

```
[open] ──→ [matched] ──→ [fulfilled]
  │              │
  └──────────────┴──→ [cancelled]
```

| Status | Set By | Meaning |
|--------|--------|---------|
| `open` | System (on creation) | Posted to community board, accepting pledges |
| `matched` | Person A (accept a pledge) | A helper has been chosen, chat is active |
| `fulfilled` | Person A (confirm receipt) OR Admin override | Resource was delivered and confirmed |
| `cancelled` | Person A, Person B, or Admin | Request is no longer active |

> **Note on existing data:** Any requests currently in the database with status `pending` or `approved` should be treated as `open`. The server will handle both values during a transition period — but all NEW requests use `open`.

### Pledge Statuses (per pledge inside a request)

| Status | Meaning |
|--------|---------|
| `pending` | Submitted, waiting for Person A to respond |
| `accepted` | Person A chose this pledger — only one pledge per request can be accepted |
| `declined` | Person A chose someone else (auto-set when another pledge is accepted) |
| `withdrawn` | Pledger pulled back their offer |

### Donation Statuses (unchanged from before)

`offered → scheduled → received → cancelled`

---

## 4. Database / Schema Changes

### 4a. ResourceRequest Model — `server/models/ResourceRequest.js`

**Change the `status` enum:**
```js
// Old:
status: { type: String, enum: ["pending","approved","rejected","fulfilled","cancelled"], default: "pending" }

// New:
status: { type: String, enum: ["pending","open","approved","matched","rejected","fulfilled","cancelled"], default: "open" }
// (Keeping old values in enum so existing documents don't fail validation)
```

**Change the `actionLog` action enum:**
```js
// Old:
action: { type: String, enum: ["approved","rejected","fulfilled","cancelled"] }

// New:
action: { type: String, enum: ["approved","matched","rejected","fulfilled","cancelled"] }
```

**Add a `pledges` sub-document array (new field):**
```js
const pledgeSchema = new mongoose.Schema({
  userId:    { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  name:      { type: String, required: true },
  phone:     { type: String, default: null },
  message:   { type: String, default: "" },
  status:    { type: String, enum: ["pending","accepted","declined","withdrawn"], default: "pending" },
  createdAt: { type: Date, default: Date.now },
}, { _id: true });

// Add to ResourceRequestSchema:
pledges:          { type: [pledgeSchema], default: [] },
matchedPledgerId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
deliveredAt:      { type: Date, default: null },
```

> `_id: true` on pledgeSchema is required — the pledge's ObjectId is used as the key when Person A accepts a specific pledge.

### 4b. New Model — `server/models/ResourceMessage.js`

Create this new file:

```js
import mongoose from "mongoose";

const ResourceMessageSchema = new mongoose.Schema({
  requestId:  { type: mongoose.Schema.Types.ObjectId, ref: "ResourceRequest", required: true },
  senderId:   { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  senderName: { type: String, required: true },
  senderRole: { type: String, enum: ["resident","admin","barangay_official"], required: true },
  text:       { type: String, required: true, maxlength: 1000 },
}, { timestamps: true });

// Index for fast lookup of all messages for a request
ResourceMessageSchema.index({ requestId: 1, createdAt: 1 });

export default mongoose.model("ResourceMessage", ResourceMessageSchema);
```

### 4c. ResourceDonation Model — `server/models/ResourceDonation.js`

**Add two new fields** (no other changes):
```js
isOfficial:       { type: Boolean, default: false },
matchedRequestId: { type: mongoose.Schema.Types.ObjectId, ref: "ResourceRequest", default: null },
```

`isOfficial: true` means this offer was posted by CDRRMO from their official stockpile — it shows differently on the community board.

---

## 5. Complete API Reference

All endpoints are prefixed with `/api/community`.

**Auth rules used:**
- `protect` — requires a valid JWT in `Authorization: Bearer <token>` header
- `optionalProtect` — works with or without JWT
- `requireAdminOrBarangay` — JWT required + `role` must be `"admin"` or `"barangay_official"`
- `residentOnly` — JWT required + `role` must be `"user"`

---

### 5.1 Community Board

#### `GET /api/community/board`

Returns an anonymized view of what residents see — open needs and available donations.

**Auth:** Optional  
**Query params:**

| Param | Required | Description |
|-------|----------|-------------|
| `barangay` | No | Filter by barangay name. Omit to return all barangays. |

**Response `200`:**
```json
{
  "success": true,
  "requests": [
    {
      "_id": "664a1...",
      "requesterName": "Juan D.",
      "barangay": "Bagong Nayon",
      "category": "food",
      "itemDescription": "Bottled Water (500ml)",
      "quantity": 5,
      "unit": "pcs",
      "urgent": false,
      "status": "open",
      "pledgeCount": 2,
      "priority": "high",
      "createdAt": "2026-05-13T08:00:00.000Z"
    }
  ],
  "donations": [
    {
      "_id": "664b2...",
      "donorName": "Anonymous",
      "isOfficial": false,
      "barangay": "Bagong Nayon",
      "category": "food",
      "itemDescription": "Canned Sardines",
      "quantity": 50,
      "unit": "cans",
      "status": "offered",
      "createdAt": "2026-05-13T08:30:00.000Z"
    }
  ]
}
```

**Privacy rules (server enforces):**
- No email, full address, or phone is returned
- Anonymous donors are shown as `"Anonymous"`
- `pledgeCount` = count of non-withdrawn pledges

**`priority` values:** `normal` | `medium` | `high` | `critical`  
Derived automatically from active hazard alert severity in that barangay.

**Sorting:** Requests sorted by priority descending, then oldest first (FCFS within same priority).

---

### 5.2 Submit a Resource Request

#### `POST /api/community/requests`

**Auth:** Optional (mobile sends JWT when logged in)

**Request body:**
```json
{
  "requesterName": "Juan Dela Cruz",
  "requesterEmail": "juan@example.com",
  "barangay": "Bagong Nayon",
  "address": "123 Main St",
  "category": "food",
  "itemDescription": "Bottled Water (500ml)",
  "quantity": 5,
  "unit": "pcs",
  "reason": "We have 4 children and no clean water",
  "urgent": false
}
```

If JWT is provided, server backfills `requesterName` and `requesterEmail` from the user's profile automatically — mobile can omit those fields when authenticated.

**Mobile-only optional fields:**
```json
{
  "resourceId": "inventory-item-id",
  "gpsLat": 14.5995,
  "gpsLng": 121.0359,
  "phone": "09171234567"
}
```

**Response `201`:**
```json
{
  "success": true,
  "request": { "...full request object, status: 'open'..." }
}
```

**Error `409`:** User already has an active request in the same category.  
**Error `400`:** Missing required fields.

**Side effects:**
- Socket.IO emits `new_community_request` to all connected clients
- Push notification sent to all admins/barangay officials

---

### 5.3 Get My Requests

#### `GET /api/community/requests/mine`

Returns the logged-in resident's own requests (all statuses).

**Auth:** Required

**Response `200`:**
```json
{
  "success": true,
  "requests": [ { "...full request object including pledges array..." } ]
}
```

---

### 5.4 Get All Requests (Admin View)

#### `GET /api/community/requests`

Returns all requests sorted by priority. Admin/barangay use only.

**Auth:** Required (admin or barangay official)

**Response `200`:**
```json
{
  "success": true,
  "requests": [ { "...full request objects with priority scoring..." } ]
}
```

---

### 5.5 Cancel a Request

#### `PATCH /api/community/requests/:id/cancel`

**Auth:** Required  
**Who can call:** The requester themselves (`request.userId === req.user.id`) OR admin/barangay official.

**Request body:**
```json
{ "note": "Resolved another way" }
```

**Response `200`:** `{ "success": true, "request": {...} }`  
**Error `400`:** Cannot cancel an already fulfilled or cancelled request.

**Side effects:** Socket.IO `community_request_updated`

---

### 5.6 Pledge to Help

#### `POST /api/community/requests/:id/pledge`

A resident offers to deliver what Person A needs.

**Auth:** Required — residents only (role: `"user"`)  
**Who can call:** Any authenticated resident. **Cannot be called by the requester on their own request.**

**Request body:**
```json
{
  "message": "I have extra bottled water I can bring tomorrow morning",
  "phone": "09171234567"
}
```

Both fields are optional but strongly encouraged.

**Response `201`:**
```json
{
  "success": true,
  "pledgeCount": 3
}
```

**Error `403`:** Admins and barangay officials cannot pledge.  
**Error `403`:** Requester cannot pledge on their own request.  
**Error `409`:** This user already has an active pledge on this request.  
**Error `400`:** Request is not in `open` status (already matched, fulfilled, or cancelled).

**Side effects:**
- Push notification to Person A: "Someone offered to help with your request"
- Socket.IO `new_pledge` emitted to room `user-{request.userId}` and `admin-room`

---

### 5.7 Withdraw a Pledge

#### `DELETE /api/community/requests/:id/pledge`

Pledger cancels their own offer.

**Auth:** Required  
**Who can call:** The pledger themselves.

**Response `200`:** `{ "success": true }`  
**Error `404`:** No active pledge from this user on this request.  
**Error `400`:** Cannot withdraw an already-accepted pledge — contact CDRRMO.

**Side effects:** Socket.IO `community_request_updated`

---

### 5.8 Accept a Pledge (Person A chooses their helper)

#### `PATCH /api/community/requests/:id/accept-pledge`

Person A reviews all pledges and selects one person to deliver.

**Auth:** Required  
**Who can call:** The requester only (`request.userId === req.user.id`). **Not admin.**

**Request body:**
```json
{ "pledgeId": "664c3..." }
```

`pledgeId` is the `_id` of the specific pledge in the `pledges` array.

**Response `200`:** `{ "success": true, "request": {...} }`

**Server logic:**
1. Validate the pledge exists and is in `pending` status
2. Set chosen pledge's status → `"accepted"`, set `request.matchedPledgerId` to pledger's userId
3. Set all other `pending` pledges → `"declined"`
4. Set `request.status` → `"matched"`
5. Push actionLog entry: `{ action: "matched", by: requester name, note: "Pledge accepted from [pledger name]" }`

**Error `403`:** Only the requester can accept a pledge.  
**Error `404`:** Pledge not found.  
**Error `400`:** Request is not in `open` status.  
**Error `400`:** Chosen pledge has been withdrawn.

**Side effects:**
- Push notification to accepted pledger: "Your offer was accepted! Check the chat to coordinate."
- Push notification to each declined pledger: "Another helper was chosen for this request. Thank you for offering!"
- Socket.IO `pledge_accepted` emitted to room `user-{acceptedPledger.userId}`
- Socket.IO `pledge_declined` emitted to room `user-{eachDeclinedPledger.userId}`
- Socket.IO `community_request_updated` emitted to all

---

### 5.9 Mark as Delivered (Person B)

#### `PATCH /api/community/requests/:id/deliver`

Person B has physically brought the item. This notifies Person A to confirm.

**Auth:** Required  
**Who can call:** The accepted pledger only (`request.matchedPledgerId === req.user.id`).

**Request body:** None required.

**Response `200`:** `{ "success": true }`

**Server logic:**
1. Validate this user is the accepted pledger
2. Set `request.deliveredAt = new Date()`
3. Do NOT change the status yet — wait for Person A's confirmation

**Error `403`:** Only the assigned helper can mark this delivered.  
**Error `400`:** Request is not in `matched` status.  
**Error `400`:** Already marked as delivered.

**Side effects:**
- Push notification to Person A: "Your helper says they've delivered! Please confirm receipt."
- Socket.IO `request_delivered` emitted to room `user-{request.userId}`

---

### 5.10 Confirm Receipt (Person A or Admin)

#### `PATCH /api/community/requests/:id/confirm`

Person A confirms they received the item. Closes the request.

**Auth:** Required  
**Who can call:** The requester (`request.userId === req.user.id`) OR admin/barangay official.

**Request body:**
```json
{ "note": "Received 5 bottles, thank you!" }
```
(Optional)

**Response `200`:** `{ "success": true, "request": {...} }`

**Server logic:**
1. Set `request.status → "fulfilled"`
2. Push actionLog: `{ action: "fulfilled", by: user name, note }`
3. If `request.resourceId` is set, deduct from inventory (existing atomic deduction logic)

**Error `403`:** Only the requester or admin can confirm.  
**Error `400`:** Request is not in `matched` status.

**Side effects:**
- Push notification to Person B: "Your delivery was confirmed! Thank you for helping."
- Socket.IO `community_request_updated` to all

---

### 5.11 Admin Force-Fulfill

#### `PATCH /api/community/requests/:id/fulfill`

Admin can manually close a request if parties are unresponsive.

**Auth:** Required — admin or barangay official only

**Request body:** `{ "note": "Verified delivery by barangay staff" }` (optional)

**Response `200`:** `{ "success": true, "request": {...} }`

**Side effects:** Socket.IO `community_request_updated`

---

### 5.12 Get Message Thread

#### `GET /api/community/requests/:id/messages`

Returns the conversation thread for a specific request.

**Auth:** Required  
**Who can access:**
- The requester (`request.userId === req.user.id`)
- The accepted pledger (`request.matchedPledgerId === req.user.id`)
- Any admin or barangay official

**Response `200`:**
```json
{
  "success": true,
  "messages": [
    {
      "_id": "664d1...",
      "requestId": "664a1...",
      "senderId": "user-id-123",
      "senderName": "Juan Dela Cruz",
      "senderRole": "resident",
      "text": "I can be there by 9am tomorrow",
      "createdAt": "2026-05-13T14:00:00.000Z"
    }
  ]
}
```

**Error `403`:** User is not a participant in this request.  
**Error `404`:** Request not found.

---

### 5.13 Send a Message

#### `POST /api/community/requests/:id/messages`

**Auth:** Required  
**Who can send:** Same access rules as `GET messages` above.

**Request body:**
```json
{ "text": "I will be at your address by 9am, I have your 5 bottles of water." }
```

**Validation:** `text` must not be empty and must be ≤ 1000 characters.

**Response `201`:**
```json
{
  "success": true,
  "message": { "...new message object..." }
}
```

**Error `403`:** Not a participant.  
**Error `400`:** Missing or empty text.  
**Error `400`:** Message too long (> 1000 characters).  
**Error `400`:** Can only message on `matched` requests (not open, fulfilled, or cancelled).

**Side effects:**
- Socket.IO `new_message` emitted to room `request-{requestId}` with the new message object
- Push notification to the OTHER participant (if sender is Person A → notify Person B, vice versa; admin messages notify both)

---

### 5.14 Get My Pledges

#### `GET /api/community/pledges/mine`

Returns all requests where the logged-in user has a non-withdrawn pledge. Used by the "My Pledges" screen in mobile.

**Auth:** Required

**Server logic:** `ResourceRequest.find({ "pledges.userId": req.user.id, "pledges.status": { $ne: "withdrawn" } })`

**Response `200`:**
```json
{
  "success": true,
  "requests": [
    {
      "...full request object...",
      "myPledge": {
        "status": "accepted",
        "message": "I have extra water",
        "createdAt": "2026-05-13T09:00:00.000Z"
      }
    }
  ]
}
```

---

### 5.15 Get My Donations

#### `GET /api/community/donations/mine`

**Auth:** Required  
No changes to this endpoint.

---

### 5.16 Submit a Donation

#### `POST /api/community/donations`

Existing endpoint — add one new optional field:

**New field for admin use only:**
```json
{ "isOfficial": true }
```

When `isOfficial: true`, the server must verify the sender is admin or barangay official. If `isOfficial: true` is sent by a regular user, reject with `403`.

This creates a CDRRMO official supply offer on the community board.

---

### 5.17 Schedule Donation Drop-Off

#### `PATCH /api/community/donations/:id/schedule`

Existing endpoint — add one new optional field:

```json
{
  "scheduledWindow": "May 28, 9:00 AM - 12:00 PM",
  "note": "Drop off at barangay hall",
  "matchedRequestId": "664a1..."
}
```

`matchedRequestId` (optional): links this donation to a specific open/matched request.  
Server validates: the request exists and is in `open` or `matched` status. If invalid, return `400`.

---

### 5.18 Receive Donation

#### `PATCH /api/community/donations/:id/receive`

No changes — existing behavior (auto-transfers to inventory) stays exactly the same.

---

### 5.19 Cancel a Donation

#### `PATCH /api/community/donations/:id/cancel`

No changes to this endpoint.

---

## 6. Socket.IO Events Reference

The server must join users to personalized rooms when they connect. Mobile must join these rooms on login.

### Rooms

| Room Name | Who joins |
|-----------|-----------|
| `user-{userId}` | Every authenticated user joins this on connect |
| `request-{requestId}` | Users join this when they open a message thread |
| `admin-room` | All admins and barangay officials join on connect |

### Events Emitted by Server

| Event Name | Payload | Who receives |
|------------|---------|--------------|
| `new_community_request` | `{ request }` | Broadcast (all) |
| `community_request_updated` | `{ id, status }` | Broadcast (all) |
| `new_pledge` | `{ requestId, pledgerName }` | Room `user-{request.userId}` + `admin-room` |
| `pledge_accepted` | `{ requestId, message }` | Room `user-{acceptedPledger.userId}` |
| `pledge_declined` | `{ requestId }` | Room `user-{eachDeclinedPledger.userId}` |
| `new_message` | `{ message }` | Room `request-{requestId}` |
| `request_delivered` | `{ requestId }` | Room `user-{request.userId}` |
| `new_community_donation` | `{ donation }` | Broadcast (all) |
| `community_donation_updated` | `{ id, status }` | Broadcast (all) |

### Server: Room Join Handlers to Add in `server/index.js`

```js
io.on('connection', (socket) => {
  // Existing handlers stay...

  // NEW: Personal room join
  socket.on('join', ({ userId }) => {
    if (userId) socket.join(`user-${userId}`);
  });

  // NEW: Admin room join (call this after verifying role from JWT)
  socket.on('join_admin', () => {
    socket.join('admin-room');
  });

  // NEW: Request thread room join
  socket.on('join_request', ({ requestId }) => {
    if (requestId) socket.join(`request-${requestId}`);
  });
});
```

### Mobile: How to Join Rooms

On login / Socket.IO connect:
```dart
socket.emit('join', { 'userId': currentUser.id });
// If admin or barangay_official:
// socket.emit('join_admin');
```

When opening a message thread:
```dart
socket.emit('join_request', { 'requestId': request.id });
```

---

## 7. Push Notification Triggers

| Trigger | Who gets notified | Title | Body |
|---------|-------------------|-------|------|
| New request posted | All admins/barangay officials | `"New Resource Request — {category}"` | `"{name} from {barangay} needs {quantity} {unit} of {item}"` |
| New pledge received | Requester (Person A) | `"Someone offered to help!"` | `"{pledgerName} can help with your {item} request. Tap to review."` |
| Pledge accepted | Pledger (Person B) | `"Your offer was accepted!"` | `"Coordinate with {requesterName} in the chat to arrange delivery."` |
| Pledge declined | Each declined pledger | `"Thank you for offering"` | `"Another helper was chosen for this request."` |
| New message received | The other participant | `"New message from {senderName}"` | `"{text truncated to 60 chars}"` |
| Delivery marked | Requester (Person A) | `"{helperName} says delivered!"` | `"Please confirm you received your {item}."` |
| Request fulfilled | Both parties | `"Request fulfilled!"` | `"The {item} request has been confirmed as received."` |
| CDRRMO official offer posted | All residents in that barangay | `"CDRRMO Supply Available"` | `"CDRRMO {barangay} is offering {quantity} {unit} of {item}."` |

---

## 8. Web Developer Checklist (React/Node.js)

### Backend Tasks

- [ ] **Import `mongoose`** at the top of `server/routes/community.js` (needed for ObjectId validation in schedule endpoint)
- [ ] **Create `server/models/ResourceMessage.js`** — new model (see Section 4b)
- [ ] **Update `server/models/ResourceRequest.js`** — add pledges array, matchedPledgerId, deliveredAt; extend status and actionLog enums (Section 4a)
- [ ] **Update `server/models/ResourceDonation.js`** — add isOfficial, matchedRequestId (Section 4c)
- [ ] **Update `server/index.js`** — add `join`, `join_admin`, `join_request` Socket.IO handlers (Section 6)
- [ ] **Update `POST /api/community/requests`** — change default status from `"pending"` to `"open"`; extend Layer 1 duplicate check: `status: { $in: ["open","pending","approved","matched"] }`
- [ ] **Add `GET /api/community/board`** — community board endpoint (Section 5.1)
- [ ] **Add `POST /api/community/requests/:id/pledge`** — (Section 5.6)
- [ ] **Add `DELETE /api/community/requests/:id/pledge`** — (Section 5.7)
- [ ] **Add `PATCH /api/community/requests/:id/accept-pledge`** — called by REQUESTER, not admin (Section 5.8)
- [ ] **Add `PATCH /api/community/requests/:id/deliver`** — called by PLEDGER (Section 5.9)
- [ ] **Add `PATCH /api/community/requests/:id/confirm`** — called by REQUESTER or admin (Section 5.10)
- [ ] **Add `GET /api/community/pledges/mine`** — returns requests user has pledged on (Section 5.14)
- [ ] **Update `PATCH /api/community/requests/:id/fulfill`** — keep for admin force-fulfill; update guard to allow `open` or `matched` status (not just `approved`)
- [ ] **Update `PATCH /api/community/requests/:id/cancel`** — allow requester to cancel their own request: check `request.userId.toString() === req.user.id || isAdmin`
- [ ] **Add `GET /api/community/requests/:id/messages`** — import ResourceMessage; enforce participant-only access (Section 5.12)
- [ ] **Add `POST /api/community/requests/:id/messages`** — enforce participant-only access; emit `new_message` to `request-{requestId}` room (Section 5.13)
- [ ] **Update `POST /api/community/donations`** — accept `isOfficial` field; if `isOfficial: true` and sender is not admin/barangay, return `403`
- [ ] **Update `PATCH /api/community/donations/:id/schedule`** — accept optional `matchedRequestId`; validate it if provided (Section 5.17)
- [ ] **Remove** old `PATCH /requests/:id/approve` and `PATCH /requests/:id/reject` endpoints (no longer used)

### Frontend Tasks

**`client/src/components/community/helpers.js`**
- [ ] Add `"open"` → `"text-blue-600"` / `"bg-blue-600"`
- [ ] Add `"matched"` → `"text-purple-600"` / `"bg-purple-600"`
- [ ] Keep `"pending"`, `"approved"` entries for backward compatibility

**`client/src/hooks/useCommunitySharing.js`**
- [ ] Add `board` state `{ requests: [], donations: [] }` + `boardLoading`
- [ ] Add `fetchBoard(barangay = "")` → `GET /api/community/board`
- [ ] Add `messages` state `{}` (keyed by requestId) + `messagesLoading`
- [ ] Add `fetchMessages(requestId)` → `GET /api/community/requests/:id/messages`
- [ ] Add `sendMessage(requestId, text)` → `POST /api/community/requests/:id/messages`
- [ ] Export all new state and functions

**`client/src/components/community/RequestsView.jsx`**
- [ ] Replace TABS with `["Open", "Matched", "Fulfilled", "Cancelled"]`
- [ ] Add "Offers" column: purple badge `"N offers"` when non-withdrawn pledges exist
- [ ] Update empty-state `colSpan` to match new column count

**`client/src/components/community/RequestDetailModal.jsx`**
- [ ] Remove Approve and Reject buttons entirely
- [ ] Add "Community Offers" section: list all pledges with name, phone, message, status badge
  - `pending` → grey "Pending" label (admin view only — admin cannot accept)
  - `accepted` → purple "Accepted" badge
  - `declined` → grey strikethrough "Declined"
- [ ] Add Message Thread section:
  - Load messages via `fetchMessages(req._id)` when modal opens
  - Show messages in chronological order with sender name + role badge
  - Admin can type and send (calls `sendMessage`)
  - Subscribe to `new_message` Socket.IO event to append in real time
- [ ] Add admin force-fulfill button (visible when status is `open` or `matched`)
- [ ] Update `isTerminal` to `["fulfilled","cancelled"]` only

**`client/src/components/community/DonationsView.jsx`**
- [ ] Add green "Official" badge on rows where `don.isOfficial === true`
- [ ] Add purple "Linked" badge when `don.matchedRequestId` is set

**`client/src/components/community/DonationDetailModal.jsx`**
- [ ] In schedule mode: fetch board for barangay → populate request dropdown for optional linking
- [ ] Pass `matchedRequestId` in schedule body
- [ ] Show "CDRRMO Official" badge if `don.isOfficial === true`
- [ ] Show linked request info if `don.matchedRequestId` is set

**`client/src/pages/CommunitySharingPage.jsx`**
- [ ] Add third tab `{ key: "board", label: "Community Board" }`
- [ ] Call `fetchBoard()` on tab switch to `"board"`
- [ ] Render `CommunityBoardView` inline component:
  - "Open Needs" list — requests with priority/urgent badges + pledge count
  - "Available to Give" list — donations with isOfficial badge
  - "Post CDRRMO Offer" button (admin only) — opens donation form pre-set with `isOfficial: true`
  - Label: *"This is what residents see on their mobile app."*

---

## 9. Mobile Developer Checklist (Flutter)

### New Screens to Build

#### Screen 1: Community Board (`CommunityBoardScreen`)

Entry point for community sharing. Add as a tab or navigation button.

**API:** `GET /api/community/board?barangay=<user barangay>`  
Refresh on pull-to-refresh.

**Layout:**
- Barangay filter selector (default: logged-in user's barangay)
- Section 1: "Open Needs" — request cards
- Section 2: "CDRRMO Supplies" — `isOfficial: true` donation cards
- Section 3: "Community Offers" — community donation cards

**Request card fields:** item name, category icon, quantity + unit, requester name (first + last initial only), barangay, urgency badge, priority badge, pledge count (`"2 people offered to help"`). Tap → `RequestDetailScreen`.

**Donation card fields:** item name, quantity, donor name (or "Anonymous"), barangay, CDRRMO badge if official.

---

#### Screen 2: Request Detail (`RequestDetailScreen`)

Shown when browsing a request from the board (as Person B).

**Actions based on state:**

| Condition | Show |
|-----------|------|
| Status `open`, user ≠ requester, no pledge yet | "I Can Help" button |
| Status `open`, user already pledged | Pledge status badge + "Withdraw Offer" |
| Status `matched` | "Go to Chat" button |
| Status `fulfilled` or `cancelled` | Status label only |

"I Can Help" → opens Pledge Form (Section 3 below).  
"Withdraw Offer" → `DELETE /api/community/requests/:id/pledge`  
"Go to Chat" → `RequestChatScreen`

---

#### Screen 3: Pledge Form

Modal or bottom sheet. Opens from "I Can Help."

**Fields:**
- Message (optional): short offer text
- Phone (optional): contact number

**Submit:** `POST /api/community/requests/:id/pledge`  
**Success toast:** "Your offer was sent! The requester will be notified."

---

#### Screen 4: My Requests (`MyRequestsScreen`)

Shows logged-in user's OWN requests. **Different from the board** — this is Person A's view.

**API:** `GET /api/community/requests/mine`

**Tabs:** Open | Matched | Fulfilled | Cancelled

**Open tab cards:** show pledge count badge. Tap → `MyRequestDetailScreen`.

**`MyRequestDetailScreen`:**
- Shows request info + reason
- Lists all pledges: name, phone, message, status badge
- "Accept" button on each `pending` pledge → `PATCH /:id/accept-pledge` with `{ pledgeId }`
- After matched: "Open Chat" button → `RequestChatScreen`
- "Cancel Request" button → `PATCH /:id/cancel`

---

#### Screen 5: Chat Thread (`RequestChatScreen`)

For matched requests. Accessible by both Person A and Person B.

**Load on open:** `GET /api/community/requests/:id/messages`  
**Send:** `POST /api/community/requests/:id/messages`

**UI:**
- Chat bubbles: own messages right, other's left
- CDRRMO messages get a special badge
- Timestamps on each message

**Action buttons below chat:**

| Who | When | Button |
|-----|------|--------|
| Person B (pledger) | Status is `matched` | "Mark as Delivered" → `PATCH /:id/deliver` |
| Person A (requester) | `deliveredAt` is not null | "Confirm Receipt" → `PATCH /:id/confirm` |

**Socket.IO on this screen:**
```dart
socket.emit('join_request', { 'requestId': request.id });
socket.on('new_message', (data) => /* append to chat */);
socket.on('request_delivered', (data) => /* show Confirm Receipt button */);
```

---

#### Screen 6: My Pledges (`MyPledgesScreen`)

Shows all requests this user has pledged to help with.

**API:** `GET /api/community/pledges/mine`

**Tabs:** Pending | Accepted | Declined

**Each card shows:** item name, barangay, requester name, my pledge status.

**Accepted tab:** Show "Open Chat" → `RequestChatScreen`

---

### Global Socket.IO Listeners (add to app-level connection setup)

```dart
// After connecting and joining user room:
socket.emit('join', { 'userId': currentUser.id });

socket.on('new_pledge', (data) {
  // Show in-app banner: "{pledgerName} offered to help"
  // Refresh MyRequestsScreen if visible
});

socket.on('pledge_accepted', (data) {
  // Show banner: "Your offer was accepted!"
  // Refresh MyPledgesScreen if visible
});

socket.on('pledge_declined', (data) {
  // Show banner: "Another helper was chosen. Thank you!"
  // Refresh MyPledgesScreen if visible
});

socket.on('request_delivered', (data) {
  // Show banner: "Your helper says delivered — please confirm"
  // If RequestChatScreen for this request is open, show Confirm button
});

socket.on('community_request_updated', (data) {
  // Refresh board and my-requests screens if open
});
```

---

### Push Notification Deep Links (FCM tap handling)

| Tag prefix | Navigate to |
|------------|-------------|
| `request-{id}` | `MyRequestDetailScreen` |
| `pledge-{id}` | `MyRequestDetailScreen` (to review pledges) |
| `message-{id}` | `RequestChatScreen` |
| `delivered-{id}` | `RequestChatScreen` |

---

## 10. Error Handling (Both Developers)

### Server always returns:
```json
{ "success": false, "error": "Human-readable message" }
```

| Code | Meaning |
|------|---------|
| `400` | Validation / wrong state |
| `401` | No JWT |
| `403` | Wrong role or not the owner |
| `404` | Resource not found |
| `409` | Conflict (duplicate pledge, duplicate active request in category) |
| `500` | Server error |

### Mobile error handling:
- `401` → redirect to login screen
- `403` → toast "You don't have permission to do this"
- `409` on pledge → toast "You've already offered to help with this request"
- `409` on request create → toast "You already have an active {category} request"
- `400` on message → show character counter; disable send button when > 1000 chars
- Network timeout → show retry button

### Web error handling:
- Pledge accept failure → inline error message in pledges section
- Message send failure → retry button in chat area
- Force-fulfill failure → modal error display

---

## 11. Testing Checklist

### Happy Path (must all pass)
- [ ] Person A posts a request → appears on community board immediately
- [ ] Person B pledges → Person A receives push notification
- [ ] Person C also pledges → Person A sees both offers in `MyRequestDetailScreen`
- [ ] Person A accepts Person B's pledge → Person C gets "declined" notification, Person B gets "accepted" notification, request status = `matched`
- [ ] Person A and Person B send messages to each other
- [ ] Admin opens the request in the web panel → sees pledge list and message thread; can send a message
- [ ] Person B taps "Mark as Delivered" → Person A gets notification
- [ ] Person A taps "Confirm Receipt" → request status = `fulfilled`, Person B gets confirmation
- [ ] Admin posts CDRRMO offer with `isOfficial: true` → appears with CDRRMO badge on board

### Edge Cases (must all be blocked)
- [ ] Person B tries to pledge on their OWN request → `403`
- [ ] Person B pledges twice → `409`
- [ ] Person B tries to withdraw an accepted pledge → `400`
- [ ] Person A tries to accept a withdrawn pledge → `400`
- [ ] Person C tries to read message thread (not a participant) → `403`
- [ ] Regular user posts donation with `isOfficial: true` → `403`
- [ ] Person A posts a second food request while one is already `matched` → `409`
- [ ] Non-pledger tries to call `/deliver` → `403`
- [ ] Non-requester tries to call `/confirm` → `403`

---

## 12. What Is NOT Changing

These existing features are completely untouched:

- Donation flow: offered → scheduled → received (and auto-inventory-transfer on received)
- Inventory management system
- All hazard, alert, reports, and evacuation endpoints
- Push subscription / VAPID setup
- Authentication and JWT logic
- Alert engine and cron jobs

---

## 13. File Summary

| File | Action | Developer |
|------|--------|-----------|
| `server/models/ResourceRequest.js` | Modify — pledges, matchedPledgerId, deliveredAt, extended enums | Web |
| `server/models/ResourceDonation.js` | Modify — isOfficial, matchedRequestId | Web |
| `server/models/ResourceMessage.js` | **Create new** | Web |
| `server/routes/community.js` | Modify — 9 new endpoints, 4 updated | Web |
| `server/index.js` | Modify — Socket.IO room join handlers | Web |
| `client/src/components/community/helpers.js` | Modify — open/matched colors | Web |
| `client/src/hooks/useCommunitySharing.js` | Modify — board, messages, sendMessage | Web |
| `client/src/components/community/RequestsView.jsx` | Modify — new tabs, offers column | Web |
| `client/src/components/community/RequestDetailModal.jsx` | Modify — pledges panel, message thread | Web |
| `client/src/components/community/DonationsView.jsx` | Modify — official/linked badges | Web |
| `client/src/components/community/DonationDetailModal.jsx` | Modify — linked request, official badge | Web |
| `client/src/pages/CommunitySharingPage.jsx` | Modify — Community Board tab | Web |
| `MOBILE_API.md` | Add new endpoints from Sections 5.1–5.14 | Web |
| Flutter: `CommunityBoardScreen` | **Create new** | Mobile |
| Flutter: `RequestDetailScreen` | **Create new** | Mobile |
| Flutter: `MyRequestsScreen` + `MyRequestDetailScreen` | **Create new** | Mobile |
| Flutter: `RequestChatScreen` | **Create new** | Mobile |
| Flutter: `MyPledgesScreen` | **Create new** | Mobile |
| Flutter: Global Socket.IO listeners | Add to existing connection setup | Mobile |
