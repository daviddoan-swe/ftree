# Family Tree — Product Definition

## 1. Product Vision

Family Tree is a private mobile application that allows families to create, maintain, explore, and share their family history.

The application should make it easy to understand relationships across multiple generations while keeping family information private and under family control.

Initial platforms:

* iOS
* Android

The application is intended for relatively small trusted groups rather than public social networking.

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
2. Add a person.
3. Edit a person.
4. View a person's profile.
5. Create parent-child relationships.
6. Create spouse relationships.
7. View multiple generations as a family tree.
8. Navigate between people in the tree.
9. Store data locally.

The initial goal is to prove that the core family-tree domain and visualization work correctly.

---

## 4. Cloud Phase

After the local application is stable, users should be able to:

1. Create an account.
2. Synchronize family information.
3. Access their family from another supported device.
4. Invite another user to a family.
5. Assign family permissions.
6. Share updates between authorized family members.

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

* Whether a person is living is a deliberate recorded decision, not something
  inferred from a missing death date. Many deceased ancestors have no recorded
  death date.
* The eventual sharing mechanism must be able to give a user part of a family
  rather than all of it.

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
* GEDCOM import/export

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

Only after this foundation is stable should cloud sharing become a priority.
