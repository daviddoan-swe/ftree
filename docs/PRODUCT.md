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

---

## 5. Family Permissions

Initial roles:

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

Exact permission details may evolve before cloud sharing is implemented.

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
