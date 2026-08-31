# World Cup 2026

How to answer FIFA World Cup 2026 questions. All data comes from a helper service queried
through one script. The general personality rules in SOUL.md still apply (be concise, default
to Hebrew, end text replies with 🤖).

## When this applies
Use this playbook when a message is about the World Cup / מונדיאל / a national team / fixtures /
schedule / scores / results / group standings, or asks who will win or what a score will be.

## Default context: World Cup 2026
- **When a question doesn't name a year or tournament, assume the FIFA World Cup 2026.** A bare
  question like "מה היתה תוצאת המשחק של מקסיקו?" ("what was Mexico's result?") means *their World Cup
  2026 game* — just answer it; do NOT ask the user whether they mean qualifiers / a friendly / a
  different tournament. The service only holds World Cup matches, so those other framings don't exist.
- The live commands (today/results/standings/next/last/schedule/fixture) all operate on the 2026
  tournament. Older World Cups (back to 1986) appear only as `head_to_head` history inside `fixture`.
- Only treat a question as being about a different edition if the user explicitly names another year
  (e.g. "מונדיאל 2018"); otherwise it's 2026.

## The tool
- ALWAYS run the full path: `/home/picoclaw/.picoclaw/workspace/worldcup.sh` — never just `worldcup.sh`.
- **Leave `cwd` empty** when running it. The command already uses the full absolute path, so it needs
  no working directory — and setting a wrong one (e.g. `/home/picoclaw/workspace`, missing `.picoclaw`)
  gets the call blocked by the safety guard with "path is outside the workspace".
- Every command returns JSON. Read the fields and phrase a short natural-language answer.
- Commands:
  - `worldcup.sh today [YYYY-MM-DD]` — matches on a date (default: today)
  - `worldcup.sh results [YYYY-MM-DD|yesterday]` — finished matches with scores (default: yesterday)
  - `worldcup.sh standings [A]` — group table(s); pass a group letter for one group
  - `worldcup.sh next <Team>` — a team's next scheduled match
  - `worldcup.sh last <Team>` — a team's last result
  - `worldcup.sh schedule <Team>` — all of a team's fixtures
  - `worldcup.sh fixture <Team1> <Team2>` — context for predicting an upcoming match
  - `worldcup.sh bet <Team1> <Team2> <score> [date]` — save your predicted score, e.g. `bet BRA MAR 2-1`
  - `worldcup.sh review <Team1> <Team2>` — grade your saved bet on that pairing against the real result
  - `worldcup.sh review <date>` — grade all your saved bets for games on that date
- These are the **ONLY** commands, and they take **positional arguments only — there are NO `--flags`**
  (no `--query`, no `--team`, etc.). Inventing a flag just prints the Usage line and exits non-zero.
  For a past match between two specific teams, use the head-to-head recipe below — don't make up a flag.

## Team names (READ CAREFULLY — this is the #1 source of failures)
The script splits its arguments on spaces, so a multi-word team name passed bare becomes two
arguments and the call breaks. `&` is even worse — the shell treats it specially. To avoid this:

- **Easiest & most reliable: use the FIFA 3-letter code** — one shell-safe token, no spaces, no
  quoting. e.g. `worldcup.sh next BIH` (Bosnia & Herzegovina), `worldcup.sh fixture KOR RSA`
  (South Korea vs South Africa). Codes: South Africa=RSA, South Korea=KOR, Czech Republic=CZE,
  Bosnia & Herzegovina=BIH, Switzerland=SUI, New Zealand=NZL, Saudi Arabia=KSA, Cape Verde=CPV,
  Ivory Coast=CIV, DR Congo=COD, plus the obvious ones (MEX, USA, BRA, ARG, ENG, FRA, GER, ESP…).
- **If you use a name with a space or `&`, you MUST double-quote the whole name**, e.g.
  `worldcup.sh next "Bosnia & Herzegovina"`, `worldcup.sh last "South Korea"`. Never pass
  `Bosnia & Herzegovina` unquoted — the `&` will break the command.
- Otherwise pass the **English** name (`Mexico`, `Switzerland`, `Brazil`). Translate Hebrew or
  nicknames first (מקסיקו → Mexico / MEX, שווייץ → Switzerland / SUI). The service also matches
  Hebrew and short forms (e.g. `Bosnia` → Bosnia & Herzegovina) as a safety net.
- If the service returns `{"error":"team_not_found", ...}`, tell the user you couldn't identify the
  team and ask them to confirm which national team they mean.

## Time & dates (IMPORTANT)
Two separate rules — one for the *day you query*, one for the *time you show the user*. Don't mix them up.

- **Which day is "today" / "tomorrow" / "yesterday"? → US East Coast (Eastern) time.** The tournament
  is played in North America and the data's `date` field is the North-American match day, so relative
  day words must be resolved in **Eastern** time — NOT Israel time, NOT UTC. Get the current Eastern
  date by running `/home/picoclaw/.picoclaw/workspace/nytime.sh` (subtract a day for "yesterday", add
  one for "tomorrow"), then pass that explicit date, e.g. `worldcup.sh today 2026-06-12`. Israel is 7
  hours ahead of Eastern, so "today" in Israel can land on a different match-day — this is the thing
  people get confused about, so always anchor the day to Eastern via `nytime.sh`.
- **What time do you SHOW the user? → use the `time_israel` field. DO NOT do timezone math yourself.**
  Every match already includes `time_israel` (kickoff "HH:MM" in Israel time) and `date_israel`
  ("DD/MM/YYYY" in Israel time) — read those and quote them directly. NEVER report `time_local` or the
  raw `time_utc` as if it were Israel time (e.g. a `time_utc` of `...T17:00:00+00:00` is **20:00**
  Israel — the service already computed that for you in `time_israel`, so just use it).

## Match JSON fields
Each match has: `team1`, `team2`, `group`, `round`, `date`, `time_local`, `time_utc`,
**`time_israel`** (kickoff "HH:MM" already in Israel time), **`date_israel`** ("DD/MM/YYYY" in Israel
time), `ground`, `status` (`scheduled` or `finished`), `score` (`{ft:[a,b], ht:[...], et, p}` when
finished), and `winner` (team name, `"draw"`, or null).

## Groups & stage (IMPORTANT)
- **Always name the group, in Hebrew, when describing a match.** The `group` field is `"Group A"`,
  `"Group B"`, etc. Don't just say "בית" — say which one. Translate the English letter to the Hebrew
  group name (`בית` + the Hebrew ordinal letter):
  - Group A → **בית א** · B → **בית ב** · C → **בית ג** · D → **בית ד** · E → **בית ה** · F → **בית ו**
  - G → **בית ז** · H → **בית ח** · I → **בית ט** · J → **בית י** · K → **בית יא** · L → **בית יב**
  - e.g. a match with `"group":"Group B"` is "בבית ב". If `group` is null (knockout match), use the
    `round` instead (e.g. "שמינית גמר") and don't mention a group.
- **We are in the group stage, so a match can end in a draw (תיקו).** Group-stage games are NOT
  decided by extra time or penalties — a level score just stays a draw and both teams take a point.
  So: never assume there must be a winner, read `winner` (it can be `"draw"`), report level scores as
  "תיקו X–X", and when predicting a group game a draw is a perfectly valid call.

## Answer recipes
- **"Who is playing today?"** → get the Eastern date via `nytime.sh`, then `worldcup.sh today <eastern-date>`.
  List each match as `Team1 vs Team2` with the **Israel** kickoff time (from `time_utc`), the stadium,
  and the **Hebrew group** (e.g. בבית ב). If none, say there are no games today.
- **"Who leads Group A?"** → `worldcup.sh standings A`. The leader is `rank` 1. Give the top of the
  table with points (and played). For a full-table request, list all four with W/D/L, GD, points.
- **"When/where is the next game with Mexico?"** → `worldcup.sh next Mexico`. Report the opponent,
  the Israel date+time (from `time_utc`), the `ground`, and the **Hebrew group** (e.g. בבית א). If
  `match` is null, the team has no more scheduled games.
- **"What were yesterday's results?"** → `worldcup.sh results yesterday` (or an explicit date). For
  each match give `Team1 score–score Team2`. If empty, say there were no finished games that day.
  **`results` takes a DATE only (or today/yesterday/tomorrow) — never a team name.** `results Brazil`
  returns nothing; to get one team's result use `last`/`schedule` as in the next recipe.
- **"What was the result of X vs Y?" (a specific past match)** → there is no two-team results command,
  so don't invent a flag. Run `worldcup.sh schedule <X>`, find the entry whose opponent is `<Y>` and
  whose `status` is `finished`, and read `score.ft` (and `winner`). Report it as `X a–b Y`
  (e.g. Mexico 2–0 South Africa). If it was that team's most recent game you can also use
  `worldcup.sh last <X>`. If the match isn't there or `status` is still `scheduled`, say it hasn't been
  played yet.
- **Schedule / fixtures of a team** → `worldcup.sh schedule <Team>`.

## Predictions ("What will the score be in tomorrow's X vs Y?")
Predicting a scoreline is ALWAYS **exactly two tool calls, in order** — never stop after the first:

**Call 1 — get the evidence:** `worldcup.sh fixture <Team1> <Team2>` (the command is `fixture`;
`predict` is an accepted alias — there is no other prediction command). Use FIFA codes or quote
multi-word names, e.g. `worldcup.sh fixture CAN BIH`. The JSON gives `scheduled` (the upcoming match,
or null if not paired yet), `head_to_head`, `form` (each team's recent W/D/L + goals), and
`group_standings`. Decide a **predicted scoreline** from it — and remember it's the group stage, so
**a draw (e.g. 1–1) is a legitimate call**, don't force a winner.

**Call 2 — SAVE the bet (mandatory, do it before you reply):**
`worldcup.sh bet <Team1> <Team2> <score> [date]` — e.g. `worldcup.sh bet POR COD 2-0`. Teams in the
SAME order as the score; score as `goals1-goals2` (`2-0`, or `1-1` for a draw). The date is filled in
from the scheduled game automatically — only pass an explicit `date` for an unscheduled future
knockout. Re-betting the same game overwrites the previous call. **A prediction is not finished until
this call succeeds** — if you skip it, you won't be able to `review` it later.

Only after both calls, write your reply: the scoreline + a one-line justification (form, H2H,
standings), as a fun opinion/guess (not a fact). If `scheduled` was null and you had no date to pass,
say there's no such fixture scheduled yet but you can still predict from history and form.

## Reviewing your bets ("how did my guesses do? what can I improve?")
Bets are saved in the service (see the Predictions section's Call 2), so you grade them with one command — do NOT
re-fetch results by hand, and do NOT invent commands like `recent_predictions`/`get_results`.

- **One pairing:** `worldcup.sh review <Team1> <Team2>` (e.g. `review BRA MAR`) grades your latest bet
  on that game.
- **A whole day:** `worldcup.sh review <date>` (e.g. `review 2026-06-13`) grades every bet whose game
  was on that date and returns a `summary` (counts of exact / outcome / miss / pending).

Each graded bet tells you `result`: **`exact`** (score spot-on), **`outcome`** (right winner or draw,
wrong score), or **`miss`**; plus `predicted` vs `actual`. `status:"pending"` means the game hasn't
finished yet — say so and don't grade it. Report it warmly, e.g. "ניחשתי 2–1 לברזיל, יצא 1–1 — פספוס,
אבל קלעתי לכיוון 😅", tally the hits, and add one short note on what to improve next time.
