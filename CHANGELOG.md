# Changelog

All notable changes to this project will be documented in this file.

---
## [1.0.0] - 2026-04-09

Initial release.

- Added `-DirectRelease` parameter to `cd-notify-discord.ps1` -- allows a
  release workflow to call the script directly after creating a release,
  bypassing the GitHub `GITHUB_TOKEN` anti-recursion limitation without
  requiring a PAT. No `CD_NOTIFY_DISCORD_RELEASE` variable needed when using
  this mode.

- Updated quick setup guide with two options for automated release workflows:
  inline `-DirectRelease` step (no PAT) and PAT-based approach. References
  the GitHub documentation on the `GITHUB_TOKEN` trigger restriction.

- `send-discord-notification.ps1` -- single-file PowerShell 7 script with no
  third-party dependencies

- **Push notifications** -- notifies on commits pushed to configured branches.
  Lists up to 5 commit SHAs and messages inline; falls back to a summary line
  for larger pushes. Controlled by `CD_NOTIFY_DISCORD_PUSH_BRANCHES`.

- **Create notifications** -- notifies when a branch or tag is created.
  Controlled by `CD_NOTIFY_DISCORD_CREATE` with values `branch` and/or `tag`.

- **Release notifications** -- notifies when a release is published.
  Controlled by `CD_NOTIFY_DISCORD_RELEASE` with value `published`.

- **Star notifications** -- notifies when a repository is starred.
  Controlled by `CD_NOTIFY_DISCORD_STAR` with value `enabled`.
  Note: GitHub fires the `watch` event with action `started`;
  there is no event for unstars.

- Configuration is driven entirely through GitHub repository (or organization)
  variables and secrets -- no code changes required to enable or disable events

- Discord embed author block on all notifications -- shows the actor's GitHub
  avatar and a link to their profile

- Discord embed timestamp on all notifications -- displays event time in the
  viewer's local timezone

- Discord markdown formatting for technical identifiers (commit SHAs, branch
  names, tag names) rendered as inline code

- Webhook URL validation on startup -- accepts both `discord.com` and
  `discordapp.com` (legacy) domains

- Defensive null checks on all GitHub event payload fields -- unknown or
  missing fields fall back to safe default values rather than crashing

- Exponential-backoff retry on Discord API calls -- up to 3 attempts with
  2 s and 4 s waits before giving up

- GitHub Actions workflow (`discord-notify.yml`) -- triggers on `push`,
  `create`, `release`, and `watch` events; passes all configuration through
  `env:` for safe injection

<br />
<br />

### `cd-notify-discord` - a developer tool from Continuous Delphi

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)

https://github.com/continuous-delphi
