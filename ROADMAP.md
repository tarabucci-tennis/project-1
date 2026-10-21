# Court Report Roadmap: player-facing, imported results

*Written Oct 21, 2026. Investigation only: no code was changed to produce this.*

**Goal:** a player sees all her teams across leagues in one place, with results imported instead of typed.

**Fetching rule (Tara):** one page at a time, only when Tara triggers it. No automated crawling.

> **Conflict to resolve first.** Tenniscores results are already fetched automatically, every hour, for every team with a Tenniscores link saved (`NightlySyncJob`, run by `scores:sync` from the droplet's crontab). That is automated fetching, which this rule forbids. Tara should decide: keep the hourly sync (it is how Legacy 1 and Advantage Us get line scores today), or switch to "only when I press the button".

---

## Where things stand today

### Data model (already many-teams-per-player)

| Table | What it holds | Key fields |
|---|---|---|
| `users` | One row per person | `name`, `email` (optional), `ntrp_rating` (the single USTA rating), `court_report_rating`, `dynamic_rating`, `deltri_player_url`, `tennislink_person_id` |
| `tennis_teams` | One row per team per season | `name`, `league_category` (USTA / Local / Inter-Club), `league_name`, `flight`, `season_name`, `tenniscores_url`, `usta_*` published standings, `archived` |
| `team_memberships` | **Joins a person to a team** (many-to-many) | `user_id`, `tennis_team_id`, `role` (captain / co_captain / player), `archived_season` |
| `matches` | One team match | `tennis_team_id`, `match_date`, `opponent` (text), `home_away`, `result`, `score_summary`, `usta_status`, `scorecard_url` |
| `match_lines` | One line of a match | `match_id`, `position`, `line_type` (singles/doubles), `result` (our view), `set1_score`..`set3_score` (ours first, e.g. "6-3"), `opponents` (**free text**) |
| `match_line_players` | Which of **our** players played a line | `match_line_id`, `user_id` |
| `usta_lines` | Lines from uploaded TennisLink "Individual Result" files | names as text, keyed by TennisLink match ID + line |
| `division_teams` | Other teams in a flight (standings, roster links) | name, W/L, points, games |

**Already true:** one person can be on any number of teams in any league. Tara is on 7+ teams through one `users` row.

**What's missing for a real "one player across leagues" platform:**
1. **Opponents aren't people.** They're stored as text ("Jane Smith / Mary Jones"), so a rival's history can't be followed.
2. **People are matched by exact name only.** Imports find a person by lowercased name, or create a name-only placeholder. Spelling variants (TennisLink "Jaclyn Groenen" vs Inter-Club "Jaci Gronen") become **two people**. Two different people with the same name become **one**. There is no merge tool and no alias list.
3. **No link to each league's own player ID.** There's one column each for Del-Tri and TennisLink, and nothing for Bux-Mont or Inter-Club.

### Importers that already exist

| Source | How | Lines? | Status |
|---|---|---|---|
| **Tenniscores** (Del-Tri, Bux-Mont, Inter-Club sites) | `DeltriResults` reads the team page, then each `print_match.php?sch=…` printable scorecard. Public, plain HTML. | Yes: players, set scores, winner | **Automatic hourly** for teams with `tenniscores_url` |
| **TennisLink Scorecard** (Send To Excel) | Upload on **Upload USTA file** → `UstaScorecardParser` / `UstaScorecardImport` | Yes: every line, both teams | Live since PR #229 |
| TennisLink Team Summary / Match Summary | Same upload page | No (team score only) | Live |
| TennisLink Individual Result | Ratings upload (admin-only for now) | One player's lines only | Live, hidden |
| Old Google Sheet | `SheetScoreSync`, hourly | Yes | Live: KMA, Pour Decisions, PCC #2. Its "USTA 18+ Baby Got Backhands" tab is skipped: no Court Report team has that name. |

**TennisLink pages can't be fetched from the server.** Every page tried redirects to USTA's sign-in (`account.usta.com/authorize`). The only way around that is a stored USTA login, which Tara ruled out (account-lock risk, stored secret). So a pasted TennisLink link can be **saved and shared**, but never **read**.

### Tenniscores scorecard structure (from the working importer)

- The team page's standings row links to one printable scorecard per match. The cell id starts with `h` (we're home) or `a` (we're away).
- Each line is a small table: **two rows**, visiting pair on top and home pair underneath. Each row holds two player names and one cell per set.
- The set a pair won carries the CSS class `bold-text`. Line winner = more sets won, then more games.
- Timed play means partial scores like `5-5` are **normal**, not errors (Bux-Mont rule B.7). Bux-Mont decides lines on **total games**, not sets.
- The current parser assumes **doubles only** ("#N Doubles"). That holds for Del-Tri / Bux-Mont / Inter-Club today.

---

## Phase 1: "Paste a scorecard link" importer, with a preview

**Honest scope:** this works for **Tenniscores** (public pages). It **cannot** work for TennisLink (sign-in). TennisLink keeps the file upload.

**What it adds over today:** one-off matches from Tenniscores teams that aren't set up for the hourly sync (a sub appearance, a friendly flight, a new season before its link is saved). Also a **preview before saving**, which the hourly sync never shows.

**Database changes**
- `matches.source_url` (or reuse `scorecard_url`) plus `matches.imported_at`, to know where a result came from and avoid importing it twice.
- Optional `import_logs` table: who imported what, when, and what changed. Lets a bad import be undone.

**Pages affected**
- **Enter Results**: a "Paste Tenniscores scorecard link" box, then a preview (each line, our side / their side, ours-first scores, W/L), then Save.
- **Result pop-up**: shows "Imported from Tenniscores" with the link.
- **Upload USTA file**: unchanged; it remains the TennisLink route.

**Reuse:** the `DeltriResults#parse_scorecard` logic, called for a single URL instead of a whole team page.

**What could go wrong**
- **Wrong team:** the link is for a different team or match. Match by our team's name (loosely) and the date, and refuse with a clear message when neither side is us.
- **Home/away:** a printable card alone doesn't say which side we are. It has to be worked out from the team names on the card, which differ in spelling ("Legacy 1" vs "Legacy Tennis 1").
- **Defaults and retirements:** blank or partial sets, "Def." markers. Need real samples before trusting them.
- **Singles lines:** the current parser is doubles-only. Any league with singles needs a change.
- **Page changes:** Tenniscores can change its HTML at any time. The parser should fail loudly ("couldn't read this scorecard"), never save junk.
- **Overwrites:** an import would overwrite hand-typed lines. Show a "this replaces what's there" warning in the preview.
- **TennisLink links:** must be refused with "TennisLink needs the Send To Excel file", not silently fail.

---

## Phase 2: Unified player database, with a manual merge tool

**Goal:** the same human is one record across USTA, Del-Tri, Bux-Mont and Inter-Club. Opponents become people too, so their history can be followed.

**Database changes**
- `player_aliases`: `user_id`, `name`, `source` (usta / deltri / buxmont / interclub / typed). Every spelling seen points to one person. Imports look up aliases before creating anyone.
- `player_external_ids`: `user_id`, `source`, `external_id` (TennisLink person ID, Tenniscores player URL). The strongest match key when a league provides one.
- `match_line_opponents`: `match_line_id`, `user_id`. This replaces the free-text `opponents`. Keep the text column during the switch.
- `users.placeholder` (boolean): created by an import, never signed up. These people can be merged freely.
- Optional `merge_logs`: which record was merged into which, so a wrong merge can be undone.

**Pages affected**
- **Admin → People / Merge duplicates**: suggested pairs (same last name with similar first name, same teams, nickname pairs like Jaci/Jaclyn). Side-by-side view, then a **Merge** button that moves memberships, lines, lineups and availability to the kept record.
- **Player profile**: all teams and all leagues on one page, plus head-to-head against opponents.
- **Every importer** (Phase 1, the uploads, the hourly sync): resolve names through aliases and external IDs first.

**What could go wrong**
- **Wrong merges.** Two real people with the same name (two "Jennifer Smith"s) get merged. This is the riskiest step. Merges must be **manual**, previewed and undoable. Never auto-merge on name alone.
- **Missed merges.** "Tara Buchakjian" and "Tara Bucci" are **different people**, per CLAUDE.md. Nickname rules must suggest, never decide.
- **Accounts with logins.** Merging two records that both have a password and email needs a rule for which login survives.
- **Privacy.** Opponents become stored records of people who never signed up. Keep it to names and results already printed publicly by their league. Offer a removal path, as TennisBump does.
- **Data volume.** Every opponent becomes a row. That's fine for SQLite at this scale, but the merge-suggestion queries need indexes.

---

## Phase 3: Per-player rating, updated after every match

**What exists:** `RatingCalculator` (live, hidden from players). It uses each scored line, the flight's level and the games margin, averaged over the season. Stored in `users.dynamic_rating` and `court_report_rating`. The Ratings pages are admin-only until the data is complete (Oct 16 decision).

**Database changes**
- `rating_events`: `user_id`, `match_line_id`, `rating_before`, `rating_after`, `computed_at`. Lets a player see why their number moved, and lets a recalculation be checked.
- Settings per league: which leagues count toward the rating. CLAUDE.md says **only USTA sets a real rating**. Del-Tri / Bux-Mont / Inter-Club results must never feed the USTA number, and at most feed a separate, clearly labelled Court Report estimate.

**Pages affected**
- **Player profile**: rating with trend line, the last N matches and their effect, and the sample size.
- **Result pop-up**: "+0.03" next to each player once ratings are public.
- **Ratings pages**: turned back on (`RatingsController::PUBLIC`) only after a few weeks of comparing against reality.

**What could go wrong**
- **Garbage in.** Ratings are only as complete as the line data. Missing USTA lines (the reason Ratings is hidden now) make numbers wrong and unfair.
- **Opponent strength.** Today it uses the flight level, not the actual opponents. Phase 2's opponent records allow a better model, but only once opponents are de-duplicated.
- **Mixing leagues.** Bux-Mont is timed with penalty games, Del-Tri is games-based, USTA is standard sets. Treating their scores alike would distort ratings. Keep separate inputs, or USTA only.
- **Expectations and trust.** Players will compare it with TennisRecord and TennisBump (paid, 5M+ results, its own bump model). A number that disagrees without explanation hurts credibility. Label it as an estimate and show its basis.
- **Sensitivity.** A visible number that drops can upset teammates. Consider letting players see only their own at first.

---

## Suggested order

1. **Decide the hourly-sync question** (top of this file).
2. Phase 1 for **Tenniscores only**, since it reuses a parser already proven on 18 Legacy scorecards.
3. Phase 2's **alias table plus manual merge** before anything else in Phase 2. Every import gets more accurate once names resolve to the right person.
4. Phase 3 last, and only for players with enough lines (CLAUDE.md: suppress percentages under 5 lines).
