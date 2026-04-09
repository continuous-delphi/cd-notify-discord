Set-StrictMode -Version Latest
$ErrorActionPreference  = 'Stop'
$InformationPreference  = 'Continue'

# -----------------------------------------------------------------------------
# cd-notify-discord
#
# A PowerShell utility to send Discord notifications based on GitHub repository
# activity such as commits, stars, releases, and branch creations
#
# Part of Continuous-Delphi: Focused on strengthening Delphi's continued success
# https://github.com/continuous-delphi
#
# Project repository:
# https://github.com/continuous-delphi/cd-notify-discord
#
# Copyright (c) 2026 Darian Miller
# Licensed under the MIT License.
# https://opensource.org/licenses/MIT
# SPDX-License-Identifier: MIT
# -----------------------------------------------------------------------------

function Write-ActivityLog {
<#
.SYNOPSIS
    Writes a prefixed log message to the information stream.
.PARAMETER Message
    The message to log.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Information "[cd-notify-discord] $Message"
}

function Get-EnvValue {
<#
.SYNOPSIS
    Reads an environment variable and trims whitespace.
.PARAMETER Name
    The name of the environment variable to read.
.OUTPUTS
    The trimmed string value, or empty string if not set.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $value = [System.Environment]::GetEnvironmentVariable($Name)
    if ($null -eq $value) {
        return ''
    }

    return $value.Trim()
}

function Get-ConfigList {
<#
.SYNOPSIS
    Reads a comma-separated environment variable and returns a normalized list.
.DESCRIPTION
    Splits the variable value by comma, trims each item, and lowercases it.
    Empty or whitespace-only items are discarded.
.PARAMETER Name
    The name of the environment variable to read.
.OUTPUTS
    Array of normalized (trimmed, lowercase) string values.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $raw = Get-EnvValue -Name $Name
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $items = @()

    foreach ($part in ($raw -split ',')) {
        $item = $part.Trim().ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $items += $item
        }
    }

    return @($items)
}

function Test-ConfigValue {
<#
.SYNOPSIS
    Tests whether a given value is present in a list of configured values.
.PARAMETER ConfiguredValues
    The list of normalized configured values to check against.
.PARAMETER Value
    The value to look up (normalized before comparison).
.OUTPUTS
    True if the normalized value is in the list; false otherwise.
#>
    param(
        [Parameter(Mandatory)]
        [string[]]$ConfiguredValues,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $normalized = $Value.Trim().ToLowerInvariant()
    return $ConfiguredValues -contains $normalized
}

function Get-AllowedValue {
<#
.SYNOPSIS
    Returns the intersection of configured values and supported values for a variable.
.DESCRIPTION
    Reads the named environment variable, normalizes its values, filters to only
    those present in SupportedValues, logs any unrecognized values, and returns
    the allowed subset.
.PARAMETER VariableName
    The environment variable name to read.
.PARAMETER SupportedValues
    The set of recognized/supported values for this variable.
.OUTPUTS
    Array of allowed (recognized and configured) values, or empty array if none.
#>
    param(
        [Parameter(Mandatory)]
        [string]$VariableName,

        [Parameter(Mandatory)]
        [string[]]$SupportedValues
    )

    $configured = @(Get-ConfigList -Name $VariableName)
    if ($configured.Count -eq 0) {
        Write-ActivityLog "$VariableName is not set. Event type is disabled."
        return @()
    }

    $allowed = @()
    $unknown = @()

    foreach ($value in $configured) {
        if ($SupportedValues -contains $value) {
            $allowed += $value
        }
        else {
            $unknown += $value
        }
    }

    if ($unknown.Count -gt 0) {
        Write-ActivityLog "Ignoring unsupported value(s) for ${VariableName}: $($unknown -join ', ')"
    }

    return @($allowed)
}

function Get-JsonFile {
<#
.SYNOPSIS
    Reads and parses a JSON file from the given path.
.PARAMETER Path
    The file system path to the JSON file.
.OUTPUTS
    A PSCustomObject representing the parsed JSON content.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Event payload file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Event payload file is empty: $Path"
    }

    return ($raw | ConvertFrom-Json -Depth 100)
}

function Get-SafeValue {
<#
.SYNOPSIS
    Returns a string value from an event payload field, with a fallback if null or empty.
.PARAMETER Value
    The value to evaluate (may be null or a PSCustomObject property).
.PARAMETER Fallback
    The string to return when Value is null or whitespace. Defaults to 'Unknown'.
.OUTPUTS
    The string value of Value, or Fallback if null/whitespace.
#>
    param(
        [object]$Value,
        [string]$Fallback = 'Unknown'
    )

    if ($null -eq $Value) {
        return $Fallback
    }

    $str = [string]$Value
    if ([string]::IsNullOrWhiteSpace($str)) {
        return $Fallback
    }

    return $str
}

function Get-ShortSha {
<#
.SYNOPSIS
    Returns the first 7 characters of a commit SHA.
.PARAMETER Sha
    The full or partial commit SHA string.
.OUTPUTS
    A 7-character (or shorter) SHA string, or empty string if input is blank.
#>
    param(
        [string]$Sha
    )

    if ([string]::IsNullOrWhiteSpace($Sha)) {
        return ''
    }

    if ($Sha.Length -le 7) {
        return $Sha
    }

    return $Sha.Substring(0, 7)
}

function Get-RefNameFromFullRef {
<#
.SYNOPSIS
    Strips the refs/heads/ or refs/tags/ prefix from a full Git ref string.
.PARAMETER Ref
    The full Git ref (e.g. refs/heads/main or refs/tags/v1.0.0).
.OUTPUTS
    The short ref name (e.g. main or v1.0.0), or the original string if no prefix matched.
#>
    param(
        [string]$Ref
    )

    if ([string]::IsNullOrWhiteSpace($Ref)) {
        return ''
    }

    if ($Ref.StartsWith('refs/heads/')) {
        return $Ref.Substring('refs/heads/'.Length)
    }

    if ($Ref.StartsWith('refs/tags/')) {
        return $Ref.Substring('refs/tags/'.Length)
    }

    return $Ref
}

function Build-DiscordEmbed {
<#
.SYNOPSIS
    Builds a Discord embed hashtable for use with the webhook API.
.PARAMETER Title
    The embed title text.
.PARAMETER Description
    The embed description text (supports Discord markdown).
.PARAMETER Url
    Optional URL that the title links to.
.PARAMETER Fields
    Optional array of field hashtables created by Build-DiscordField.
.PARAMETER Timestamp
    UTC datetime to display in the embed footer. Defaults to the current UTC time.
.OUTPUTS
    Hashtable representing a Discord embed object.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [string]$Url,

        [hashtable[]]$Fields = @(),

        [datetime]$Timestamp = [datetime]::UtcNow
    )

    $embed = @{
        title       = $Title
        description = $Description
        fields      = @($Fields)
        timestamp   = $Timestamp.ToString('o')
    }

    if (-not [string]::IsNullOrWhiteSpace($Url)) {
        $embed.url = $Url
    }

    return $embed
}

function Build-DiscordField {
<#
.SYNOPSIS
    Builds a Discord embed field hashtable.
.PARAMETER Name
    The field label (bold in Discord).
.PARAMETER Value
    The field value text (supports Discord markdown).
.PARAMETER Inline
    When true the field renders side-by-side with adjacent inline fields. Defaults to true.
.OUTPUTS
    Hashtable representing a Discord embed field object.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [bool]$Inline = $true
    )

    return @{
        name   = $Name
        value  = $Value
        inline = $Inline
    }
}

function Send-DiscordMessage {
<#
.SYNOPSIS
    Posts a message with an embed to a Discord webhook, with exponential-backoff retry.
.DESCRIPTION
    Serializes the content and embed to JSON and calls the Discord webhook API.
    On failure, retries up to two additional times with increasing wait intervals
    (2 s then 4 s). Throws on the third consecutive failure.
.PARAMETER WebhookUrl
    The Discord webhook URL to post to.
.PARAMETER Content
    The plain-text message content shown above the embed.
.PARAMETER Embed
    The embed hashtable produced by Build-DiscordEmbed.
#>
    param(
        [Parameter(Mandatory)]
        [string]$WebhookUrl,

        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [hashtable]$Embed
    )

    $payload = @{
        content = $Content
        embeds  = @($Embed)
    } | ConvertTo-Json -Depth 20

    Write-ActivityLog "Sending Discord notification..."

    $maxRetries = 3
    $attempt    = 0

    while ($true) {
        $attempt++
        try {
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType 'application/json' -Body $payload | Out-Null
            Write-ActivityLog "Discord notification sent successfully."
            return
        }
        catch {
            if ($attempt -ge $maxRetries) {
                throw
            }
            $waitSeconds = [Math]::Pow(2, $attempt)
            Write-ActivityLog "Discord API call failed (attempt $attempt of $maxRetries). Retrying in $waitSeconds seconds..."
            Start-Sleep -Seconds $waitSeconds
        }
    }
}

function Send-PushNotification {
<#
.SYNOPSIS
    Handles a GitHub push event and sends a Discord notification if the branch is configured.
.PARAMETER GitHubEvent
    The parsed GitHub event payload.
.PARAMETER WebhookUrl
    The Discord webhook URL to post to.
#>
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GitHubEvent,

        [Parameter(Mandatory)]
        [string]$WebhookUrl
    )

    $allowedBranches = @(Get-ConfigList -Name 'CD_NOTIFY_DISCORD_PUSH_BRANCHES')
    if ($allowedBranches.Count -eq 0) {
        Write-ActivityLog 'CD_NOTIFY_DISCORD_PUSH_BRANCHES is not set. Push notifications are disabled.'
        return
    }

    $branchName = Get-RefNameFromFullRef -Ref (Get-SafeValue -Value $GitHubEvent.ref -Fallback '')
    if ([string]::IsNullOrWhiteSpace($branchName)) {
        Write-ActivityLog 'Could not determine branch name from push event. Skipping.'
        return
    }

    if (-not (Test-ConfigValue -ConfiguredValues $allowedBranches -Value $branchName)) {
        Write-ActivityLog "Branch '$branchName' is not enabled for push notifications. Skipping."
        return
    }

    $repoName    = Get-SafeValue -Value $GitHubEvent.repository.full_name -Fallback 'Unknown Repository'
    $actor       = Get-SafeValue -Value $GitHubEvent.sender.login         -Fallback 'Unknown User'
    $compareUrl  = Get-SafeValue -Value $GitHubEvent.compare              -Fallback ''
    $commitCount = @($GitHubEvent.commits).Count

    $descriptionLines = @()
    if ($commitCount -eq 1) {
        $commit   = $GitHubEvent.commits[0]
        $shortSha = Get-ShortSha -Sha (Get-SafeValue -Value $commit.id -Fallback '')
        $message  = ((Get-SafeValue -Value $commit.message -Fallback '') -split "(`r`n|`n|`r)")[0]
        $descriptionLines += "1 commit pushed to ``$branchName``."
        $descriptionLines += ''
        $descriptionLines += "``$shortSha`` - $message"
    }
    elseif ($commitCount -gt 1 -and $commitCount -le 5) {
        $descriptionLines += "$commitCount commits pushed to ``$branchName``."
        $descriptionLines += ''
        foreach ($commit in $GitHubEvent.commits) {
            $shortSha = Get-ShortSha -Sha (Get-SafeValue -Value $commit.id -Fallback '')
            $message  = ((Get-SafeValue -Value $commit.message -Fallback '') -split "(`r`n|`n|`r)")[0]
            $descriptionLines += "``$shortSha`` - $message"
        }
    }
    else {
        $descriptionLines += "$commitCount commits pushed to ``$branchName``."
        $descriptionLines += 'See compare link for full details.'
    }

    $embed = Build-DiscordEmbed `
        -Title "[$repoName] Push" `
        -Description ($descriptionLines -join "`n") `
        -Url $compareUrl `
        -Fields @(
            (Build-DiscordField -Name 'Repository'   -Value $repoName),
            (Build-DiscordField -Name 'Branch'       -Value "``$branchName``"),
            (Build-DiscordField -Name 'Actor'        -Value $actor),
            (Build-DiscordField -Name 'Commit Count' -Value ([string]$commitCount))
        )

    Send-DiscordMessage `
        -WebhookUrl $WebhookUrl `
        -Content "GitHub activity: push in $repoName" `
        -Embed $embed
}

function Send-CreateNotification {
<#
.SYNOPSIS
    Handles a GitHub create event (branch or tag) and sends a Discord notification if configured.
.PARAMETER GitHubEvent
    The parsed GitHub event payload.
.PARAMETER WebhookUrl
    The Discord webhook URL to post to.
#>
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GitHubEvent,

        [Parameter(Mandatory)]
        [string]$WebhookUrl
    )

    $allowedCreateTypes = @(Get-AllowedValue `
        -VariableName 'CD_NOTIFY_DISCORD_CREATE' `
        -SupportedValues @('branch', 'tag'))

    if ($allowedCreateTypes.Count -eq 0) {
        Write-ActivityLog 'Create notifications are disabled.'
        return
    }

    $refType = Get-SafeValue -Value $GitHubEvent.ref_type -Fallback ''
    if ([string]::IsNullOrWhiteSpace($refType)) {
        Write-ActivityLog 'Create event did not include ref_type. Skipping.'
        return
    }

    $normalizedRefType = $refType.Trim().ToLowerInvariant()
    if (-not (Test-ConfigValue -ConfiguredValues $allowedCreateTypes -Value $normalizedRefType)) {
        Write-ActivityLog "Create notifications are not enabled for ref_type '$normalizedRefType'. Skipping."
        return
    }

    $repoName = Get-SafeValue -Value $GitHubEvent.repository.full_name -Fallback 'Unknown Repository'
    $actor    = Get-SafeValue -Value $GitHubEvent.sender.login         -Fallback 'Unknown User'
    $refName  = Get-SafeValue -Value $GitHubEvent.ref                  -Fallback 'Unknown'
    $repoUrl  = Get-SafeValue -Value $GitHubEvent.repository.html_url  -Fallback ''

    $title = if ($normalizedRefType -eq 'branch') {
        "[$repoName] Branch Created"
    }
    else {
        "[$repoName] Tag Created"
    }

    $description = if ($normalizedRefType -eq 'branch') {
        "Branch ``$refName`` was created."
    }
    else {
        "Tag ``$refName`` was created."
    }

    $embed = Build-DiscordEmbed `
        -Title $title `
        -Description $description `
        -Url $repoUrl `
        -Fields @(
            (Build-DiscordField -Name 'Repository' -Value $repoName),
            (Build-DiscordField -Name 'Type'       -Value $normalizedRefType),
            (Build-DiscordField -Name 'Name'       -Value "``$refName``"),
            (Build-DiscordField -Name 'Actor'      -Value $actor)
        )

    Send-DiscordMessage `
        -WebhookUrl $WebhookUrl `
        -Content "GitHub activity: create in $repoName" `
        -Embed $embed
}

function Send-ReleaseNotification {
<#
.SYNOPSIS
    Handles a GitHub release event and sends a Discord notification if the action is configured.
.PARAMETER GitHubEvent
    The parsed GitHub event payload.
.PARAMETER WebhookUrl
    The Discord webhook URL to post to.
#>
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GitHubEvent,

        [Parameter(Mandatory)]
        [string]$WebhookUrl
    )

    $allowedReleaseActions = @(Get-AllowedValue `
        -VariableName 'CD_NOTIFY_DISCORD_RELEASE' `
        -SupportedValues @('published'))

    if ($allowedReleaseActions.Count -eq 0) {
        Write-ActivityLog 'Release notifications are disabled.'
        return
    }

    $action = Get-SafeValue -Value $GitHubEvent.action -Fallback ''
    if ([string]::IsNullOrWhiteSpace($action)) {
        Write-ActivityLog 'Release event did not include action. Skipping.'
        return
    }

    $normalizedAction = $action.Trim().ToLowerInvariant()
    if (-not (Test-ConfigValue -ConfiguredValues $allowedReleaseActions -Value $normalizedAction)) {
        Write-ActivityLog "Release notifications are not enabled for action '$normalizedAction'. Skipping."
        return
    }

    $repoName    = Get-SafeValue -Value $GitHubEvent.repository.full_name -Fallback 'Unknown Repository'
    $actor       = Get-SafeValue -Value $GitHubEvent.sender.login         -Fallback 'Unknown User'
    $releaseName = Get-SafeValue -Value $GitHubEvent.release.name         -Fallback ''
    $tagName     = Get-SafeValue -Value $GitHubEvent.release.tag_name     -Fallback 'Unknown'
    $releaseUrl  = Get-SafeValue -Value $GitHubEvent.release.html_url     -Fallback ''

    if ([string]::IsNullOrWhiteSpace($releaseName)) {
        $releaseName = $tagName
    }

    $embed = Build-DiscordEmbed `
        -Title "[$repoName] Release Published" `
        -Description "Release '$releaseName' was published." `
        -Url $releaseUrl `
        -Fields @(
            (Build-DiscordField -Name 'Repository' -Value $repoName),
            (Build-DiscordField -Name 'Release'    -Value $releaseName),
            (Build-DiscordField -Name 'Tag'        -Value "``$tagName``"),
            (Build-DiscordField -Name 'Actor'      -Value $actor)
        )

    Send-DiscordMessage `
        -WebhookUrl $WebhookUrl `
        -Content "GitHub activity: release published in $repoName" `
        -Embed $embed
}

function Send-StarNotification {
<#
.SYNOPSIS
    Handles a GitHub watch event (star) and sends a Discord notification if configured.
.DESCRIPTION
    GitHub fires the 'watch' event for star activity with action 'started'.
    There is no event for unstars -- GitHub does not fire the watch event on unstar.
    CD_NOTIFY_DISCORD_STAR controls which actions are notified; only 'started' is valid.
.PARAMETER GitHubEvent
    The parsed GitHub event payload.
.PARAMETER WebhookUrl
    The Discord webhook URL to post to.
#>
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GitHubEvent,

        [Parameter(Mandatory)]
        [string]$WebhookUrl
    )

    $allowedStarActions = @(Get-AllowedValue `
        -VariableName 'CD_NOTIFY_DISCORD_STAR' `
        -SupportedValues @('started'))

    if ($allowedStarActions.Count -eq 0) {
        Write-ActivityLog 'Star notifications are disabled.'
        return
    }

    $action = Get-SafeValue -Value $GitHubEvent.action -Fallback ''
    if ([string]::IsNullOrWhiteSpace($action)) {
        Write-ActivityLog 'Star event did not include action. Skipping.'
        return
    }

    $normalizedAction = $action.Trim().ToLowerInvariant()
    if (-not (Test-ConfigValue -ConfiguredValues $allowedStarActions -Value $normalizedAction)) {
        Write-ActivityLog "Star notifications are not enabled for action '$normalizedAction'. Skipping."
        return
    }

    $repoName = Get-SafeValue -Value $GitHubEvent.repository.full_name -Fallback 'Unknown Repository'
    $actor    = Get-SafeValue -Value $GitHubEvent.sender.login         -Fallback 'Unknown User'
    $repoUrl  = Get-SafeValue -Value $GitHubEvent.repository.html_url  -Fallback ''

    $title       = "[$repoName] Star Added"
    $description = "'$actor' starred the repository."

    $embed = Build-DiscordEmbed `
        -Title $title `
        -Description $description `
        -Url $repoUrl `
        -Fields @(
            (Build-DiscordField -Name 'Repository' -Value $repoName),
            (Build-DiscordField -Name 'Action'     -Value $normalizedAction),
            (Build-DiscordField -Name 'User'       -Value $actor)
        )

    Send-DiscordMessage `
        -WebhookUrl $WebhookUrl `
        -Content "GitHub activity: star event in $repoName" `
        -Embed $embed
}

function Main {
    $webhookUrl = Get-EnvValue -Name 'CD_NOTIFY_DISCORD_WEBHOOK_URL'
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        throw 'Required secret CD_NOTIFY_DISCORD_WEBHOOK_URL is not set.'
    }

    if ($webhookUrl -notmatch '^https://(discord\.com|discordapp\.com)/api/webhooks/\d+/[A-Za-z0-9_-]+$') {
        throw 'CD_NOTIFY_DISCORD_WEBHOOK_URL does not appear to be a valid Discord webhook URL.'
    }

    $eventName = Get-EnvValue -Name 'GITHUB_EVENT_NAME'
    if ([string]::IsNullOrWhiteSpace($eventName)) {
        throw 'GITHUB_EVENT_NAME is not set.'
    }

    $eventPath = Get-EnvValue -Name 'GITHUB_EVENT_PATH'
    if ([string]::IsNullOrWhiteSpace($eventPath)) {
        throw 'GITHUB_EVENT_PATH is not set.'
    }

    Write-ActivityLog "GitHub event name: $eventName"
    Write-ActivityLog "GitHub event path: $eventPath"

    $githubEvent = Get-JsonFile -Path $eventPath

    switch ($eventName.Trim().ToLowerInvariant()) {
        'push' {
            Send-PushNotification -GitHubEvent $githubEvent -WebhookUrl $webhookUrl
        }

        'create' {
            Send-CreateNotification -GitHubEvent $githubEvent -WebhookUrl $webhookUrl
        }

        'release' {
            Send-ReleaseNotification -GitHubEvent $githubEvent -WebhookUrl $webhookUrl
        }

        'watch' {
            Send-StarNotification -GitHubEvent $githubEvent -WebhookUrl $webhookUrl
        }

        default {
            Write-ActivityLog "Unsupported event '$eventName'. No notification sent."
        }
    }
}

Main
