# Family Tree — Product Definition

## 1. Product Vision

Family Tree is a private mobile application that allows families to create, maintain, explore, and share their family history.

The application should make it easy to understand relationships across multiple generations while keeping family information private and under family control.

Initial platforms:

* iOS
* Android

The application is intended for relatively small trusted groups rather than public social networking.

## 1.1 Audience and culture

The application is multicultural from the start. Vietnamese families are the
first audience, but nothing may assume a Vietnamese family.

What follows from that:

**Interface strings are externalised from the first screen.** Retrofitting
localisation means unpicking several hundred strings out of widgets. Unlike the
decisions in DOMAIN.md §18 this loses no data, but it is avoidable work.

**Culture-specific features are opt-in per family, not per viewer.** The lunar
calendar is the case that exists today: `Family.usesLunarCalendar` travels with
the tree, so a relative abroad reading the application in another language
still sees the family's giỗ.

**Name display order follows the reader, name storage does not.** Storing
`displayName` as entered rather than composing it from parts (DOMAIN.md §3.1)
already sidesteps the Western given-then-family versus East Asian
family-then-given problem. Only the suggestion offered at data entry needs to
follow the locale.

**Search must ignore diacritics.** "Nguyen" has to find "Nguyễn". Relevant when
search is built, not before.

---

## 2. Primary Users

Typical users include:

* family administrators
* relatives
* extended family members
* invited trusted users

A family may contain people who do not have application accounts.

A Person in the family tree and an authenticated User are therefore different concepts.

---

## 3. V1 Goals

V1 should allow a user to:

1. Create a family.
2. Edit a family — its name, its notes, and whether it keeps the lunar calendar.
3. Delete a family.
4. Add a person.
5. Edit a person.
6. Delete a person.
7. View a person's profile.
8. Create parent-child relationships.
9. Create spouse relationships.
10. Remove a relationship without removing either person.
11. View multiple generations as a family tree.
12. Navigate between people in the tree.
13. Store data locally.

The initial goal is to prove that the core family-tree domain and visualization work correctly.

**Every entry point has a way back.** Editing and deleting are listed above
beside creating, not left for later. A transcription session produces mistakes
— a name mistyped, a person entered twice, a family created by accident — and
an application that can only add turns each of them into permanent damage.

**There is no undo.** Deletion writes a tombstone rather than erasing a row
(DOMAIN.md §15.1), but nothing in the interface restores one. The guard is
therefore in front of the action, and it is sized to the loss: removing a
person is a confirmation naming how many relationships go with them; deleting a
whole family — years of transcription — requires typing its name back.

---

## 4. Cloud Phase

After the local application is stable, users should be able to:

1. Create an account.
2. Synchronize family information.
3. Access their family from another supported device.
4. Invite another user to a family.
5. Assign family permissions.
6. Share updates between authorized family members.

### 4.1 An account is never needed to use the application

**Decided.** The application works, completely, with no account and no
network. Three ways of using it, and only the third asks for one:

| | What somebody is doing | Account |
| --- | --- | --- |
| 1 | Recording their own family, on their own device | **No** |
| 2 | Sending a relative a copy to read | **No** — a file (§9.1) |
| 3 | Several people keeping **one** record between them | **Yes**, for those people |

An account is asked for at the moment somebody wants the third thing, never at
the door. Most people who use this will want the first, and a sign-in wall in
front of it is a wall in front of the whole application — against the offline
capability the project lists fourth among its goals.

So there is no sign-in screen at launch. Sharing is an action on **one family**
— a "Chia sẻ" alongside export, edit and delete — and signing in happens there,
with a sentence saying what it is for. Somebody who never presses it never sees
it.

**A relative who is to edit must register.** There is no way round that: the
server decides what anybody may touch from the identity in their token, and an
identity means an account. It is real friction for an elderly relative, and it
is reduced rather than removed — an invitation leads straight into signing up
rather than leaving somebody to find it.

**A relative who only wants to read does not.** They get a file. That path
stays, and it is the right one for most of a family.

Whether an account is made with an email address or a phone number is **open**.
A phone number is the identity Vietnamese users actually remember; an SMS code
costs real money per message, which §9's total-cost thinking has to weigh.

### 4.2 Only a family that is shared leaves the device

**Decided.** Pressing Chia sẻ on one family sends that family. Every other
family on the device is untouched and unknown to the server, including after
the account exists.

This follows from what an account is for. Signing in is not a statement about
everything on the device; it is what one family needs in order to be kept by
more than one person.

Two earlier decisions make it work rather than merely describe it:

* Identifiers are globally unique (DOMAIN §14.1), so a family moves to the
   server keeping the id it already had. There is no renumbering and no table
   of translations.
* The server decides who owns a family from the token of whoever created it,
   so the person who presses Chia sẻ becomes its owner without anything being
   asserted by the client.

What it needs that does not exist yet: the device has to remember which of its
families are shared, since it cannot ask the server while offline. That is one
column, and it travels with the synchronisation metadata the local schema needs
anyway.

What stays open for synchronisation: a family may be on the device only, on
both, or — for somebody who has just been invited — on the server only. Listing
families then has to answer from two places, which is the point at which the
repository boundary is worth splitting rather than before (ARCHITECTURE §7).

### 4.3 Two devices holding one family: the first to press owns it

**Decided.** Whoever presses Chia sẻ first becomes the owner. The second person
is told that the family is already kept by somebody else, and that an
invitation from them is the way in.

The case is ordinary, not exotic. A sends B a file; the file carries the family
keeping its id (DOMAIN §14.1), which is what lets a later file be merged in
rather than arriving as a second gia phả. So after one export both devices hold
the same family, and each device's record of what it has shared is right about
itself and silent about the other. Both see the button.

**There is no fairer rule available.** A file carries no proof of who made it,
and cannot: at the moment of export there may be no account anywhere on the
device, so there is nobody to sign it. The server is asked to decide between
two identical claims and has nothing to weigh. First press wins is not a
compromise between better options; it is the only rule the data supports.

What this deliberately does not prevent: B, who received a file, can press
first and own A's gia phả. A is then locked out of it — not shown an error but
shown nothing, because a family A is not a member of is absent rather than
forbidden. The protection is social. In the ordinary flow A shares first,
because A is the one who wants the record kept.

**Handing a family over is a separate feature**, deferred. It needs an owner
willing to do it, which makes it a conversation between people with a button
at the end rather than a rule. Until it exists, the answer to "the wrong person
owns it" is that they invite the right one as an editor.

Three things the interface owes a person here:

* Chia sẻ is not offered for a family this device has marked as shared, so the
   refusal is usually never reached.
* When the mark is missing but the family is ours, **the mark is recovered
   rather than the family re-sent.** This is the reinstall, and the restore from
   one's own exported file: the device has forgotten, the server has not. Sending
   again would put the restored copy on top of the shared one, which is the
   conflict resolution nobody can do yet (DOMAIN §15.3). So nothing is sent, the
   mark is rebuilt from what the server already knows, and the button stops being
   offered.
* When it is reached anyway — two people pressing at once — the refusal says
   what happened. A primary-key violation is not an explanation.

The second of those is why "a device that imported a file may not share" was
rejected as a rule: it would have caught the person restoring their own backup,
which is the same act from the device's point of view and the opposite act from
the person's. Asking the server tells them apart; a local flag cannot.

### 4.4 Registering is an email address and a password

**Decided**, after weighing phone numbers, emailed codes, the nineteen OAuth
providers Supabase offers, and no account at all.

**Phone numbers lost on regulation, not on price.** Supabase does not send SMS
itself; the message leaves through Twilio or a competitor, at roughly $0.29 per
message to a Vietnamese number. That is affordable. What is not is Decree
91/2020: sending an OTP to a Vietnamese number requires a brandname registered
with Viettel, Vinaphone or MobiFone, approval takes weeks, and since August 2024
every message must carry that registered name. A private family application has
no company brandname to register. This is closed, not expensive.

**Email and a password won on independence.** Of what remained it is the only
option that depends on nobody — no carrier, no Google, no Facebook, no Zalo. It
is also already written and already tested against a real auth server.

**No account at all was considered and rejected.** A long secret key carried in
the file, so that whoever holds the file may write, needs no accounts. It cannot
be taken back: withdrawing access from one person means re-keying for everybody.
It cannot say who made an edit, which the field-level merge will need. And RLS
is written against `auth.uid()`, so it would require issuing tokens ourselves —
a custom authentication server, which CLAUDE §9 rules out without a
demonstrated need.

**Anonymous sign-in was the closest to "just a unique account", and is the
trap.** It yields a real `auth.uid()` with nothing asked. But the session lives
in the device's storage, so a lost or wiped phone loses that identity for good,
and with it ownership of the family — with nothing to prove who you were. A
username is not there to identify somebody; `auth.uid()` already does that. It
is there so an account can be **recovered**. For an application whose purpose is
keeping a hundred years of records, that is not a secondary feature; it is what
an account is for.

What it costs: somebody has to remember a password, and production needs real
SMTP to confirm addresses. Both are acceptable, and the first is small because
very few people ever need an account — an owner and a handful of editors, while
everybody who only wants to read receives a file (§4.1).

**Adding a provider later breaks nothing.** `auth.uid()` is the same value
whatever the person signed in with, so every policy, membership and trigger sits
underneath the choice rather than on top of it. Facebook is the strongest second
option for this audience, and it can be added when somebody is actually stuck.

---

## 5. Family Permissions

Initial roles:

### 5.0 What each role may do on the device

**Decided.** The interface offers a control only where the role on that family
allows it. What follows is the whole table; every row but one mirrors a policy
that already exists on the server.

| | not shared | owner | editor | viewer |
|---|---|---|---|---|
| Export a file | ✓ | ✓ | — | — |
| Chia sẻ | ✓ | — | — | — |
| Thành viên | — | ✓ | — | — |
| Rename the family | ✓ | ✓ | — | — |
| Delete the family | ✓ | ✓ | — | — |
| Add a person | ✓ | ✓ | ✓ | — |
| Edit a person | ✓ | ✓ | ✓ | — |
| Delete a person | ✓ | ✓ | ✓ | — |
| Add or remove a relationship | ✓ | ✓ | ✓ | — |
| Import a file into it | ✓ | ✓ | ✓ | — |

**What the gia phả is called is the owner's, like whether it exists.** An
editor's work is the people inside: a great-grandmother added, a birthplace
corrected, a duplicate removed. Each of those is one record, and a mistake in
one costs one record. Renaming the family changes what the whole household sees
it called, on every device, with no per-record bound on the damage — which puts
it beside deleting the family rather than beside editing a person. The server
says the same: `20260926000001_family_naming.sql` takes the editor's UPDATE on
`families` away entirely, leaving the owner's as the only one.

**A family that was never shared has no role and every right.** There is
nobody else it could belong to. The same is true of one that arrived as a
file: a file carries no rights, so a copy made from one is simply yours (§5.7).

**The role belongs to the family, not to the device or the account.** Somebody
holding one family they made themselves and one they were invited into as an
editor has full rights on the first and restricted rights on the second, at
the same time, on the same phone. That is why it is a column on the family
row.

**A role can change under the device, and the device has to notice.** The
answer is cached for as long as the application is running, so a demotion made
on somebody else's phone would otherwise leave the old controls in place until
the application was restarted — an editor demoted to viewer still being offered
Sửa and Xoá. It is asked again whenever a family is opened, which is already
the moment a request is spent, and whenever the application comes back to the
front. Between those the answer may be stale, and the server refusing is what
keeps that safe rather than merely untidy.

**This mirrors the server; it does not replace it.** Every row above except
Export corresponds to a policy in `20260924000003_policies.sql` or a migration
that later narrowed one, and the policies are what actually decide. Hiding a control is a courtesy — it stops
somebody doing work that would be refused — and CLAUDE §8 is explicit that
client-side authorization is never the thing being relied on.

**Export is the exception, and it is only a rule.** Exporting never touches
the server, so no policy can refuse it; hiding the button is the whole of the
enforcement. It is worth having because it closes the easy, accidental path —
dropping a file into a group chat — and states the intent plainly. It is not
worth calling security: an editor has the whole gia phả on their device
already, because that is what editing requires. Anybody who can read a record
can copy it, and no arrangement of buttons changes that.

**Where the role comes from.** Two moments where the device knows it for
certain, both of which already write to the local database:

* pressing Chia sẻ — this device is the owner
* accepting an invitation — the code says which role it grants

It is stored beside `sharedAt` and read without a network, so it holds on a
train.

**It is not cleared when signing out**, unlike `sharedAt`. The two say
different things: `sharedAt` records what this device did and can be recovered
by asking (§5.9), while the role records *how this copy came to be here*. A
copy that arrived as an editor's copy stays one, and clearing it on sign-out
would hand full rights to anybody who signed out.

**It is kept in step by asking.** When the application opens with a session it
asks the server, in one request, for every role this account holds, and writes
the answers down. A promotion, a demotion and a removal all reach a device that
way, which is the only thing that does before M9 — nothing else synchronises.

**A family the server does not name is one this account was put out of**, and
the copy is locked to reading. Every control goes, and the screen says why: a
row of buttons vanishing with no explanation reads as the application breaking
rather than as a decision somebody took.

**Deleting that copy is deferred**, deliberately, until M9. An editor's own
additions have never left their phone — there is nowhere for them to go yet —
so erasing the copy would destroy work that exists nowhere else, and would
still not be security, because a file may have been exported long before. Once
synchronisation exists those additions are on the server, and deleting the
local copy costs nothing; that is when to do it.

**Asking is skipped unless the answer can be trusted.** No session, no network,
no cloud opened at all: each of those leaves the roles alone. "The server named
nothing" and "the server could not be reached" look identical from here, and
one of them would mark every family removed.

**One case defeats that guard, and it is worth knowing.** A session whose
account no longer exists still carries a valid token, so the server answers —
with an empty list. Every family then reads as removed. In ordinary use nobody
is deleted out from under their own session; in development, resetting the
database does exactly that, and the device has to be signed out by hand
afterwards.

### 5.1 Who may invite, and to what

**Decided.** Only an owner may invite. **Any** of the three roles may be
invited, owner included, and inviting an owner asks first.

Editors cannot invite. An editor who could invite editors would widen the
circle without the owner ever seeing it happen, and a circle is far easier to
widen than to narrow. Loosening this later costs nothing; tightening it would
mean taking something away from people who already had it.

__Owner is invitable because a gia phả is meant to outlive one person.__ A
family kept by a single account dies with that account — a lost phone, a
forgotten password, a person who dies. A second owner is how the record
survives that, and nothing in the schema ever forbade it: `keep_an_owner`
requires _at least_ one owner, not exactly one.

It also softens §4.3. Where the wrong person pressed Chia sẻ first, they can
now hand the family back by inviting the right person as owner. That is not a
transfer — the first owner stays — but it unblocks somebody locked out of a
gia phả they themselves built, which was the sharpest cost of first-press-wins.

**What it costs, plainly.** An owner can delete the whole family, and can make
further owners. There is no super-owner, and until removing a member exists
there is no way to walk any of it back. So the warning is not decoration: it
has to say what the new owner will be able to do, not merely that the role is
important.

Friction proportional to harm, as everywhere else here (§10): a confirmation,
not a typed name. Deleting a family destroys a hundred years of transcription
and asks for the name to be typed; inviting a second owner is a decision that
can be regretted but not an act that loses anything.

### 5.2 An invitation is a code, passed on by hand

**Decided.** The owner's device makes a ten-character code, sends the server
only its hash, and hands the code to whatever the family already uses — Zalo, a
message, email. It works **once** and expires after **seven days**.

The alphabet leaves out `O`, `0`, `I` and `1`: a code is read off one screen
and typed into another, and one nobody can transcribe is one nobody uses. What
is compared is a canonical form — upper case, punctuation dropped — so `k7p2
9xmr4t` opens what was issued as `K7P2-9XMR-4T`.

**Only the hash is stored**, so a database that escapes carries nothing that
opens a family. Ten characters from thirty-two is about fifty bits, which would
be thin for a bearer secret standing alone and is not standing alone: it dies
after one use and after a week.

**Single use earns its place twice.** The obvious job is limiting damage. The
one found by thinking it through is that it makes theft *visible* — somebody
who intercepts a code and uses it first leaves the intended reader looking at
"this code has already been used", which is how the owner learns anything is
wrong. A code that worked twice would be stolen in silence.

A link that opens the application directly was considered and deferred: it
needs a domain and a file hosted on it for the phone to verify, which is
infrastructure rather than code.

A code meant for a whole branch, reusable and gated by approval, is proposed in
§5.8 and deferred to M9. It does not replace this one; it sits beside it.

### 5.3 No approval, and what stands in its place

**Decided.** A valid code lets somebody in immediately. There is no queue for
the owner to work through.

The owner has already decided twice — when they made the code, and when they
chose who to send it to. A third decision, taken later against an email address
they may never have seen, would be approved without looking. It would also
leave the invited person waiting on somebody else opening an application, which
for a relative who was sent a code and expected it to work is the difference
between joining and giving up.

**What replaces it is seeing and removing.** The owner can see every member by
the address they signed up with, and remove any of them. A door that opens and
cannot close would be worse than a slow lock, so removing a member is not a
later refinement; it is the other half of this decision.

The last owner cannot be removed. A family nobody can manage is a family nobody
can ever be invited into.

This holds for a code sent to **one person**. §5.8 proposes a code sent to a
group, where the owner never chooses a recipient at all — and there approval
becomes the only per-person decision there is, rather than a second one.

### 5.4 The owner's device keeps the codes it issued

**Decided.** Codes for invitations that are still standing are held on the
device that made them, so the Lời mời screen can show one again and send it
again. Used or revoked, it is forgotten.

This does not weaken §5.2. Hashing defends against the *server* being read; the
owner's phone already holds the whole gia phả, and anybody who can unlock it
can issue a fresh invitation in three taps. What it buys is the ordinary
accident: the message was closed before it was sent.

A device that has forgotten — a reinstall, a different phone — still lists the
invitation and can still revoke it. It simply has nothing left to send, and
says so rather than pretending.

### 5.5 Accepting downloads the family, once

**Decided.** Entering a valid code writes the gia phả onto that device
immediately. Without it the invitation would be a permission nobody can see:
the application reads its own database, so the invited person would open it and
find nothing at all.

It is **not** synchronisation. Afterwards the two copies drift — the owner adds
somebody and the guest does not see it, the guest edits and nothing goes up —
until M9. What an invitation buys today is the gia phả and a membership waiting
for the day two copies can talk.

It arrives through the **same add-only merge a file does**, and that is not
tidiness. Somebody may have been sent the exported file first, imported it, and
added their own branch before the invitation came. The file and the server
carry the same family id (§4.3), so an overwrite would land on that branch and
take it.

---

### Owner

Can:

* manage the family
* manage people and relationships
* invite users
* change permissions
* remove users

### Editor

Can:

* view family information
* add people
* edit people
* manage permitted relationships

### Viewer

Can:

* view permitted family information

An owner changes a role and removes somebody from the member list (§5.6).
Both are the owner's alone: an editor who could promote themselves would make
the distinction between the two meaningless.

### 5.6 The member list, and who may open it

**Decided.** Reached from **Thành viên** on a family that has been shared —
labelled for what pressing it does, which is to open the room rather than to
send an invitation. Inviting is a button inside it, and making a code is not
something that should happen as a side effect of looking. Two
sections: the people who already have access, then the invitations standing
against the family.

A member's row is **a name, an address and a role, and nothing to press.**
Managing somebody is behind a left swipe, as it is on the family list, giving
**Sửa** and **Xoá**. A row is for reading; demoting a relative or putting them
out are not things to leave under a thumb while scrolling.

* **Sửa** offers the three roles — the same sheet an invitation uses, so
  promoting somebody already here and inviting somebody at that role read as
  one idea. Promoting to owner asks first, for the reason §5.1 gives.
* **Xoá** takes away everything. See below.

**Your own row has nothing behind it.** Leaving a family is a different act
from running one, and this screen is reached by whoever runs it.

**Only an owner sees any of this.** An editor or a viewer who opens it is told
whose job it is. This reverses what §5 first said — that members see each
other, because knowing who can read a gia phả is part of knowing whether it is
private. The decision went the other way: the list is where somebody is demoted
or put out, and that is not done in front of an audience. What an editor loses
is the ability to see who else has access; what they keep is that the owner
they trusted chose everybody in it.

**A name is asked for when an account is created**, and shown here instead of
an address. It belongs to the person rather than to any one family — somebody
in three families should not have three names — so it is carried in the account
itself. An account made before names were asked for has none, and the row says
so rather than wearing its address as one: an address with its domain cut off
is not a name.

### 5.7 An administrator is not necessarily in the gia phả

Worth stating, because the two are easy to confuse and nothing in the schema
connects them.

A **person in the gia phả** is a record — a great-grandfather, a great-aunt,
somebody long dead. They have no account, and `Person` holds no user id. An
**administrator** is an account with access to a family on the server. An owner
is not required to appear in their own gia phả, and the people in it are not
required to have accounts.

So **removing somebody takes away every right they had** — editor, viewer and
owner alike. The family goes back to being invisible to them. Three things are
deliberately left alone:

* **Their account.** It may belong to other families. Deleting it is theirs to
  do, not their former owner's.
* **The gia phả.** If that same person also appears in the tree, that record
  stays: it is a note about the family, not about an account.
* **Whatever they already downloaded.** It sits on their phone and **cannot be
  recalled.** The confirmation says so plainly rather than implying otherwise.

The membership row is tombstoned rather than erased, as everything else here
is (DOMAIN §15.1). That keeps the record of who was let in, and it means
inviting them again later simply works: accepting revives the membership they
had.

### 5.9 Signing out, and what it takes with it

**Decided.** An account button appears on the family list **only while signed
in**, and opens a screen showing the name, the address, and a way out. Most
people never sign in (§4.1); a permanent button would be advertising an
account to somebody with no use for one, and offering to manage something that
is not there.

**Signing out clears two local things**, because both belong to the account
that is leaving rather than to the device:

* the marks saying which families this device sent up (§4.2)
* the invitation codes this device is holding (§5.4)

Left behind, the first would lie to whoever signs in next and the second would
hand them somebody else's live codes.

**Clearing the marks is safe because it heals itself.** A family with no mark
offers Chia sẻ again. Pressing it asks the server, which says the family is
claimed — and then, for the same account, that it can see it, which is case 2
of §4.3: the mark is recovered and nothing is sent. Signed in as somebody
else, the same press is told another account holds it, which is true.

**Clearing the codes does not heal**, and the confirmation says so rather than
letting somebody find out later. An invitation still standing cannot be sent
from this device again; revoking it and making another is the way back.

The gia phả itself is untouched, and still works with nobody signed in. That
is the whole of §4.1 and signing out must not quietly walk it back.

### 5.8 A code for a whole branch, with approval — deferred to M9

**Proposed and written down rather than built.** One code an owner can hand to
a family group, reusable for a while, giving **viewer** access only — so that
nobody has to make a code per relative. Everybody who uses it lands in a
pending list, and the owner lets them in one at a time.

This revisits §5.2 and §5.3 rather than adding to them, so the reasoning is
kept here in full.

**Reusable and approval need each other.** Single use earns its place by making
theft *visible* (§5.2): whoever intercepts a code and uses it leaves the
intended reader looking at "already used". A reusable code gives that up — a
stranger walks in silently. Approval restores it by another route: a stranger
appears in a list, with a name the owner does not know. So the pair is coherent
and **either half alone is not**. A reusable code with no approval is the
dangerous shape.

**And the argument against approval does not reach this case.** §5.3 rejects a
queue because the owner already decided twice — making the code, and choosing
who to send it to. With a code meant for a group, the owner never made the
second decision at all. Approval is then the only place a decision about a
particular person is ever taken, which is the opposite of a gate clicked
through.

It also only became workable when accounts started carrying names (§5.6).
Approving `nguyenvana1983@gmail.com` is guessing; approving *Nguyễn Văn Hải* is
deciding.

**"Without even registering" contradicts approval, with one way out.** To
approve somebody you must be able to name them and grant access to *them*. With
no account there is no them. Dropping approval and letting whoever holds the
code download is the bearer-key design §4.4 already rejected: nothing can be
withdrawn from one person, nobody can be told apart, and RLS is written against
`auth.uid()`, so it would mean issuing tokens ourselves.

The way out is **anonymous sign-in** — a real `auth.uid()` with no email and no
password. §4.4 rejects it, but rejects it *for owners*: losing the phone loses
the identity and the family with it. A viewer owns nothing, so losing it costs
them a second look at the code. The objection does not cover them.

What that buys is a name the person types themselves, which **nobody
verifies**. An owner approving is trusting the name together with the fact that
whoever typed it had the code. For a code passed around a family's own group
chat that is a reasonable thing to trust — but it should be understood as
trust, not as proof.

**Why it waits for M9.** Until synchronisation exists, a viewer who downloads
through the cloud has exactly what somebody sent the exported file has: one
snapshot, never updated. §4.1 already offers that, and it costs nothing. What
the cloud path adds is that the server remembers them, ready for the day two
copies can speak — which is M9. Building the pending list now would be building
a queue to hand out something a file already hands out.

**The cost to weigh when it is built:** a pending list is an inbox the owner
has to remember to open. With no push notifications a request can sit for
weeks. Somebody who asked with a group code expects to wait, which softens it,
but it is still a new obligation on the one person who did not ask for one.

### 5.10 Deleting, and who it reaches

Two different acts wear the same word, and the difference is who the role table
already gives the button to (§5.0).

**A family nobody else has a claim on, or one the owner deletes, goes for
everybody.** The owner's tombstone travels to the server and to every member's
device at their next synchronisation. This was decided over the alternative of
keeping deletion local to the device that pressed it, and the cost was accepted
openly: a family deleted by mistake takes the whole household's work with it,
and there is no undo. What argued for it is that the owner is the one person
entitled to decide a gia phả should not exist, and a delete that did not reach
anybody would leave them unable to act on that decision at all.

**Nobody else has the button.** `mayDeleteFamily` is the owner's, or belongs to
a family with no role at all — one made on this device or brought in as a file.
An editor may delete *people*; they may not delete the family those people are
in. That is stated twice on purpose, once in the interface and once in the
policy, because the second is the one that holds: `families_update_editor`
carries `deleted_at IS NULL` on both halves, and `delete_family_deep` refuses
outright unless the caller is the owner.

The second check is not decoration. The three tables' policies are not uniform:
`persons_update` and `relationships_update` say only "owner or editor", because
an editor removing one person is ordinary work. So an editor who reached
`delete_family_deep` would have tombstoned every person and every edge while the
family row survived — a gia phả of three hundred people reduced to a name, no
error raised, because an UPDATE a policy forbids changes nothing and reports
success.

**A removal that meets an edit is put to somebody.** One relative removes a
person while another is writing their biography. Neither answer may be taken
quietly: applying the tombstone destroys work that cannot be recovered, and
ignoring it sends the person back up alive and undoes a deletion nobody was
told about. So it is held as a question, the same way a disagreement about a
field is (§4.2), and asked as one question about the person rather than field by
field — there is no version of somebody both gone and corrected.

Which answer is already selected is whatever the device holds. It holds them
alive when the server removed them, and holds a tombstone when this device's own
owner pressed delete. Pressing on through therefore never reverses a decision
somebody here took deliberately, in either direction.

**Relationships are not asked about.** An edge carries no recorded detail, only
which two people it joins, and changing that makes it a different edge. A
tombstone for one is applied. Asking would be asking about nothing.

---

## 6. Person Information

V1 Person may contain:

* identifier
* display name
* given name
* additional names
* family name
* family name at birth (maiden name)
* sex — male, female, or unknown
* date of birth
* date of death
* place of birth
* place of death
* biography/notes
* profile photo reference

Most biographical fields should be optional because historical family information may be incomplete.

Two consequences of that incompleteness are part of V1 rather than deferred:

**Dates may be partial.** "1887", "March 1887", "about 1890" and "15 March 1887"
are all valid entries. Forcing a full date makes users invent day and month
values, which destroys the distinction permanently.

**Dates may carry a lunar reading.** Vietnamese family records are written in
the lunar calendar. A person's dates may therefore be recorded in both: a
Gregorian date, which the application requires, and the lunar date the source
actually gave.

**Family name at birth is recorded separately.** A person whose surname changed
on marriage appears under two surnames across records, and the birth surname is
what links them into their parents' branch.

The exact schema is defined in DOMAIN.md.

### 6.1 Lunar calendar and giỗ

Vietnamese family records are written in the lunar calendar, and giỗ — the
death anniversary — is observed on the lunar date. Modern documents use the
Gregorian calendar. A single tree will contain both, sometimes for the same
person.

Three requirements follow.

**Entry in either calendar.** The user chooses which calendar they are typing
in and the application converts. Requiring Gregorian only would force someone
transcribing a family record to leave the application, convert each date by
hand elsewhere, and type it back — hundreds of times for a real tree, with a
chance of error each time.

**Display in both.** A date is shown as Gregorian with its lunar reading
alongside: *07/04/1960 (12/3 âm lịch, năm Canh Tý)*. Older relatives read the
lunar date, younger ones the Gregorian; neither should have to convert in their
head.

**Upcoming giỗ.** A list of death anniversaries falling soon, each shown as the
lunar date it is fixed to and the Gregorian date it lands on this year. This is
what makes the application worth opening every year rather than once.

The conversion this rests on is built at M1.5. Whether the giỗ list itself
ships in V1 is not yet decided — the capability exists either way.

---

## 7. Relationships

Initial supported relationships:

* Parent → Child
* Spouse ↔ Spouse

The application should not assume:

* every parent is known
* every marriage is known
* a person has only one spouse during their lifetime
* every relationship has complete dates
* a person has at most two parents
* a person is connected to the rest of the family at all

### 7.1 Imperfect data must be storable

Family records contain implausible but genuine entries, and transcription
errors that the user wants to save and investigate later.

The application therefore distinguishes two kinds of problem:

* **Errors** — structurally impossible data, such as a person being their own
   ancestor. These are refused.
* **Warnings** — implausible but possible data, such as a parent aged fifteen or
   a child born shortly after the father's death. These are shown to the user,
   who can confirm and save anyway.

An application that refuses everything unusual cannot record real genealogy.

---

## 8. Family Tree

The family-tree interface should eventually support:

* multiple generations
* pan
* zoom
* selecting a person
* navigating to a profile
* clear representation of parent-child relationships
* clear representation of spouse relationships

Performance should remain reasonable for family trees containing hundreds or potentially thousands of people.

---

## 9. Offline Use

Core family information should be available locally.

Users should eventually be able to:

* browse existing family information offline
* make supported changes offline
* synchronize when connectivity becomes available

Detailed synchronization behavior is not part of the first implementation milestone.

### 9.1 The data must be able to leave the device

A family tree lives in the application's own private storage, which both iOS
and Android delete when the application is uninstalled. A user must be able to
**export one family to a file** they keep themselves, and to **import** such a
file back.

This is not a feature waiting on synchronization. Until synchronization exists,
a file is the only way a hundred years of transcription survives a reinstall.
After it exists, a file is still how a branch reaches a relative who does not
want an account.

**Import adds; it never overwrites.** Deciding which copy is newer needs a
clock that can be trusted, and devices do not have one (DOMAIN.md §15.3).
Anything already on this device is left exactly as it is. The cost has to be
said plainly in the interface rather than discovered: a correction made on a
relative's device does not travel.

Built, in the application's own JSON format — see ROADMAP M6.5 for why not
GEDCOM and not a copy of the database file.

### 9.2 A file that leaves is a file that cannot be recalled

The export used to be plain JSON: names, dates, birthplaces and the lives of
living relatives, readable by anybody holding the file. One reaching one wrong
person reaches everybody they forward it to, and there is no taking it back.

**Every export is sealed with a password.** Not an option somebody can turn on,
because a lock that has to be remembered is a lock nobody turns. The file is
`.ftree` and its contents are noise without the password.

**What it protects, and what it does not.** It protects a file that is
*found* — left in a chat application's cache, in a Downloads folder, on a
phone somebody lost. Against that it is complete. It does **not** protect
against the person it was sent to passing on the file *and* the password. No
file encryption can. Access that can be withdrawn from one person is the cloud
invitation (§5.5), not a file, and anybody choosing between the two should
know that is the difference.

**Setting one asks twice; entering one asks once.** A typo when setting cannot
be found out later — there is nothing to check against, and the file is the
only copy of a hundred years of transcription. When entering, the file itself
is the check, and asking for a passphrase twice on every restore buys nothing
it does not already give.

**Twelve characters at least, and a passphrase is welcome.** Spaces and
Vietnamese letters included: four ordinary words somebody can remember resist
an offline attack better than eight characters of punctuation nobody can
recall, and are what people will actually use.

**The sentence the whole thing depends on** is on the screen that sets the
password: send it by another route. A password pasted into the same message as
the file protects nothing, and it is what most people will do unless told
otherwise. It is the one line here that is not about cryptography and the one
that decides whether the cryptography matters.

**Losing the password loses the backup.** There is no way back in, by design —
and it is a real cost for a record meant to outlive the person keeping it
(§5.1). The screen says so where the password is chosen, not in a note
afterwards.

**The interface says none of this in mechanism.** The button is "Xuất dữ
liệu"; the wait is "Đang xuất file…". How the file is protected is the
application's business. What somebody must *act* on — that losing the password
loses the file, and that the password travels separately — is not mechanism,
and is said plainly.

---

## 10. Privacy

Family information is private by default.

Users should only access families for which they have permission.

A person's presence in a family tree does not automatically mean that person has a user account.

Privacy controls may become more granular in later versions. The most likely
next requirement is **restricting information about living people from Viewers**
— birth dates, places, and photographs of living relatives are more sensitive
than the same data about ancestors.

This is not built for V1, but two things follow from it now:

* **Death is derived, and one-way.** A person has died when a death date *or* a
   place of death is recorded (DOMAIN.md §3.5). Either is somebody writing down
   that this person died; neither is a record that says nothing on the subject.
   Nothing may read the absence of both as "living" — it means *nothing was
   recorded*, which for most of a gia phả is the truth. Where the difference
   matters, the words are "no death recorded".
* The eventual sharing mechanism must be able to give a user part of a family
   rather than all of it.

**What this cannot yet express.** A person the family knows perfectly well has
died, but whose date and place nobody remembers, cannot be recorded as dead:
the form refuses a claim it has nothing to store behind. Such an ancestor is
shown the same as somebody nothing is known about — not greyed on the chart,
not greyed in a list.

For a gia phả reaching back three centuries this is common rather than rare.

**Decided: left as it is for V1.** Closing the gap means storing the fact
separately from its evidence — a column, and a schema version for every device
already carrying one. What the present rule buys is that the answer is derived,
so no column can be wrong about it and nothing can contradict anything else.
The gap costs an ancestor the grey they have earned; it costs no data.

Reversible cheaply, which is why it waits: adding the column later is an
ordinary migration, not the kind whose price has to be paid at the start
(DOMAIN.md §18).

---

## 11. Explicitly Outside Initial V1

Do NOT initially implement:

* public social networking
* public family search
* chat
* messaging
* video
* advertising
* AI features
* complex notifications
* genealogy DNA integration
* payment/subscription systems
* advanced analytics
* public APIs
* GEDCOM import/export — the international interchange format, and worth
   adding later so a family is never locked into this application. The
   application's **own** file format is in scope now, and is a different job
   (§9.1)

These features may be reconsidered later.

---

## 12. Product Success for Initial Development

The initial product milestone is successful when:

1. A family can be created locally.
2. Multiple people can be created.
3. Relationships can be defined correctly.
4. Structurally invalid relationships are rejected, and implausible-but-possible
   data is flagged as a warning the user can accept.
5. A multi-generation family tree can be generated from the data.
6. The tree can be rendered and navigated on iOS and Android.
7. Person information can be created, viewed, and edited.
8. A family can be exported to a file and imported back, and importing loses
   nothing that was already there.

Item 8 is listed alongside the rest rather than after them. Until it was done,
every family entered into the application was one uninstall away from gone —
a larger risk than anything else on this list.

**All eight are now met** (ROADMAP M6.5). What remains before cloud work is
not a gap in this list.

Only after this foundation is stable should cloud sharing become a priority.
