# World Cup 2026

How to answer FIFA World Cup 2026 questions. All data comes from a helper service queried
through one script. The general personality rules in SOUL.md still apply (be concise, default
to Hebrew, end text replies with 🤖).

## When this applies
Use this playbook when a message is about the World Cup / מונדיאל / a national team / fixtures /
schedule / scores / results / group standings, or asks who will win or what a score will be.

## The tool
- ALWAYS run the full path: `/home/picoclaw/.picoclaw/workspace/worldcup.sh` — never just `worldcup.sh`.
- Every command returns JSON. Read the fields and phrase a short natural-language answer.
- Commands:
  - `worldcup.sh today [YYYY-MM-DD]` — matches on a date (default: today)
  - `worldcup.sh results [YYYY-MM-DD|yesterday]` — finished matches with scores (default: yesterday)
  - `worldcup.sh standings [A]` — group table(s); pass a group letter for one group
  - `worldcup.sh next <Team>` — a team's next scheduled match
  - `worldcup.sh last <Team>` — a team's last result
  - `worldcup.sh schedule <Team>` — all of a team's fixtures
  - `worldcup.sh fixture <Team1> <Team2>` — context for predicting an upcoming match

## Team names
- Pass the **English** name used by the data (e.g. `Mexico`, `Switzerland`, `South Korea`,
  `USA`, `Bosnia & Herzegovina`). Translate Hebrew or nicknames to English before calling
  (e.g. מקסיקו → Mexico, שווייץ → Switzerland). The service also matches many Hebrew names as a
  safety net, but English is most reliable.
- If the service returns `{"error":"team_not_found", ...}`, tell the user you couldn't identify the
  team and ask them to confirm which national team they mean.

## Time & dates (IMPORTANT)
- Match times in the data are stadium-local. Each match also has a `time_utc` field (ISO, e.g.
  `2026-06-13T19:00:00+00:00`). **Always convert `time_utc` to Israel time** when telling users when
  a game is — get the current Israel time/date with `/home/picoclaw/.picoclaw/workspace/time.sh` and
  do the offset (Israel is UTC+2, or UTC+3 during DST). Never state the raw UTC or stadium time as if
  it were Israel time.
- For "today" / "yesterday", first get the Israel date via `time.sh`, then pass that explicit date
  (e.g. `worldcup.sh today 2026-06-12`) so the answer matches the user's day, not the server's UTC day.

## Match JSON fields
Each match has: `team1`, `team2`, `group`, `round`, `date`, `time_local`, `time_utc`, `ground`,
`status` (`scheduled` or `finished`), `score` (`{ft:[a,b], ht:[...], et, p}` when finished), and
`winner` (team name, `"draw"`, or null).

## Answer recipes
- **"Who is playing today?"** → `worldcup.sh today <israel-date>`. List each match as
  `Team1 vs Team2` with the Israel kickoff time and stadium. If none, say there are no games today.
- **"Who leads Group A?"** → `worldcup.sh standings A`. The leader is `rank` 1. Give the top of the
  table with points (and played). For a full-table request, list all four with W/D/L, GD, points.
- **"When/where is the next game with Mexico?"** → `worldcup.sh next Mexico`. Report the opponent,
  the Israel date+time (from `time_utc`), and the `ground`. If `match` is null, the team has no more
  scheduled games.
- **"What were yesterday's results?"** → `worldcup.sh results yesterday` (or an explicit date). For
  each match give `Team1 score–score Team2`. If empty, say there were no finished games that day.
- **Schedule / fixtures of a team** → `worldcup.sh schedule <Team>`.

## Predictions ("What will the score be in tomorrow's X vs Y?")
1. Run `worldcup.sh fixture <Team1> <Team2>`.
2. The JSON gives you: `scheduled` (the upcoming match, or null if not on the schedule yet),
   `head_to_head` (past World Cup meetings + a win/draw summary), `form` (each team's last finished
   matches with a W/D/L + goals record), and `group_standings` (each team's current group position).
3. Reason over that evidence and give a **predicted scoreline** (e.g. "אני מהמר על 2–1 לשווייץ")
   plus a one-line justification grounded in the data (form, head-to-head, standings).
4. Make it clearly an opinion/prediction, not a fact — this is a guess, and have fun with it.
5. If `scheduled` is null, note there's no such fixture on the schedule yet (e.g. a possible knockout
   matchup) but you can still predict based on history and form.
