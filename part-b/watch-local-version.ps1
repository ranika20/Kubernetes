$ErrorActionPreference = 'Stop'

$partB = $PSScriptRoot
$versionFile = Join-Path $partB 'VERSION'
$remoteHost = 'ubuntu1'
$remotePartB = '/home/ran/part-b'
$sshKey = Join-Path $env:USERPROFILE '.ssh\fortune-k8s'
$lastSignature = ''

function Copy-ToServer {
    param([string]$LocalPath, [string]$RemotePath)

    & scp -q -i $sshKey -o BatchMode=yes -- $LocalPath "$remoteHost`:$remotePartB/$RemotePath"
    if ($LASTEXITCODE -ne 0) {
        throw "scp failed while syncing $LocalPath. Configure SSH key authentication for '$remoteHost' first."
    }
}

function Bootstrap-ServerWatcher {
    Copy-ToServer (Join-Path $partB 'deploy.sh') 'deploy.sh'
    Copy-ToServer (Join-Path $partB 'watch-version.sh') 'watch-version.sh'
    Copy-ToServer (Join-Path $partB 'install-version-watcher.sh') 'install-version-watcher.sh'
    Copy-ToServer (Join-Path $partB 'api/server.js') 'api/server.js'
    Copy-ToServer $versionFile 'VERSION'

    & ssh -t -i $sshKey -o BatchMode=yes $remoteHost 'sudo bash /home/ran/part-b/install-version-watcher.sh'
    if ($LASTEXITCODE -ne 0) {
        throw 'Remote watcher installation failed. Confirm the SSH key works and enter the Ubuntu sudo password when prompted.'
    }
}

function Sync-VersionToServer {
    Copy-ToServer (Join-Path $partB 'api/server.js') 'api/server.js'
    Copy-ToServer $versionFile 'VERSION'
}

Write-Host "Installing/updating the Ubuntu watcher. SSH key authentication is required."
Bootstrap-ServerWatcher
Write-Host "Watching $versionFile. Keep this window open; press Ctrl+C to stop."

$source = Get-Item -LiteralPath (Join-Path $partB 'api/server.js')
$lastSignature = "$((Get-Content -LiteralPath $versionFile -Raw).Trim())|$($source.LastWriteTimeUtc.Ticks)|$($source.Length)"

while ($true) {
    try {
        $version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
        if ($version -notin @('v1', 'v2', 'v3', 'v4')) {
            throw "Unsupported VERSION '$version'. Choose v1, v2, v3, or v4."
        }

        $source = Get-Item -LiteralPath (Join-Path $partB 'api/server.js')
        $signature = "$version|$($source.LastWriteTimeUtc.Ticks)|$($source.Length)"
        if ($signature -ne $lastSignature) {
            Sync-VersionToServer
            $lastSignature = $signature
            Write-Host "Synced $version and API source to $remoteHost. The server watcher will build and deploy it."
        }
    } catch {
        Write-Warning $_
    }

    Start-Sleep -Seconds 2
}
