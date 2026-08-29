$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$dataDir = Join-Path $root 'data'
$bookingsFile = Join-Path $dataDir 'bookings.json'

if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
if (-not (Test-Path $bookingsFile)) { Set-Content -Path $bookingsFile -Value '[]' -Encoding UTF8 }

function Get-MimeType {
  param([string]$Path)
  $map = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.svg'  = 'image/svg+xml'
    '.webp' = 'image/webp'
    '.ico'  = 'image/x-icon'
    '.woff' = 'font/woff'
    '.woff2' = 'font/woff2'
  }
  $ext = [System.IO.Path]::GetExtension($Path).ToLower()
  if ($map.ContainsKey($ext)) { return $map[$ext] }
  return 'application/octet-stream'
}

function Send-Json {
  param($Context, [int]$Status, $Object)
  $Context.Response.StatusCode = $Status
  $Context.Response.ContentType = 'application/json; charset=utf-8'
  $json = $Object | ConvertTo-Json -Depth 8 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.OutputStream.Close()
}

function Send-Bytes {
  param($Context, [int]$Status, [string]$ContentType, [byte[]]$Bytes)
  $Context.Response.StatusCode = $Status
  $Context.Response.ContentType = $ContentType
  $Context.Response.ContentLength64 = $Bytes.Length
  $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
  $Context.Response.OutputStream.Close()
}

function Load-Bookings {
  $raw = Get-Content $bookingsFile -Raw | ConvertFrom-Json
  if ($null -eq $raw) { @() } else { @($raw) }
}

function Save-Bookings {
  param($List)
  $json = $List | ConvertTo-Json -Depth 8
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($bookingsFile, $json, $utf8NoBom)
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:3000/')
$listener.Prefixes.Add('http://127.0.0.1:3000/')
$listener.Start()

Write-Host ''
Write-Host '================================================='
Write-Host '  Vacation Vibes backend is running'
Write-Host '  Site:      http://localhost:3000'
Write-Host '  Bookings:  POST http://localhost:3000/api/bookings'
Write-Host '  Stored in: data\bookings.json'
Write-Host '  Press Ctrl+C to stop.'
Write-Host '================================================='
Write-Host ''

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $request = $context.Request
  $response = $context.Response

  try {
    $path = $request.Url.AbsolutePath.TrimStart('/')

    if ($path -match '(^|/)\.\.(/|$)') {
      Send-Bytes $context 403 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes('403 Forbidden'))
      continue
    }

    if ($request.HttpMethod -eq 'POST' -and $path -eq 'api/bookings') {
      $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
      $body = $reader.ReadToEnd()
      $reader.Close()

      $booking = $null
      if (-not [string]::IsNullOrWhiteSpace($body)) { $booking = $body | ConvertFrom-Json }

      if ($null -eq $booking) {
        Send-Json $context 400 @{ success = $false; message = 'Invalid JSON body' }
        continue
      }

      $required = @('pickup', 'drop', 'customerName', 'customerPhone')
      $missing = @($required | Where-Object { [string]::IsNullOrWhiteSpace($booking.$_) })
      if ($missing.Count -gt 0) {
        Send-Json $context 400 @{ success = $false; message = 'Missing required fields: ' + ($missing -join ', ') }
        continue
      }

      $booking | Add-Member -NotePropertyName id -NotePropertyValue ([guid]::NewGuid().ToString())
      $booking | Add-Member -NotePropertyName createdAt -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

      $list = @(Load-Bookings)
      $list += $booking
      Save-Bookings $list

      Write-Host ("[BOOKING] {0}  {1} -> {2}  ({3})" -f $booking.createdAt, $booking.pickup, $booking.drop, $booking.customerName)
      Send-Json $context 201 @{ success = $true; message = 'Booking stored'; id = $booking.id }
      continue
    }

    if ($request.HttpMethod -eq 'GET' -and $path -eq 'api/bookings') {
      $list = @(Load-Bookings)
      Send-Json $context 200 @{ success = $true; count = $list.Count; bookings = $list }
      continue
    }

    if ([string]::IsNullOrEmpty($path)) { $path = 'index.html' }

    $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $path))
    if (-not $filePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
      Send-Bytes $context 403 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes('403 Forbidden'))
      continue
    }

    if (-not (Test-Path -LiteralPath $filePath) -or (Test-Path -LiteralPath $filePath -PathType Container)) {
      Send-Bytes $context 404 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes('404 Not Found'))
      continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    Send-Bytes $context 200 (Get-MimeType $filePath) $bytes
  } catch {
    $logLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.ToString())"
    Add-Content -Path (Join-Path $dataDir 'server.log') -Value $logLine
    try {
      Send-Json $context 500 @{ success = $false; message = $_.Exception.Message }
    } catch { }
  }
}

$listener.Stop()
