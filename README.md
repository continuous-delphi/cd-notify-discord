# cd-notify-discord

![cd-notify-discord logo](/assets/cd-notify-discord-logo_350x350.png)

[![CI](https://github.com/continuous-delphi/cd-notify-discord/actions/workflows/ci.yml/badge.svg)](https://github.com/continuous-delphi/cd-notify-discord/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/continuous-delphi/cd-notify-discord)
[![Continuous Delphi](https://img.shields.io/badge/org-continuous--delphi-red)](https://github.com/continuous-delphi)

A lightweight `GitHub -> Discord` notification pipeline for
repository activity.

---

## Overview

`cd-notify-discord` provides a simple, configurable way to send GitHub
repository activity to a Discord channel using a webhook.

It is designed to be:

* configuration-driven
* free from third-party dependencies
* simple to use

Events are configured using `Repository` or `Organization` variables
that are defined under `Secrets and variables` section in Settings.
A required `Discord webhook` is also set as a `repository secret`.

See the [quick setup guide](/docs/quick-setup.md) to be up and running
in a few minutes.

---

## Supported Events

The following GitHub activities are currently supported.
More may be added later by request.

* Push (commits)
* Create (branch / tag)
* Release (publish)
* Star (created/deleted)

Each event is enabled and configured via a named variable as defined below.  
`{variable name}={allowed values}`

  

### Push (commits)

Triggered on repository pushes and configurable by branch:

```text
CD_NOTIFY_DISCORD_PUSH_BRANCHES=main,develop,staging
```

Only pushes to the specified branches will generate notifications.

---

### Create (branch / tag)

Triggered whenever a branch or tag is created.

```text
CD_NOTIFY_DISCORD_CREATE=branch,tag
```

Supported values:

* `branch`
* `tag`

---

### Release

Triggered on release activity.  Currently only supports `published`
releases.

```text
CD_NOTIFY_DISCORD_RELEASE=published
```

---

### Star

Triggered when a repository is starred.

```text
CD_NOTIFY_DISCORD_STAR=enabled
```

Supported values:

* `enabled`

<img width="536" height="206" alt="image" src="https://github.com/user-attachments/assets/5550abff-5cbf-4aab-891a-b954f9e80fb6" />


---

## Configuration

Configuration is driven entirely through GitHub repository settings and
requires a `Discord Webhook` to establish communication with Discord from GitHub
and `Repository variables` to determine which activities trigger notifications.
Note the variables could be set at the `Organization` level if desired.

### Discord Webhook

#### How to create a Discord Webhook

* Webhooks are created in Discord:
Right-click your channel -> Edit Channel -> Integrations -> Webhooks -> New Webhook`

* View the created webook and click on the `Copy Webhook URL` button to copy it to
the clipboard (and it is recommended to explicitly name the webhook while you are
there so you will know later what exactly it is being used for.)

#### What does a webhook look like

```text
https://discord.com/api/webhooks/23322424/aaabbbcccdddeeefffggg
```

#### Where do you configure your GitHub Repo's discord webook

* Location:

```text
Repository -> Settings -> Secrets and variables -> Actions -> Secrets -> New repository secret
```

* `Name` = `CD_NOTIFY_DISCORD_WEBHOOK_URL`
* `Secret` = `https://discord.com/api/webhooks/23322424/aaabbbcccdddeeefffggg`

The secret you enter in the configuration settings is the value copied from Discord
when you created the webhook and it should be kept secret. (Anyone with this webhook
could post activity on your Discord channel.)

---

### Events to track are defined in variables

Location:

```text
Repository -> Settings -> Secrets and variables -> Actions -> Variables
```

Examples:

```text
CD_NOTIFY_DISCORD_PUSH_BRANCHES=main
CD_NOTIFY_DISCORD_CREATE=branch,tag
CD_NOTIFY_DISCORD_RELEASE=published
CD_NOTIFY_DISCORD_STAR=enabled
```

---

## Behavior Rules

* Missing or empty variables -> feature is disabled
* Values are comma-separated
* Values are case-insensitive
* Whitespace is ignored
* Unknown values are ignored

---

## Example Workflow

```yaml
name: Notify Discord of GitHub Activity (`cd-notify-discord` from Continous-Delphi)
on:
  push:
  create:
  release:
    types: [published]
  watch:

jobs:
  notify:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Send Discord notification
        shell: pwsh
        env:
          CD_NOTIFY_DISCORD_WEBHOOK_URL:    ${{ secrets.CD_NOTIFY_DISCORD_WEBHOOK_URL }}
          CD_NOTIFY_DISCORD_PUSH_BRANCHES:  ${{ vars.CD_NOTIFY_DISCORD_PUSH_BRANCHES }}
          CD_NOTIFY_DISCORD_CREATE:         ${{ vars.CD_NOTIFY_DISCORD_CREATE }}
          CD_NOTIFY_DISCORD_RELEASE:        ${{ vars.CD_NOTIFY_DISCORD_RELEASE }}
          CD_NOTIFY_DISCORD_STAR:           ${{ vars.CD_NOTIFY_DISCORD_STAR }}
          GITHUB_EVENT_NAME:                ${{ github.event_name }}
          GITHUB_EVENT_PATH:                ${{ github.event_path }}
        run: |
          ./source/cd-notify-discord.ps1
```

---

## Continuous-Delphi

This tool is part of the [Continuous-Delphi](https://github.com/continuous-delphi)
ecosystem, focused on strengthening Delphi's continued success

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)
