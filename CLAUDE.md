# Court Report — Project Configuration

## What This Is

**Court Report** is an app that puts all of a racket sport player's tennis (and eventually other racket sport) life in one place — schedules, teams, leagues, availability, rosters. Today, players and captains jump between different apps and sites for different teams and leagues. Court Report is the "one app" that replaces that mess.

**In Tara's words:**
> "It's an app for players and captains to have all tennis platforms in one app. We jump from schedule to schedule for different teams and leagues. It would be extremely beneficial for all players, coaches and teams to have it all in one place."

- **Product name:** Court Report
- **Domain (goal):** yourcourtreport.com
- **Current production URL:** http://146.190.112.29 (DigitalOcean droplet)
- **Who it's for:** All racket sport players, captains, and coaches. Not just tennis — also pickleball, squash, padel, etc. (future). Not just USTA — any league.
- **End goal:** Tara is building this for herself first, but wants to turn it into a real product that other people pay for.

**Key people:**
- **Tara Bucci** — primary user, admin, captain of multiple USTA teams. **Building this app alone.**
- **Jaclyn ("Jaci") Staples** — Tara's teammate, first "real" user beyond Tara.
- **Tara's husband** — built the tiiny.host mockup as a design example to show Tara what Claude could do. **Not involved in building the Rails app.**

## Critical Dates

| Date | Event | Status |
|------|-------|--------|
| **April 14, 2026** | First match of the season for Tara's first team | Not ready — will use MatchTime |
| **April 21, 2026** | First match of the season for Tara's second team | App needs to be working by then |

Both dates are real matches Tara needs to captain through. The app doesn't need to replace MatchTime by April 14 — Tara will still use MatchTime for that match. The harder target is April 21: by then, Court Report should be functional enough that Tara can actually use it for her second team's opening match.

## How Tara Prefers to Work

**Tara is not a technical person.** Important working norms:

- **Plain language only.** No jargon. Don't say "migration" — say "database update." Don't say "turbo stream" — say "the page updates without reloading." Don't say "deploy" without explaining "push the code to the live server."
- **Be direct and specific.** Tell her exactly what to click, exactly what to type, exactly what URL to visit.
- **Be honest about uncertainty.** If code isn't tested, say so out loud. If you're guessing, say so.
- **Phase work in small pieces.** Don't try to build everything at once. Get one slice working and shippable before starting the next.
- **Verify before declaring victory.** Don't say "done" if you haven't actually tested it works in a browser.
- **Ask before building.** If the task doesn't match what's in the code, ask clarifying questions first — don't just start coding on assumptions.

## Current Status (as of April 10, 2026)

### What's actually live on the DigitalOcean server at http://146.190.112.29
- Homepage: "Tara's Sandbox" (dark green + neon yellow theme — **NOT** Court Report branding yet)
- Auth: email-only login (no password — just look up by email)
- User management (admin can add/edit/delete users)
- Player profile page with NTRP rating and match stats table
- Tennis landing page with Sabalenka quotes

### What's on a branch but NOT deployed and NOT tested
**Branch: `claude/fix-teams-500-error-GPgeR`** contains two features sitting unverified:

1. **Teams 500 error fix** — New TeamsController, routes, and views so clicking a team card shows team detail. Untested.
2. **Match availability feature** — Schedule page, match cards with In/Out/message buttons, Captain View grid, in-app notifications. New database tables: `team_memberships`, `matches`, `availabilities`, `notifications`. **Never run. Never tested. May not even compile.**

**Treat the code on this branch as a draft.** Before merging or deploying, someone needs to actually boot the app, run the database updates, and click through the features.

### What's missing or broken
- **Visual branding is wrong.** The app looks like "Tara's Sandbox," not Court Report. Needs full restyle to white background / black header / gold accents to match the tiiny.host mockup.
- **Real team data is missing.** Seeds contain old team names (Quad Squad, Over Served, Tri Me, AGC ACES, Unmatchables). Tara's current real teams are **Kiss My Ace**, **Pour Decisions**, and **Legacy 2**. Seeds need updating.
- **`yourcourtreport.com` does NOT point to the Rails app.** The domain currently points to a static HTML mockup on tiiny.host. DNS needs to move to DigitalOcean.
- **No captain auto-assignment.** When a team is created, there's no automatic team_membership record making the creator a captain. Tara's seed teams get it manually in seeds.rb.

## The Two "Court Reports" (important context)

There are currently **two different things** both being called "Court Report":

1. **The Rails app** (this repo) — deployed at http://146.190.112.29. Real backend, real database, can save data. Currently styled as "Tara's Sandbox."
2. **The tiiny.host mockup** at `courtreport.tiiny.site` — static HTML/CSS built by Tara's husband as a **design example**. Pretty but not functional. `yourcourtreport.com` currently points here.

**The plan:** make #1 look like #2, then point the domain at #1.

## Real Team Data

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

### Pour Decisions

_Details still needed. From tiiny.host mockup: USTA, 16 players, 8 upcoming, 0-0._

### Legacy 2

_Details still needed._

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
| 6 | Teams 500 fix + availability feature (this session) | `d456d37`, `50316cd` | **Code on branch, NOT deployed, NOT verified** |

## Lessons Learned (honest notes from past sessions)

### From Session 6 — don't repeat these
- **Claude built a large feature without running it.** The availability feature has 4 new database tables and hundreds of lines of code — none tested. Next time: run the database update, boot the app, click the buttons in a browser before claiming done.
- **Claude hand-edited `db/schema.rb`.** This file is auto-generated. Hand-editing it risks drift. Always run the database update command instead.
- **Claude tried to fix a bug without verifying the bug was real.** The "500 error on /teams/1" couldn't be reproduced because the real broken site was on tiiny.host, not in this Rails app. Next time: ask "can you show me the bug first?" before writing a single line.
- **Claude used technical language with a non-technical user.** Tara had to ask for plain English. Default to plain English always.

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
| Firewall | Ports 22 (SSH) and 80 (HTTP) open |
| Container Registry | `registry.digitalocean.com/tarabucci-tennis` |
| SSH Key ID | `54458995` (name: `do-deploy`) |

**App URL:** http://146.190.112.29

### Re-deploying after pushing new code

SSH into the droplet and run:
```bash
cd /root/app && git pull && docker build -t project-1 . && docker stop project-1 && docker rm project-1 && docker run -d -p 80:80 -e RAILS_MASTER_KEY=<key> -v /root/storage:/rails/storage --name project-1 --restart unless-stopped project-1
```

SQLite databases are persisted via a Docker volume mounted at `/root/storage` on the host.

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
