# Court Report — Project Configuration

## What This Is

**Court Report** is an app that puts all of a racket sport player's tennis (and eventually other racket sport) life in one place — schedules, teams, leagues, availability, rosters. Today, players and captains jump between different apps and sites for different teams and leagues. Court Report is the "one app" that replaces that mess.

**In Tara's words:**
> "It's an app for players and captains to have all tennis platforms in one app. We jump from schedule to schedule for different teams and leagues. It would be extremely beneficial for all players, coaches and teams to have it all in one place."

- **Product name:** Court Report
- **Production URL:** https://yourcourtreport.com (SSL via Thruster + Let's Encrypt)
- **Droplet IP:** 146.190.112.29 (still works, but use the domain)
- **Who it's for:** All racket sport players, captains, and coaches. Not just tennis — also pickleball, squash, padel, etc. (future). Not just USTA — any league.
- **End goal:** Tara is building this for herself first, but wants to turn it into a real product that other people pay for.

**Key people:**
- **Tara Bucci** — primary user, admin, captain of multiple USTA teams. **Building this app alone.**
- **Jaclyn ("Jaci") Staples** — Tara's teammate, first "real" user beyond Tara.
- **Tara's husband** — built the tiiny.host mockup as a design example to show Tara what Claude could do. **Not involved in building the Rails app.**

## Critical Dates

**Known real first-match dates for each of Tara's four teams:**

| Date | Day | Team | League | First Match |
|------|-----|------|--------|-------------|
| **April 14, 2026** | Tue | Kiss My Ace | USTA 40+ | vs. Kinetix Deuces Wild (HOME, Bryn Mawr Racquet Club) |
| **April 17, 2026** | Fri | Pour Decisions | USTA 18+ | vs. No Drama Mamas |
| **April 27, 2026** | Mon | Philadelphia Country #2 | Inter-Club | vs. Laurel Creek #1 (AWAY, 10:00 AM) |
| (already over) | — | Legacy 2 | Del-Tri | Season ran Oct 3, 2025 – Mar 20, 2026 |

**April 21 note:** When Tara first mentioned "April 21" as the deadline for her second team, she was approximating. **No team actually has an April 21 first match.** The real next-after-April-14 date is **April 17 (Pour Decisions)**. So the practical "by when must Court Report work?" target is:
- **April 14:** Kiss My Ace opener. Tara will use MatchTime for this one.
- **April 17:** Pour Decisions opener. First real opportunity to use Court Report.
- **April 27:** PCC opener. Second real opportunity.

## How Tara Prefers to Work

**Tara is not a technical person.** Important working norms:

- **Plain language only.** No jargon. Don't say "migration" — say "database update." Don't say "turbo stream" — say "the page updates without reloading." Don't say "deploy" without explaining "push the code to the live server."
- **Be direct and specific.** Tell her exactly what to click, exactly what to type, exactly what URL to visit.
- **Be honest about uncertainty.** If code isn't tested, say so out loud. If you're guessing, say so.
- **Phase work in small pieces.** Don't try to build everything at once. Get one slice working and shippable before starting the next.
- **Verify before declaring victory.** Don't say "done" if you haven't actually tested it works in a browser.
- **Ask before building.** If the task doesn't match what's in the code, ask clarifying questions first — don't just start coding on assumptions.

## Current Status (as of April 12, 2026 — Session 9)

### What's actually live at https://yourcourtreport.com
**Phase 1 is live with SSL and auto-deploy infrastructure:**
- **HTTPS/SSL** — Auto-provisioned via Thruster + Let's Encrypt. Works on both `yourcourtreport.com` and `www.yourcourtreport.com`
- **Court Report marketing homepage** — shows to logged-out users with "All Your Teams. One App." messaging and Sign In / Sign Up buttons
- **Email-only login** (tarabucci@gmail.com)
- **My Teams page** with real team data (43 users, 16 matches)
- **Team detail pages** with hero, schedule, roster, availability
- **Player profile pages** with NTRP rating + match stats
- **Admin user management** (Players page)
- **`/stats-test` page** — pulls live data from a public Google Sheet on every page load (proof of concept for dynamic external data). Sheet: `1OvOObnk_Sq5wZOX8sQHnUfn_PNTXrgSgGnqqS8QeIjI`

### What was fixed in Session 9 (April 12, 2026)
- Enabled SSL/HTTPS via Thruster + Let's Encrypt (port 443, TLS_DOMAIN env var, thruster cert storage volume)
- Fixed DNS: `www` CNAME now points to `yourcourtreport.com` (was pointing to `teamcourtreport.com`)
- Opened port 443 in the DigitalOcean firewall
- Created SSH `deploy_key` on the droplet for GitHub Actions auto-deploy
- Added GitHub Actions deploy workflow (`.github/workflows/deploy.yml`)
- **Consolidated main branch** — main is now the single source of truth, matching the deployed code. Previously, many parallel `claude/*` branches had diverged and main was outdated.
- Added `/stats-test` page pulling from Google Sheets

### What's still broken / pending
- **GitHub Actions Deploy workflow is failing** — SSH authentication error (`ssh: no key found`). The `DEPLOY_SSH_KEY` secret in GitHub needs to be re-added correctly. Multi-line SSH keys can be hard to copy from mobile — recommend doing this from desktop. Until fixed, deploys must be done manually on the droplet.
- **CI workflow may have test/lint failures** from code added in Session 9. Needs investigation.
- **No captain auto-assignment.** When a team is created, there's no automatic team_membership record making the creator a captain.
- **Mobile UI** — some tabs may still get cut off. Partially fixed in Session 9 but needs verification on actual deployed version.

## The Two "Court Reports" (historical context)

There used to be **two different things** both being called "Court Report":

1. **The Rails app** (this repo) — now deployed at https://yourcourtreport.com with SSL. Real backend, real database, can save data.
2. **The tiiny.host mockup** at `courtreport.tiiny.site` — static HTML/CSS built by Tara's husband as a **design example**. Pretty but not functional.

**Status (as of Session 9):** The Rails app is fully functional, styled, and live at yourcourtreport.com with SSL. The tiiny.host mockup is no longer in use for production.

## Real Team Data

### League Structure (the "3 leagues, 4 teams" realization)

**Tara plays in THREE different leagues across FOUR teams:**

| League Category | League/Organizer | Team Name |
|-----------------|------------------|-----------|
| **USTA** | USTA Middle States (Philadelphia) | **Kiss My Ace** (Adult 40+) |
| **USTA** | USTA Middle States (Philadelphia) | **Pour Decisions** (Adult 18+) |
| **Inter-Club** | Philadelphia country-club league | **Philadelphia Country Club (PCC)** |
| **Local Leagues** | Del-Tri (Delaware-Tri-State area) | **Legacy 2** |

**This is the core problem Court Report solves.** These three leagues all live in different systems — USTA has TennisLink, Inter-Club has its own country-club scheduling, Del-Tri has its own website. Tara has to check FOUR different places to know her schedule. Court Report puts all four teams in one app.

**The tiiny.host mockup already reflects this structure:** top-level tabs labeled USTA, Inter-Club, Local Leagues, with teams nested inside each league category.

**Data model implication:** The current `tennis_teams` table has no concept of league category. We'll need a `league_category` field (or a separate `leagues` table) so teams group correctly in the UI. This is NOT blocking — we can ship with a simple string field for now.

### Kiss My Ace (captured from TennisLink, Session 7)

**League & Format:**
- League: **USTA Adult 40 & Over**
- Flight: **4.0 Women Delches** (Tuesdays, Sub-Flight 2)
- Rating: **4.0**
- Gender: **Women's**
- Section: **Middle States** (District: Philadelphia)
- Match format: 1S, 4D (1 singles + 4 doubles lines)
- Season: **April 13, 2026 — June 30, 2026**

**First match (the April 14 deadline):**
- Date: Tuesday, April 14, 2026
- Opponent: Kinetix Deuces Wild (HOME)
- Location: Bryn Mawr Racquet Club, 4 N Warner Ave, Bryn Mawr, PA 19010

**Captain:**
- **Jaclyn Groenen** — `jaclyn.groenen@gmail.com`, 610-329-8911
- **IMPORTANT: Tara is a player on Kiss My Ace, NOT the captain.** Earlier assumption was wrong.

**Division opponents:**
- Kinetix Deuces Wild
- Love Hurts
- Unmatchables (note: was in old seed data — probably Tara's previous team)
- Tennis Addiction

**Full roster (22 players):**

| Name | NTRP |
|------|------|
| Stephanie Giordano | 3.5 |
| Amanda Neill | 4.0 |
| Leslie Brinkley | 3.5 |
| Rebecca Feinberg | 3.5 |
| **Jaclyn Groenen (captain)** | 4.0 |
| Lynn Sundblad | 4.0 |
| Rachel Chadwin | 4.0 |
| Amanda Neczypor | 3.5 |
| Helen Lee | 3.5 |
| Helen He | 4.0 |
| Sarah Brautigan | 4.0 |
| Mary Marshall | 4.0 |
| Alison Vachris | 4.0 |
| Doris Kerr | 4.0 |
| **Tara Bucci** | 4.0 |
| Nicole Costelloe | 4.0 |
| Christina Faidley | 4.0 |
| Jody Staples | 3.5 |
| Karli McGill | 4.0 |
| Kerry McDuffle | 4.0 |
| Vanessa Halloran | 4.0 |
| Bridget Hallman | 4.0 |

### Pour Decisions (captured from TennisLink, Session 7)

**League & Format:**
- League: **USTA Adult 18 & Over**
- Flight: **4.0 Women Del-Ches** (Fridays, Sub-Flight 1)
- Rating: **4.0**
- Gender: **Women's**
- Section: **Middle States** (District: Philadelphia)
- Season: **April 13, 2026 — June 30, 2026**

**Captain:**
- **Lynn Sundblad** — `vino33@hotmail.com`, 267-253-2323
- **Tara is a player, not the captain** (same as Kiss My Ace)

**Home court:** Radnor Valley Country Club, 555 Sproul Rd, Villanova PA 19085

**Full schedule (8 matches):**

| Date | Opponent |
|------|----------|
| 4/17/2026 | No Drama Mamas |
| 4/24/2026 | St. Albans |
| 5/8/2026 | UD Smash Squad |
| 5/15/2026 | Simply Smashing |
| 5/29/2026 | Merion Cricket 18+ |
| 6/5/2026 | Philly Cricket |
| 6/12/2026 | Quad Squad |
| 6/19/2026 | Kicking Aces |

**NOTE:** Pour Decisions' first match is **April 17, NOT April 21.** The April 21 deadline Tara mentioned must belong to her **third** team (Legacy 2). Need to confirm.

**Division opponents:**
Quad Squad (was in old seed data!), UD Smash Squad, Kicking Aces, St. Albans, No Drama Mamas, Simply Smashing, Merion Cricket 18+, Philly Cricket

**Full roster (17 players):**

| Name | NTRP |
|------|------|
| Jaclyn Groenen (captain of Kiss My Ace) | 4.0 |
| **Lynn Sundblad (captain)** | 4.0 |
| Amanda Neill | 4.0 |
| Rachel Chadwin | 4.0 |
| Rebecca Feinberg | 3.5 |
| Helen Lee | 3.5 |
| Amanda Neczypor | 3.5 |
| Kerry McDuffie | 4.0 |
| Nicole Costelloe | 4.0 |
| **Tara Bucci** | 4.0 |
| Olivia Andrews | 4.0 |
| Kristin Kobell | 3.5 |
| Christina Faidley | 3.5 |
| Lisa Tan | 3.5 |
| Jody Staples | 3.5 |
| Karli McGill | 4.0 |
| Leslie Brinkley | 3.5 |

### Observations about Kiss My Ace ↔ Pour Decisions

These two teams are effectively **"sister teams"** with heavy roster overlap:

- **14 of 17 Pour Decisions players also play on Kiss My Ace**
- **Jaclyn Groenen** captains Kiss My Ace and plays on Pour Decisions
- **Lynn Sundblad** captains Pour Decisions and plays on Kiss My Ace
- **Tara plays on both** (as a player, not captain, on either one)

**Small inconsistencies between the two TennisLink rosters:**
- "Kerry McDuffle" (Kiss My Ace) vs "Kerry McDuffie" (Pour Decisions) — likely the Pour Decisions spelling is correct.
- Christina Faidley: 4.0 on Kiss My Ace, 3.5 on Pour Decisions (NTRP may display differently by league type).

**Design implication:** A player can be on many teams. The data model already supports this via `team_memberships`, but we need to make sure the UI treats "My Teams" as a list of all teams a user belongs to (not just teams they own or captain).

### Philadelphia Country Club #2 — Inter-Club (captured Session 7)

**League & format:**
- League: **Philadelphia Inter-Club Tennis, Cup 6** (Monday league)
- Division: **Cup 6**
- Season: **April 27, 2026 – June 8, 2026** (7-match regular season, Mondays at 10:00 AM)
- Home club: **Philadelphia Country Club**, 1601 Spring Mill Road, Gladwyne, PA 19035 (610-525-7788)
- Club Representatives: **Deborah Dixon** and **Lindsey Schontz** (not captains — Inter-Club uses "club reps")

**Captain:** No explicit "captain" shown on the Inter-Club website. Tara is listed as **position #1** in the roster, which suggests she may be a team leader even without the title.

**Full schedule (7 matches, all 10:00 AM Mondays):**

| Date | H/A | Opponent |
|------|-----|----------|
| 4/27/2026 | Away | Laurel Creek #1 |
| 5/4/2026  | Home | Waynesborough #3 |
| 5/11/2026 | Away | Philadelphia Cricket #3 |
| 5/18/2026 | Home | Dupont CC #1 |
| 5/26/2026 | Away | Delsea #2 (note: Tuesday, Memorial Day week) |
| 6/1/2026  | Home | Overbrook #2 |
| 6/8/2026  | Away | West Chester #2 |

**First match: April 27, 2026 (Monday) vs. Laurel Creek #1 (AWAY).**

**Division opponents (Cup 6):** Delsea #2, Dupont CC #1, Laurel Creek #1, Overbrook #2, Philadelphia Cricket #3, Waynesborough #3, West Chester #2

**Primary roster (12 players, organized by position):**

| Pos | Player |
|-----|--------|
| 1 | **Tara Bucci** |
| 1 | Joanne Steinberg (also captain of Legacy 2!) |
| 2 | Jaci Gronen |
| 2 | Amanda Neczypor (also on Kiss My Ace + Pour Decisions) |
| 3 | Jill Kirchner (also on Legacy 2) |
| 3 | Laura Zalewski (also on Legacy 2) |
| 4 | Lynda Donahue |
| 4 | Anne Siembieda |
| 5 | karen ernst |
| 5 | Robyn Leto |
| 6 | Ryan Longstreth |
| 6 | Laurie Nowlan |

**Subs:** Nancy Fox, Jen Gallagher, Rachel Miller (also on Legacy 2), Christi Neilly

### The "Jaci" mystery — SOLVED (confirmed by Tara, Session 7)

Looking across the rosters, the name "Jaci" / "Jaclyn" shows up three ways:

1. **Jaclyn "Jaci" Groenen** — captain of Kiss My Ace, player on Pour Decisions, player on PCC, 4.0 USTA. The "Jaci" Tara first mentioned. **She is Tara's captain on Kiss My Ace.**
2. **Jaci Gronen** (PCC roster) — same person as Jaclyn Groenen; the Inter-Club website has a typo in the last name.
3. **Jody Staples** — a **different person**. Plays on Kiss My Ace and Pour Decisions with Tara. Often confused with Jaci because of similar-sounding names, but confirmed by Tara to be a separate teammate.

**Confirmed by Tara (Session 7):** "Jody Staples and Jaci Groenen. Two different people. Both teammates. Jaci is our captain."

### Correction: Tara is a PLAYER on all four teams, not a captain

Earlier CLAUDE.md said "Tara is a captain of multiple USTA teams." The real TennisLink / Inter-Club / Del-Tri data shows that is **not correct**. Tara is:
- **Kiss My Ace:** player (captain is Jaclyn Groenen)
- **Pour Decisions:** player (captain is Lynn Sundblad)
- **Legacy 2:** player (captain is JoAnne Steinberg)
- **PCC:** position #1 player, no formal captain, two "club reps"

**Tara is not the captain of any of her current teams.** She's building Court Report as a **player**, not a captain. This might actually matter for the app design — the primary use case is "player managing her own availability across four teams," not "captain managing a roster."

### Cross-team players (the "real people" data model)

Looking across all four rosters, many players appear on multiple teams:

- **Tara Bucci** — plays on all 4
- **JoAnne Steinberg** — Legacy 2 captain + PCC player
- **Jaclyn ("Jaci") Groenen** — Kiss My Ace captain + Pour Decisions player + PCC player
- **Lynn Sundblad** — Pour Decisions captain + Kiss My Ace player
- **Amanda Neczypor** — Kiss My Ace + Pour Decisions + PCC
- **Jill Kirchner** — Legacy 2 + PCC
- **Laura Zalewski** — Legacy 2 + PCC
- **Rachel Miller** — Legacy 2 + PCC (sub)
- **Jody Staples** — Kiss My Ace + Pour Decisions

**Implication:** The user model must support one human being on multiple teams across multiple leagues. The current `team_memberships` table already supports this correctly. The seed file needs to dedupe players (create one User record, then multiple TeamMemberships).

### Legacy 2 — Del-Tri Local League (captured Session 7)

**Important: Legacy 2's season is FALL/WINTER (Oct 2025 – Mar 2026), already ended or ending.** This is NOT the April 21 team — its 2025-26 season just finished. April 21 must be PCC or another team.

**League & format:**
- League: **Del-Tri Tennis** (DELTRI TENNIS on the website)
- Division: **Division 4**
- Season: **October 3, 2025 – March 20, 2026** (fall/winter season, just ended)
- Home club: **Legacy Tennis**, 4842 Ridge Ave, Philadelphia PA 19129 (215-487-9555)
- Club rep: **JoAnne Steinberg**

**Captain:**
- **JoAnne Steinberg** (3.0 rating, 6W-6L record)
- **Tara is a player** (listed under "Players Also Subbing for Other Teams" — she's a regular but also subs elsewhere)
- Tara's Del-Tri rating: **3.5** (note: different from her USTA 4.0 rating — Del-Tri uses a separate rating system)

**Final 2025-26 standings (Division 4):**
| Rank | Team | Pts |
|------|------|-----|
| 1 | DVTA 3 | 70 |
| **2** | **Legacy 2** | **68** |
| 3 | Brandywine 5 | 58 |
| 4 | Springfield YMCA 3 | 56 |
| 5 | Brandywine 4 | 53 |
| 6 | Radnor Racquet 3 | 52 |
| 7 | HPTA 6 | 51 |
| 8 | Penn Oaks 5 | 48 |
| 9 | Tennis Addiction 4 | 45 |
| 10 | Upper Main Line Y 2 | 39 |

**Primary roster (9 players):** Anh Bixby (4.0), Rachel Miller (3.5), Tara Buchakjian (3.0), Khue Feigenberg (3.5), Rebecca Bramen (3.0), Sarah Dougherty (3.0), Leilani Schlottfeldt (3.0), Lindsey Schontz (3.0), Jill Kirchner (3.0), Laura Zalewski (3.5).

**Regular players who also sub elsewhere:** Tara Bucci (3.5)

**Subs from other teams who played for Legacy 2:** Jackie Wilson, Lorise Chow, Marla Cohen, Audra DelConte, Jennifer Enslin, Ronni Giannascoli, Denise Gozdan, Noelle Heckscher, Ina Nechita, Leslie Reber, Joye Shrager, Jamie Straszewski.

**Frozen players:** Ginger McGeer (3.5)

**Full schedule (18 matches, all played):** see TennisLink screenshots — team went approximately 12-6 over the season.

### Data model implications from Legacy 2

Legacy 2's structure is more complex than Kiss My Ace / Pour Decisions and forces us to think about:

1. **Roles beyond captain/player:** Del-Tri rosters have "captain," "player," "sub from other team" (S), "frozen player" (Frz). The current `team_memberships.role` field only knows "captain" and "player." Probably fine for MVP — we can collapse subs/frozen into "player" for now.

2. **League-specific ratings:** Tara is 4.0 in USTA but 3.5 in Del-Tri. Rating belongs on the **team membership**, not the **user**. Current model has `ntrp_rating` on `users` — will need to move or duplicate it per team.

3. **Season scope:** Legacy 2's season is already over. The app needs to handle "my current teams" vs "all my teams across all seasons." MVP decision: show all of Tara's teams, but mark Legacy 2 as "past season" so it's not in the active rotation.

4. **League categories have different seasons:** Del-Tri = fall/winter. USTA = spring/summer. Inter-Club = probably also spring. A team's season dates matter — there isn't just one "current season."

### Important notes

- **Jaci vs. Jody name question:** Earlier Tara referenced "Jaclyn ('Jaci') Staples" as her teammate. The Kiss My Ace roster shows "Jody Staples" (3.5) but no "Jaclyn Staples." These may be the same person (nickname) or Tara may have mis-remembered. The captain is a different person entirely: **Jaclyn Groenen**. Ask Tara to clarify.
- **"Unmatchables" in old seeds:** The old Rails seed file had "Unmatchables" as one of Tara's teams. The TennisLink data shows Unmatchables is now an opponent in Kiss My Ace's division — so this was likely Tara's team in a previous year (possibly a lower rating level).
- **The tiiny.host mockup said "Friday"** for Kiss My Ace but TennisLink confirms **Tuesday**. April 14, 2026 is a Tuesday. The mockup text was wrong.

## Session History

Reconstructed from git log. Tara has built this app over ~6 sessions.

| # | Focus | Key commits | Outcome |
|---|-------|-------------|---------|
| 1 | Initial Rails app, DigitalOcean setup, deploy pipeline | `312cd3a`, `f69d255`, `aeef49a` | Hello World deployed |
| 2 | GitHub Actions auto-deploy, fixes, import maps, basic theming | `3551f58`, `ca6e389`, `1b1df9f`, `520e8e5`, `fc71e58`, `3dcffde`, `48d40a7` | Deploys work on push |
| 3 | Tennis theme (Sabalenka quote), SVG icons, email-only login, user management | `f321583`, `4538c47`, `935dffe`, `1852951` | User login + management shipped |
| 4 | Sandbox restructure, permissions, add Jody Staples user | `4de514b`, `62702c4` | Nav reorganized, second user added |
| 5 | Player profile page with NTRP ratings and match stats | `68589da` | Profile page live |
| 6 | Teams 500 fix + availability feature | `d456d37`, `50316cd` | Code on branch, untested |
| 7 | CLAUDE.md overhaul, real team data capture, Phase 1 restyle + deploy | `ec55ae1`–`717881a` | **Phase 1 LIVE and verified by Tara** |
| 8 | Password auth added then reverted (Gemfile.lock mismatch), Legacy 2 scoring fixes | `cf1e17a`, `db95ec2` | Reverted password; legacy scoring corrected |
| 9 | SSL via Thruster, DNS fix, GitHub Actions auto-deploy, main consolidation, stats-test page | `6441e4b`, `3509a6b`, `68eb612` | **Site now on https://yourcourtreport.com; main = source of truth** |

## Lessons Learned (honest notes from past sessions)

### From Session 6 — don't repeat these
- **Claude built a large feature without running it.** The availability feature has 4 new database tables and hundreds of lines of code — none tested. Next time: run the database update, boot the app, click the buttons in a browser before claiming done.
- **Claude hand-edited `db/schema.rb`.** This file is auto-generated. Hand-editing it risks drift. Always run the database update command instead.
- **Claude tried to fix a bug without verifying the bug was real.** The "500 error on /teams/1" couldn't be reproduced because the real broken site was on tiiny.host, not in this Rails app. Next time: ask "can you show me the bug first?" before writing a single line.
- **Claude used technical language with a non-technical user.** Tara had to ask for plain English. Default to plain English always.

### From Session 9 — DON'T REPEAT THESE
- **Don't start work from a stale `claude/*` feature branch.** Always start from `main`. Previous sessions created many parallel branches; merging an old one wiped out features and broke the deployed site. **Main is the source of truth — always work from main.**
- **Don't merge a branch to main without verifying it has all the deployed features.** If main is currently empty/skeleton and the deployed site has features, the deployed code lives on a different branch. Find that branch first, merge it into main, THEN add new changes.
- **Bringing single files (like `courtreport.html.erb`) over from another branch without their controllers/routes/models breaks the app.** Either bring all dependent files or rebase the whole branch.
- **Multi-line SSH keys are nearly impossible to copy from a phone correctly.** GitHub Actions Deploy workflow needs SSH key setup from a desktop, not mobile.
- **Verify which branch the droplet is actually deploying from.** The `/root/app` directory on the droplet may be checked out to a branch other than `main`. Run `git branch` on the droplet before reasoning about what's deployed.

### From earlier sessions — deployment environment constraints
- **No `ssh-keygen`** in this sandbox — had to use `openssl genpkey` + Python stdlib to generate RSA keys.
- **No Docker daemon** running locally — all builds must happen on the remote server.
- **Outbound proxy is set.** Cannot directly test deployed URLs from this environment — Tara must verify in her browser.
- **No `ssh` client** available — cannot SSH into Droplets from this environment for debugging.

### Rails 8 Dockerfile notes
- Default uses `COPY vendor/* ./vendor/` — works as long as `vendor/.keep` exists.
- `SECRET_KEY_BASE_DUMMY=1` is used during `assets:precompile` to avoid needing the real secret at build time.
- `-j 1` flag on `bootsnap precompile` disables parallel compilation (avoids a QEMU bug on cross-architecture builds).

### DigitalOcean notes
- DO App Platform requires GitHub OAuth to be connected via the DO dashboard (browser-based) before you can deploy from a GitHub repo. No CLI workaround.
- The `docker-20-04` Marketplace image has Docker pre-installed on Ubuntu 22.04 — fastest way to get a Docker-ready Droplet.

## Technical Spec

**Framework:** Ruby on Rails 8.1.2
**Ruby:** 3.3.6
**Database:** SQLite (multi-database: primary, cache, queue, cable)
**Asset pipeline:** Propshaft
**Background jobs:** Solid Queue (running inside Puma via `SOLID_QUEUE_IN_PUMA`)
**WebSockets:** Solid Cable
**JavaScript:** Import Maps + Stimulus + Turbo (Hotwire)
**Web server:** Puma via Thruster
**Containerization:** Docker (multi-stage build, production-optimized)

## GitHub

**Repo:** `tarabucci-tennis/project-1` (public)
**Active feature branch:** `claude/fix-teams-500-error-GPgeR` (contains unverified Session 6 work — do not merge blindly)

## DigitalOcean Deployment

**Account:** tarabucci@gmail.com
**Token:** stored in `doctl` auth config (run `doctl auth list` to verify)

### Deployed Infrastructure

| Resource | Details |
|----------|---------|
| Droplet ID | `555081556` |
| Droplet Name | `project-1` |
| Public IP | `146.190.112.29` |
| Region | `sfo3` |
| Size | `s-1vcpu-1gb` |
| Image | `docker-20-04` (Ubuntu 22.04 + Docker pre-installed) |
| Firewall ID | `b6a72fad-0194-438c-9603-589490137155` |
| Firewall | Ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) open |
| Container Registry | `registry.digitalocean.com/tarabucci-tennis` |
| SSH Key ID | `54458995` (name: `do-deploy`) |

**App URL:** https://yourcourtreport.com
**Domain:** yourcourtreport.com (with www redirect)
**SSL:** Auto-provisioned via Thruster + Let's Encrypt

### Branching Strategy — READ THIS BEFORE STARTING ANY WORK

**The single source of truth is `main`.** Always.

- **Always start new work from `main`** — never from a stale `claude/*` feature branch.
- **Always pull the latest `main` first:** `git fetch origin && git checkout main && git reset --hard origin/main`
- **Feature branches should be short-lived** — create, push, merge PR to main, delete.
- **Never commit directly to main from the droplet** — all changes go through GitHub PRs.
- **Verify before merging:** if you're on a feature branch and unsure whether it has the latest main, rebase: `git rebase origin/main`

**Why this matters:** Previously, parallel Claude sessions created a dozen stale feature branches, each built on a different starting point. When one branch got merged to main, it wiped out features from other branches. This caused the deployed site to break. Never let main fall behind the deployed code.

### Auto-merge authorization (standing permission from Tara, Session 10)

Tara has given Claude **standing permission to auto-merge PRs** in `tarabucci-tennis/project-1` without waiting for explicit "merge it" every time. Normal flow:

1. Make changes, commit, push to the feature branch.
2. Open a PR via `mcp__github__create_pull_request`.
3. **Immediately merge it** via `mcp__github__merge_pull_request` in the same turn.
4. Tell Tara in the reply what was merged and what to do on her phone to see it (clear Safari cache, etc.).

**Still ask before merging** in these cases:
- The PR touches data-destructive operations — database migrations that drop columns, delete records, reset seeds, or otherwise can't be undone.
- The PR is a large refactor or architectural change Tara might want to look at first.
- Claude is not fully confident the change is correct (tests failing, unsure about logic, couldn't verify locally).
- The PR touches deploy infrastructure, SSH keys, secrets, GitHub Actions workflows, or domain/DNS config.
- The PR would affect code outside `tarabucci-tennis/project-1`.

When in doubt, pause and ask. Auto-merge is for normal day-to-day feature work and bug fixes, not for "I think this is probably fine" changes.

### Auto-Deploy (GitHub Actions)

Deployments are automated via `.github/workflows/deploy.yml`.

**Trigger:** Any push to `main` automatically deploys.

**How it works:**
1. GitHub Actions SSHes into the Droplet
2. Pulls the latest `main`
3. Builds a new Docker image
4. Stops and removes the old container
5. Starts a new container with SSL, volumes, and env vars
6. Runs `db:migrate` and `db:seed`

**Required GitHub Secrets:**
- `DEPLOY_HOST` — Droplet IP (`146.190.112.29`)
- `DEPLOY_SSH_KEY` — Private key matching `~/.ssh/deploy_key` on the Droplet
- `RAILS_MASTER_KEY` — Rails credentials master key

**To deploy:** Just merge a PR to `main`. No terminal commands needed.

### Manual Re-deploy (fallback)

If GitHub Actions fails, SSH into the droplet and run:
```bash
cd /root/app && git fetch origin && git checkout main && git reset --hard origin/main && docker build -t project-1 . && docker stop project-1 && docker rm project-1 && docker run -d -p 80:80 -p 443:443 -e RAILS_MASTER_KEY=$(cat /root/app/config/master.key) -e TLS_DOMAIN=yourcourtreport.com,www.yourcourtreport.com -v /root/storage:/rails/storage -v /root/thruster-storage:/rails/.thruster --name project-1 --restart unless-stopped project-1
```

SQLite databases are persisted via a Docker volume at `/root/storage`.
Thruster SSL certs are persisted via a Docker volume at `/root/thruster-storage`.

**Note:** After merging the Session 6 branch, you will also need to run database updates on the server: `docker exec project-1 bin/rails db:migrate db:seed`

## Open Questions (things Claude still needs from Tara)

**Answered in Session 7 (April 10, 2026):**
- ✅ Product vision — Tara's own words captured above.
- ✅ End goal — personal use first, then a real product for anyone who plays a racket sport.
- ✅ Who it's for — players, captains, coaches across any racket sport.
- ✅ Husband's involvement — none beyond the tiiny.host mockup.

**Still open:**
- [ ] **Real team data** — for each of Tara's current teams (Kiss My Ace, Pour Decisions, Legacy 2):
  - League (USTA?), rating (e.g. 4.0), gender, section
  - Number of players and their names/emails
  - Which team has the April 14 match and which has the April 21 match
  - Is Tara the captain of each?
  - Start date of the season
- [x] **Domain registrar** — `yourcourtreport.com` was purchased from **GoDaddy**. Tara will need to log in to GoDaddy and change the DNS A record to point to `146.190.112.29` (the DigitalOcean droplet) when we're ready to switch.
- [ ] **tiiny.host source files** — does Tara have access to the HTML/CSS files used for the mockup? Would help match the Court Report visual design exactly.
- [ ] **Has Session 6's code been tested?** Before merging `claude/fix-teams-500-error-GPgeR`, verify the teams page and availability feature actually work.
- [ ] **Future racket sports** — how soon does Tara want pickleball/squash/padel support? MVP = tennis only, but we should avoid baking "tennis" into the data model in ways that'll hurt later.

## Working Norms Going Forward

**At the end of every session, Claude updates this file with:**
- What was built, tested, and deployed (and what was NOT)
- New decisions made
- Answers to any Open Questions that got resolved
- New lessons learned
- New Open Questions that came up

**Think of this file as the project diary.** It's the first thing any future Claude session should read before writing any code.

## Session 8 (April 10, 2026 — evening)

### What was built, tested, and deployed

**All features are LIVE at http://146.190.112.29 on branch `claude/clarify-team-members-1ycVZ`.**

1. **Google Calendar button** — Calendar icon on Coming Up cards and Schedule tab. Opens Google Calendar with match title, date/time, location pre-filled. Tara uses this so her husband and family know where she is.

2. **Compact Coming Up cards** — Smaller cards with league label (USTA/DEL-TRI) above team name in gold, not clickable as links anymore but clickable to navigate to match detail page. Calendar icon inline inside card.

3. **Match detail page** (`/teams/:id/matches/:id`) — MatchTime-style layout with:
   - Header bar: date, time, HOME/AWAY badge, opponent, gold underline
   - Lineup table: Time | Line | Player | Confirmed/Pending/Declined
   - Lines grouped by position (1S, 1D-4D or Lines 1-6)
   - Confirm/Can't Play prompt for players in pending lineup
   - "No lineup posted" clean state
   - Set Lineup button only visible to captain/team creator (NOT admin)

4. **Lineup email notifications** — LineupMailer sends creative HTML email when captain publishes lineup. Black/gold branded email with tennis ball, match details, player's assigned position, and Confirm/Can't Play buttons. Requires Gmail SMTP setup (see below).

5. **Lineup confirm route fix** — Confirm now accepts GET requests so email links work (was PATCH-only, causing 404).

6. **Sign Up page** — New users can create an account with name + email at `/signup`. Gold "Sign Up" button in header for logged-out users. Auto-signs in after creation.

7. **Three ways to join a team:**
   - **Captain adds player** — Name + email form on Captain tab. Creates account if needed.
   - **Join link** — Each team gets a unique `/join/:code` URL. Captain shares via text. Players auto-join after signing up/in.
   - **Player self-service** — "Find a Team" search page and "Create a Team" form. Players can search by team name and join, or create their own team (becomes captain).

8. **Empty My Teams page** — Shows bouncing tennis ball + "Find a Team" and "Create a Team" buttons instead of blank message.

9. **Lineup position on Coming Up cards** — Shows black/gold badge (e.g., "1S", "2D") when you're in a published lineup.

10. **Legacy 2 full season results** — All 18 matches seeded with scores (2-4, 4-2, 6-0, etc.). Season completed Fall/Winter 2025-26.

11. **Del-Tri points-based standings** — Legacy 2 standings show Points (68 pts, 2nd place) instead of W-L since Del-Tri uses total games won as points.

12. **Deploy workflow fix** — Removed `claude/**` from the auto-deploy GitHub Action trigger. Only `main` branch pushes deploy now. This prevents new Claude sessions from accidentally overwriting the deployed site.

13. **Bouncing tennis ball animation** — Bounces on empty My Teams, Find a Team, and Create a Team pages.

### What was NOT deployed / NOT tested
- Email notifications require Gmail SMTP setup (see below)
- Line-by-line match data for Legacy 2 (Tara shared all 18 matches worth of screenshots but data entry page not built yet)

### Deploy commands

```bash
# Standard redeploy (keeps existing data)
cd /root/app && bash bin/deploy-phase-1.sh

# Fresh deploy (resets database, re-seeds everything)
cd /root/app && rm -rf /root/storage/* && bash bin/deploy-phase-1.sh
```

### Gmail SMTP setup (for lineup email notifications)

On the Droplet, create `/root/.smtp_credentials`:
```bash
cat > /root/.smtp_credentials << 'EOF'
SMTP_USERNAME="tarabucci@gmail.com"
SMTP_PASSWORD="your-16-char-gmail-app-password"
EOF
chmod 600 /root/.smtp_credentials
```

To get a Gmail App Password: myaccount.google.com > Security > 2-Step Verification > App Passwords > create one for "Court Report".

Then redeploy: `bash bin/deploy-phase-1.sh`

### Key branches

- **`claude/clarify-team-members-1ycVZ`** — the deploy branch. Deploy script pulls from here.
- **`claude/clarify-team-members-1ycVZ-aTu9y`** — this session's working branch (same code, kept in sync).
- Deploy workflow only triggers on `main` pushes now (safe).

### New decisions made

1. **Set Lineup visible only to captain/team creator** — not to admin users. If Tara is a player (not captain) on a team, she shouldn't see Set Lineup.
2. **Del-Tri and Inter-Club use 6 doubles lines** (no singles). USTA uses 1S + 4D. Need league format config.
3. **Subs are a roster role** — captains need to add substitute players. Team memberships need "sub" role in addition to "captain" and "player".
4. **Del-Tri scoring = points** (total games/lines won), not W-L records.
5. **Players can create their own teams** and become captain — the app works even if only one player on a team uses it.

### League format differences (important for lineup/results)

| League | Format | Lines |
|--------|--------|-------|
| **USTA** | 1 Singles + 4 Doubles | 1S, 1D, 2D, 3D, 4D |
| **Del-Tri** | 6 Doubles only | Line 1-6 |
| **Inter-Club** | 6 Doubles only | Line 1-6 |

### PCC subs (from Inter-Club website)

Nancy Fox (S), Jen Gallagher (S), Rachel Miller (S), Christi Neilly (S)

### Legacy 2 line-by-line data

Tara shared all 18 match screenshots from the Del-Tri website with full line-by-line results (who played which line, set scores, wins/losses). This data is preserved in Session 8's conversation. Key matches with Tara playing:

- Oct 3 vs Brandywine 5: Tara on Line 2 (with Ginger McGeer), Line 3 (with JoAnne Steinberg)
- Oct 10 vs DVTA 3: Tara on Line 2 (Buchakjian/Khue), Line 3 (JoAnne/Tara Bucci)
- Oct 17 vs Brandywine 4: Tara on Line 3 (Tara Bucci/JoAnne Steinberg)
- Oct 24 vs Tennis Addiction 4: Tara on Line 3 (Buchakjian/Khue Feigenberg)
- Oct 31 vs Upper Main Line Y 2: Tara on Line 3 (Tara Bucci/JoAnne Steinberg)
- Nov 7 vs Springfield YMCA 3: Tara on Line 1 (Tara Bucci/Anh Bixby)
- Nov 14 vs HPTA 6: Tara on Line 2 (Buchakjian/Khue Feigenberg)
- Nov 21 vs Radnor Racquet 3: (line data captured)
- Dec 5 vs Penn Oaks 5: Tara on Line 3 (Tara Bucci/JoAnne Steinberg)
- Jan 9 vs Brandywine 5: Tara on Line 3 (Tara Bucci/JoAnne Steinberg)
- Jan 16 vs DVTA 3: Tara on Line 2 (Buchakjian/Khue), Line 3 (Tara Bucci/JoAnne)
- Jan 23 vs Brandywine 4: Tara on Line 3 (Tara Bucci/Jackie Wilson)
- Jan 30 vs Tennis Addiction 4: (Tara not in lineup this week)
- Feb 6 vs Upper Main Line Y 2: Tara on Line 2 (Buchakjian/Khue)
- Feb 20 vs Springfield YMCA 3: (data captured)
- Feb 27 vs HPTA 6: (data captured)
- Mar 6 vs Radnor Racquet 3: Tara on Line 2 (Buchakjian/Lorise Chow)
- Mar 13 vs Penn Oaks 5: Tara on Line 3 (Buchakjian/Khue), Line 4 (JoAnne/Tara Bucci)

Note: "Tara Buchakjian" in Del-Tri results = Tara Bucci (different last name spelling in Del-Tri system).

### Next session priorities

1. **Build Enter Results page** — for Legacy 2's line-by-line data. Must support Del-Tri format (6 doubles lines). Use the screenshots from this conversation as reference.
2. **Add "sub" role to team memberships** — captains can add subs with name, ranking (optional), email (optional)
3. **League format configuration** — add field to TennisTeam for format ("usta_standard" = 1S+4D, "doubles_6" = 6 doubles lines). Lineup builder and Enter Results pages use this.
4. **Set up yourcourtreport.com domain** — Tara owns it on GoDaddy. Need to point DNS A record to 146.190.112.29 and set up HTTPS.
5. **Gmail app password** — Tara needs to create one for lineup email notifications.
6. **Co-captain role** — allow captain to promote a player to co-captain who can also set lineups.

### Lessons learned (Session 8)

- **The deploy workflow was overwriting the site** every time a new Claude session pushed to a `claude/*` branch. Fixed by removing `claude/**` from the trigger. Only `main` deploys now.
- **Don't nest `<a>` tags inside `<a>` tags** — the calendar button inside a link_to caused the button to render outside the card. Use div with onclick instead.
- **Route helper names matter** — `post "add_player"` inside a resources block generates a different helper name than expected. Use `member do` blocks for clarity.
- **Del-Tri uses a points system, not W-L** — storing points as "wins" caused confusion. Need separate handling for points-based leagues.
- **"Tara Buchakjian" is NOT "Tara Bucci"** — they are two different people. Tara Buchakjian is a separate player on Legacy 2 who often plays Line 2 with Khue Feigenberg. Tara Bucci is the app builder.
