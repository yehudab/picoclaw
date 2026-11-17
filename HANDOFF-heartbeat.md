# Handoff: StatusCake heartbeat is permanently DOWN (false alarms)

## Symptom
After a gateway restart the heartbeat pings OK for ~20 min, then withholds forever.
Since 2026-11-01: 22 OK pings vs ~4,650 withheld runs. The monitor shows DOWN almost all
the time, so it can no longer signal a real outage.

## Root cause 1 (main): picoclaw's reconnect loop fights whatsmeow's auto-reconnect
`pkg/channels/whatsapp_native/whatsapp_native.go`, `eventHandler` → `reconnectWithBackoff()`.

- whatsmeow has `EnableAutoReconnect` (default true). On a routine `events.Disconnected` (e.g. WA's
  periodic "503 stream error"), whatsmeow reconnects by itself within seconds.
- picoclaw ALSO starts `reconnectWithBackoff()`, whose `client.Connect()` then returns
  `whatsmeow.ErrAlreadyConnected` ("websocket is already connected"). The loop only exits on
  `err == nil`, so it keeps retrying every 5 min (backoff cap) and logs `WARN WhatsApp reconnect failed`
  until a lucky race lines up with a real disconnect.
- gateway.log evidence: 64,031 `reconnect failed` lines with `websocket is already connected`
  vs 563 `invalid use of deleted device` (a real outage) and 1 dial failure. The bot works fine
  during these loops.
- `scripts/statuscake-heartbeat.sh` check 3a greps for `reconnect failed` (added for the
  deleted-device outage), so the benign loop withholds the ping forever.

**Go fix:** in `reconnectWithBackoff`, treat `errors.Is(err, whatsmeow.ErrAlreadyConnected)` as success
(log "already reconnected by whatsmeow" at info, then return). Optionally also check
`client.IsConnected()` before calling `Connect()`. Don't remove the loop; it still covers cases
whatsmeow gives up on.

## Root cause 2: check 3b (gateway.log staleness > 900s) assumes the bot is never idle
A healthy, idle bot goes quiet for a long time. The largest gaps in the last 20k gateway.log lines
were 559, 411, 328 and 124 min, with 7 gaps over 15 min. 3b false-alarms every quiet night.
This was flagged as an "OPEN follow-up" in July but never fixed.

**Planned fix, never done:** replace "absence of known errors / log freshness" with a POSITIVE
liveness signal. Proposal: a small goroutine in the WhatsApp channel that logs one line every 5 min
while `client.IsConnected() && client.IsLoggedIn()`, e.g.
`INFO whatsapp "WhatsApp alive"` (to gateway.log). Then in the heartbeat script:
- 3b → withhold unless a `WhatsApp alive` line was written within the last ~12 min
  (no longer depends on chat traffic).
- 3a → drop `reconnect failed` from the regex (redundant once 3b is positive; it's the false-alarm
  source). Keep `WhatsApp ERROR|Client outdated` (the 405 case). Optionally add
  `invalid use of deleted device` explicitly.
- Also log `events.LoggedOut` at ERROR level in `eventHandler` (it's currently unhandled), so the
  server-side logout gets a clear signal.

Expected results:
- Real 405: whatsmeow is not connected → no `alive` line → DOWN. 3a also catches it instantly.
- Server-side logout or deleted device: `IsLoggedIn` is false → DOWN.
- Idle healthy night: `alive` lines keep coming → OK.
- Benign 503 + auto-reconnect: fixed in Go → no loop, and the alive line continues → OK.

## Deploy notes
- The heartbeat script runs from the VPS working tree via `/etc/cron.d/picoclaw-heartbeat` (root,
  every 5 min), so a script change is live after `git pull`. The Go change needs
  `sudo docker compose -f docker/docker-compose.yml --profile gateway build picoclaw-gateway && ... up -d picoclaw-gateway`.
- Deploy both together. If only the script ships, 3b would wait for an `alive` line that never comes.
  Alternatively, make 3b fall back to the old behaviour when no `alive` line has ever been seen.
- whatsmeow's own errors go to the container's stdout (`docker logs`), NOT gateway.log. picoclaw's
  logger lines go to both.
- Heartbeat log: `docker/data/logs/statuscake_heartbeat.log` on the VPS.
