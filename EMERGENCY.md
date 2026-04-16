# EMERGENCY — "My Site Is Down"

> Last verified working: 2026-04-16 (tonight's outage recovery)
>
> If you are reading this because your site is down, skip to
> **"5-Minute Fix"** below. Everything else is background.

---

## Quick Facts

| What | Value |
|---|---|
| Site | https://yourcourtreport.com |
| Droplet IP | 146.190.112.29 |
| Droplet ID | 555081556 |
| Repo | tarabucci-tennis/project-1 |
| DigitalOcean login | tarabucci@gmail.com (Google login) |

**Open the server terminal (bookmark this link):**
https://cloud.digitalocean.com/droplets/555081556/terminal/ui

**Where the real master key lives (the one that actually works):**
`/root/app/config/master.key` on the droplet. Read it with `cat`. Don't trust any master key written on paper or in a chat — the file on the droplet is the source of truth.

---

## 5-Minute Fix

Run these 4 steps in order. Don't skip ahead. If a step looks wrong, stop and screenshot it.

### Step 0 — Open your server terminal

1. Go to **https://cloud.digitalocean.com/droplets/555081556/terminal/ui**
2. Log in with Google (tarabucci@gmail.com) if asked
3. A black window opens. Wait until you see `root@project-1:~#` with a blinking cursor. That's the prompt. You're in.

### Step 1 — Reset the code to real main

**Copy this entire line, right-click → Paste, press Enter:**

```
cd /root/app && git fetch origin && git checkout -B main origin/main
```

**What good looks like:** You see "Switched to and reset branch 'main'" and "Your branch is up to date with 'origin/main'". No red text.

### Step 2 — Rebuild the app

**Copy, paste, press Enter:**

```
docker build -t project-1 .
```

**What good looks like:** Lots of text scrolls by for 1–3 minutes. When scrolling stops and you see `root@project-1:~/app#` again, it's done. The last lines should mention "naming to docker.io/library/project-1" or similar.

**If you see ERROR in red:** Stop. Screenshot it. Send to Claude.

### Step 3 — Restart the container properly

**This is ONE long line. Copy ALL of it. Paste as one chunk. Press Enter ONCE:**

```
docker stop project-1; docker rm project-1; docker run -d -p 80:80 -p 443:443 -e RAILS_MASTER_KEY=$(cat /root/app/config/master.key) -e TLS_DOMAIN=yourcourtreport.com,www.yourcourtreport.com -v /root/storage:/rails/storage -v /root/thruster-storage:/rails/thruster --name project-1 --restart unless-stopped project-1
```

**What good looks like:** Three things print:
1. `project-1` (old container stopped — OR a "No such container" error, which is also fine)
2. `project-1` (old container removed — OR same "No such container" error, also fine)
3. **A long string of 64 random letters and numbers** — this is the new container's ID. **THIS is the success signal.**

### Step 4 — Verify

**Copy, paste, press Enter:**

```
sleep 15 && docker ps --filter name=project-1
```

**What good looks like:** A small table showing `project-1` with `STATUS: Up X seconds`.

**What bad looks like:** STATUS says `Restarting` or `Exited`. That means the app is crashing on startup. Skip to **"If It Didn't Work"** below.

### Step 5 — Test it

1. Open a **brand new browser tab** (don't reload an old one)
2. Visit **https://yourcourtreport.com** (use `https`, not `http`)
3. If you see your tennis site: **YOU'RE DONE.** Close the terminal.
4. If you see "site can't be reached": try an **incognito window**. Browsers cache errors aggressively — incognito bypasses the cache.

---

## If It Didn't Work

Run ONE more command and screenshot the output:

```
docker logs project-1 --tail 80
```

This shows the last 80 lines of what the app said before dying. Screenshot it and send to Claude with the message: *"I ran EMERGENCY.md and the site is still down, here are the logs."*

Claude can read those logs and figure out the new problem. There are many possible causes beyond tonight's (missing env var, bad migration, ran out of disk, etc.) but they all show up in these logs.

---

## Traps To Avoid

### ❌ Don't run `reboot` on the droplet
It re-runs an old cloud-init script that has a broken docker-run command. Use the 5-minute fix instead.

### ❌ Don't trust a master key written on paper
Always `cat /root/app/config/master.key` on the droplet to read the real one. Written notes can get out of sync or have typos.

### ❌ Don't follow ChatGPT's "fix your CI to fix the site"
Red X marks on GitHub Actions (CI) and your site being down are **two different problems**. CI failures don't crash the site. Fix the site first with the 5-minute fix above; clean up CI separately.

### ❌ Don't push to `main` until deploy.yml is fixed
As of 2026-04-16, your `deploy.yml` has bugs that cause it to produce a broken container on every merge to main. Pushing to main = re-triggering tonight's outage. Fix deploy.yml FIRST (separate task), then resume normal pushing. Claude knows the details.

### ❌ Don't hard-refresh one browser tab as your only test
Chrome caches errors. Always verify with an incognito window or a second browser.

---

## 60-Second Background (so you can follow what's happening)

Your site has four layers stacked on top of each other:

1. **Your domain** (`yourcourtreport.com`) — points to the droplet's IP via DNS
2. **The droplet** — a small Linux computer DigitalOcean rents you for ~$6/month
3. **The Docker container** — a sealed "crate" running your Rails app, inside the droplet
4. **The Rails app itself** — the code that shows tennis data to visitors

When the site is down, the problem is usually in layer 3 (crate died or is in a crash loop) or layer 4 (app bug). Tonight's outage was layer 3 — the crate was stuck in a crash loop because it was started with the wrong master key.

The 5-minute fix above handles the most common cause: get a fresh crate running with the right master key. If the problem is somewhere else (layer 2 droplet itself is off, or layer 1 DNS broke), this fix won't help and you'll need Claude to walk you through something different.

---

## Diagnostic Commands (only if Claude asks for these)

```
docker ps -a
```
Shows all containers and their states. Look for `Up X` (good) vs `Restarting` or `Exited` (bad).

```
docker logs project-1 --tail 80
```
Shows what the app said before it crashed. Screenshot the output.

```
cat /root/app/config/master.key
```
Shows the real master key value. Only needed if you're debugging a key mismatch.

```
df -h /
```
Shows how full the droplet's disk is. If it says 100%, that's the problem and you need to free space.

```
free -h
```
Shows how much memory is free. If "available" is very low (under 100M), the droplet is out of memory and crashes become common.

---

## When To Call For Help

Tell Claude (or another AI assistant):
- "My site is down and EMERGENCY.md didn't fix it"
- Attach a screenshot of `docker logs project-1 --tail 80`

That's usually enough for a fresh session to pick up where you left off.
