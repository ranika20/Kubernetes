$ErrorActionPreference = 'Stop'

function Invoke-Docker {
    param([string[]]$Arguments)

    & docker @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed: docker $($Arguments -join ' ')"
    }
}

$version = (Get-Content (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^v[1-4]$') {
    throw "Unsupported VERSION '$version'. Set part-b\VERSION to v1, v2, v3, or v4."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker was not found. Install and start Docker Desktop, then rerun this script.'
}

Invoke-Docker -Arguments @('info', '--format', '{{.ServerVersion}}')

$network = 'fortune-local'
$networkNames = @(& docker network ls --format '{{.Name}}')
if ($LASTEXITCODE -ne 0) {
    throw 'Could not list Docker networks.'
}
if ($networkNames -notcontains $network) {
    Invoke-Docker -Arguments @('network', 'create', $network)
}

$apiImage = "fortune-api:$version"
$webImage = "fortune-web-local:$version"
$apiPath = Join-Path $PSScriptRoot 'api'
$frontendPath = Join-Path $PSScriptRoot 'frontend'

Invoke-Docker -Arguments @('build', '--build-arg', "APP_VERSION=$version", '-t', $apiImage, $apiPath)
Invoke-Docker -Arguments @('build', '-f', (Join-Path $frontendPath 'Dockerfile.local'), '-t', $webImage, $frontendPath)

$containerNames = @(& docker ps -a --format '{{.Names}}')
if ($LASTEXITCODE -ne 0) {
    throw 'Could not list Docker containers.'
}
foreach ($name in @('fortune-api-local', 'fortune-web-local')) {
    if ($containerNames -contains $name) {
        Invoke-Docker -Arguments @('rm', '-f', $name)
    }
}

Invoke-Docker -Arguments @(
    'run', '-d',
    '--name', 'fortune-api-local',
    '--network', $network,
    '--network-alias', 'fortune-api',
    '--env', "APP_VERSION=$version",
    $apiImage
)
Invoke-Docker -Arguments @(
    'run', '-d',
    '--name', 'fortune-web-local',
    '--network', $network,
    '--publish', '30090:80',
    $webImage
)

$url = 'http://localhost:30090/'
$ready = $false
for ($attempt = 0; $attempt -lt 15; $attempt++) {
    & curl.exe --fail --silent --max-time 5 $url --output NUL
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    & docker logs fortune-web-local
    throw "The website did not become available at $url"
}

$fortune = & curl.exe --fail --silent --show-error --max-time 5 "${url}api/fortune"
if ($LASTEXITCODE -ne 0) {
    & docker logs fortune-web-local
    & docker logs fortune-api-local
    throw 'The website loaded, but the API did not respond.'
}

Write-Host "Website is ready: $url (API $version)"
Write-Host $fortune
