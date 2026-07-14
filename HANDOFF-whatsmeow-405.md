# Handoff: fix WhatsApp "Client outdated (405)" — bump whatsmeow

**Status:** bot is DOWN (WhatsApp not receiving/sending). Root cause identified. Fix is a
whatsmeow dependency bump + rebuild. Do the dep/build work on the **dev machine**, push, then
**deploy on the VPS** (which builds from source via compose).

---

## 1. Root cause (confirmed)

WhatsApp's servers now reject our whatsmeow client version with **HTTP 405 "Client outdated"**.

VPS gateway log (`docker/data/logs/gateway.log`), 2026-07-14 15:51:32Z:

```
[WhatsApp ERROR] Client outdated (405) connect failure (client version: 2.3000.1033703022)
```

Evidence:
- Our pin: `go.mau.fi/whatsmeow v0.0.0-20260219150138-7ae702b1eed4` (built **Feb 2026**).
- WhatsApp raised the minimum client version ~**June 2026** (whatsmeow issue
  [#1164](https://github.com/tulir/whatsmeow/issues/1164); same pattern as #1040, #941, #1031).
- The websocket "connects" then the session is refused, so the socket looks up but no messages flow.
- Session store `docker/data/session/store.db` is frozen at **Jul 13 20:46** (the moment it died) —
  a live session writes to it continuously.
- Restart does NOT fix it and does NOT prompt for a QR (it re-accepts the stale creds). A relink
  won't help either — this is a **client-version** problem, not a session problem.

## 2. Why "pull from upstream" does NOT fix it

`sipeed/picoclaw@main` (HEAD `85dcfcca`) pins the **same** stale whatsmeow version. Upstream hasn't
bumped it. We are 46 commits ahead / 943 behind upstream, but that's irrelevant here — the fix must
bump whatsmeow directly. (Merging upstream is optional and separate; don't couple it to this fix.)

## 3. The fix (on the DEV machine)

```bash
# from repo root, on a branch
git checkout -b fix/whatsmeow-405
go get go.mau.fi/whatsmeow@latest
go get go.mau.fi/util@latest        # companion dep; bump if go mod tidy asks
go mod tidy
go build ./...                      # <-- expect possible breakage; see §4
```

Latest whatsmeow (July 2026) reports a current client version and clears the 405.

## 4. Likely compile-breakage spots (5 months of whatsmeow API drift)

The WhatsApp channel (`pkg/channels/whatsapp_native/whatsapp_native.go`) uses this whatsmeow surface —
check each still compiles after the bump:

```
whatsmeow.NewClient, whatsmeow.Client
client.Connect / Disconnect / IsConnected
client.AddEventHandler
client.GetQRChannel        # signature has changed across versions before — most likely to break
client.SendMessage        # ctx/return signature occasionally changes
client.DownloadAny
client.Store.ID            # used as the "logged in / paired" check
events.Message, events.Disconnected
types.JID, types.NewJID, types.ParseJID, types.DefaultUserServer, types.GroupServer
```

Fix compile errors minimally, matching the new signatures. `go doc go.mau.fi/whatsmeow.Client.<method>`
is the fastest reference. Don't refactor beyond what the build requires.

## 5. Verify on dev

- `go build ./...` clean.
- `go vet ./...` clean.
- Optional smoke: run the gateway locally and link a **test** WhatsApp account (fresh QR); confirm
  it connects with NO 405 and receives a message. (The real number's session lives only on the VPS.)

## 6. Commit & push

```bash
git add go.mod go.sum pkg/channels/whatsapp_native/   # + any other files the API fix touched
git commit -m "Bump whatsmeow to fix WhatsApp 405 Client outdated"
git push origin fix/whatsmeow-405        # then merge to main (PR or fast-forward)
```

## 7. Deploy on the VPS (after main has the fix)

The VPS gateway builds from source (`docker/docker-compose.yml` → `build: context: ..`), so it just
needs the new code, then a rebuild. Run as the user with `sudo` (docker needs root here; `ubuntu` is
not in the `docker` group).

```bash
cd /home/ubuntu/picoclaw
git checkout main && git pull origin main

# rebuild the gateway image with the bumped dep
sudo docker compose -f docker/docker-compose.yml --profile gateway build picoclaw-gateway

# the stale session must be cleared so whatsmeow shows a fresh QR (back it up first)
sudo docker stop picoclaw-gateway
sudo cp docker/data/session/store.db docker/data/session/store.db.bak-$(date +%Y%m%d) || true
sudo rm -f docker/data/session/store.db

# recreate with the new image
sudo docker compose -f docker/docker-compose.yml --profile gateway up -d picoclaw-gateway

# relink: tail logs, scan the QR on the bot's phone (WhatsApp > Linked Devices > Link a Device)
sudo docker logs -f --since 1m picoclaw-gateway 2>&1        # QR ASCII prints here, refreshes ~20s
```

## 8. Post-deploy verification

```bash
# NO 405 in the log after connect
sudo docker logs --since 5m picoclaw-gateway 2>&1 | grep -iE '405|outdated' && echo "STILL BROKEN" || echo "no 405 - good"
# login success + it receives a real message
sudo docker logs --since 5m picoclaw-gateway 2>&1 | grep -iE 'login event event=success|message received'
# send an image in the group -> expect a Hebrew score reply (end-to-end)
```

## 9. Alert improvement (do this too — it's why we got no warning)

The StatusCake heartbeat (`scripts/statuscake-heartbeat.sh`) only checks container-health + scorer, so
a 405/WhatsApp failure with a "healthy" process slips through. The 405 IS logged at ERROR level, so add
a cheap, false-alarm-resistant check that withholds the heartbeat if the WhatsApp channel logged an
error recently. Insert BEFORE the final `curl` heartbeat, after the scorer check:

```sh
# 3) recent WhatsApp connection error (e.g. 405 Client outdated) -> treat as down
GATEWAY_LOG="/home/ubuntu/picoclaw/docker/data/logs/gateway.log"
if [ -r "$GATEWAY_LOG" ]; then
	# last WhatsApp ERROR line, if any; withhold if it's within the last ~30 min
	last_err_ts="$(grep -iE '\[WhatsApp ERROR\]|Client outdated|connect failure' "$GATEWAY_LOG" 2>/dev/null | tail -1 | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}')"
	# NOTE: gateway.log ERROR lines are colorized/plain-time; prefer matching the JSON
	# '"level":"error","component":"whatsapp"' lines which carry a full RFC3339 "time" field.
fi
```

Better signal (JSON logs carry full timestamps): withhold if any
`"level":"error","component":"whatsapp"` line appears in the last N minutes. Implement with the same
`date -d` freshness comparison already proven in the diagnosis. Keep the threshold ~15–30 min so a
single transient blip doesn't false-alarm. Do NOT use whatsapp log *silence* as the signal — a healthy
idle connection is quiet (verified: after a clean restart the whatsapp component logged nothing for
minutes while perfectly healthy).

## 10. Current VPS state & rollback

- `picoclaw-gateway` is running but 405-failing; `connections-scorer` healthy; session store intact
  (NOT cleared — the clear command was aborted).
- StatusCake heartbeat is green (blind to this failure) — expected until §9 lands.
- Rollback for the dep bump: `git revert` the bump commit, rebuild. Session backup (step 7) lets you
  restore the old `store.db` if needed, though a relink is the norm after a version change.

## Reference (VPS facts)
- Repo: `/home/ubuntu/picoclaw`; compose: `docker/docker-compose.yml`, profile `gateway`.
- Containers: `picoclaw-gateway` (build from `docker/Dockerfile`), `connections-scorer`
  (built from sibling `../connections-score-analyzer`).
- Session store (host): `docker/data/session/store.db` → container `/home/picoclaw/.picoclaw/session`.
- go 1.25.8. `docker` requires `sudo` (user not in docker group).
