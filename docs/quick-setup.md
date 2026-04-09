# Quick Setup Guide

Get GitHub activity posting to a Discord channel in about 5 minutes.

---

## What you need

- A GitHub repository you want to monitor
- A Discord server where you have permission to manage channels

---

## Step 1 -- Create a Discord Webhook

1. In Discord, right-click the channel you want notifications posted to
2. Select **Edit Channel**
3. Go to **Integrations** -> **Webhooks** -> **New Webhook**
4. Give the webhook a recognizable name (e.g. `cd-notify-discord`) so you
   know what it is later
5. Click **Copy Webhook URL** -- keep this somewhere safe

A webhook URL looks like this:

```
https://discord.com/api/webhooks/1234567890/aBcDeFgHiJkLmNoPqRsTuVwX
```

> Anyone who has this URL can post to your channel. Treat it like a password.

---

## Step 2 -- Download the files

Go to the [latest release](https://github.com/continuous-delphi/cd-notify-discord/releases/latest)
and download both files:

- `cd-notify-discord.ps1` -- the notification script
- `cd-notify-discord.yml` -- the GitHub Actions workflow

---

## Step 3 -- Add the files to your repository

Place the files as follows:

```
your-repo/
  .github/
    workflows/
      cd-notify-discord.yml    <-- workflow file goes here
  source
    cd-notify-discord.ps1      <-- script can go anywhere; update the
                                    workflow path if you move it
```

By default, the workflow references the script at
`./source/cd-notify-discord.ps1`. If you prefer a different location
such as `.github/scripts/`, edit the `run:` line in the workflow to match
like this:

```yaml
run: |
  ./.github/scripts/cd-notify-discord.ps1
```

---

## Step 4 -- Add the webhook secret

In your GitHub repository:

```
Settings -> Secrets and variables -> Actions -> Secrets -> New repository secret
```

| Field  | Value                                      |
|--------|--------------------------------------------|
| **Name**   | `CD_NOTIFY_DISCORD_WEBHOOK_URL`            |
| **Secret** | the webhook URL you copied in Step 1       |

---

## Step 5 -- Configure which events to notify

By default, you will not get any notifications from GitHub to Discord
until you configure one or more event variables.

In your GitHub repository:

```
Settings -> Secrets and variables -> Actions -> Variables
```

Add one or more of the following variables depending on what activity
you want posted to Discord. Any variable that is missing or empty
disables that event -- you do not need to add them all.

| Variable                        | Example value       | What it enables                          |
|---------------------------------|---------------------|------------------------------------------|
| `CD_NOTIFY_DISCORD_PUSH_BRANCHES` | `main`            | Commits pushed to the listed branches    |
| `CD_NOTIFY_DISCORD_CREATE`        | `branch,tag`      | Branch or tag creation                   |
| `CD_NOTIFY_DISCORD_RELEASE`       | `published`       | Release published                        |
| `CD_NOTIFY_DISCORD_STAR`          | `enabled`         | Repository starred                       |

### Common starting configuration

```
CD_NOTIFY_DISCORD_PUSH_BRANCHES=main
CD_NOTIFY_DISCORD_STAR=enabled
```

### Full configuration

```
CD_NOTIFY_DISCORD_PUSH_BRANCHES=main
CD_NOTIFY_DISCORD_CREATE=branch,tag
CD_NOTIFY_DISCORD_RELEASE=published
CD_NOTIFY_DISCORD_STAR=enabled
```

---

## Step 6 -- Commit and push

Commit both files and push to your repository. GitHub Actions will pick up
the workflow automatically. The next time a configured event occurs, a
notification will appear in your Discord channel.

To test immediately, push a commit to the branch you configured in
`CD_NOTIFY_DISCORD_PUSH_BRANCHES`.

---

## Step 7 -- Star your repo

You can also validate operation by starring your repo.  If you have already
added a star, unstar it and wait 30 seconds or so and then star it again.

---

## Behavior notes

- Variables are comma-separated and case-insensitive
- Whitespace around values is ignored
- Unrecognized values are silently ignored
- GitHub does not fire an event when a repository is unstarred

---

## Troubleshooting

**No notification appeared**

1. Check the workflow ran: go to **Actions** in your repository and look for
   a `cd-notify-discord` run triggered by your event
2. If the run failed, expand the step log -- the script logs each decision
   it makes (e.g. `Branch 'feature-x' is not enabled for push notifications. Skipping.`)
3. Confirm the variable name and value are spelled correctly
4. Confirm the secret is set and the webhook URL is valid

**Error: CD_NOTIFY_DISCORD_WEBHOOK_URL does not appear to be a valid Discord webhook URL**

The secret value must start with `https://discord.com/api/webhooks/` or
`https://discordapp.com/api/webhooks/`. Re-copy the URL from Discord and
update the secret.

**Push notifications not working**

The branch name in `CD_NOTIFY_DISCORD_PUSH_BRANCHES` must exactly match
the branch being pushed to (comparison is case-insensitive). Example: if
your default branch is `main`, the variable must contain `main`, not `master`.



## Example Settings Page

<img width="573" height="521" alt="image" src="https://github.com/user-attachments/assets/eb390c36-a53b-4737-a163-5619babdd06c" />
