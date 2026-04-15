param(
  [int]$Port = 4173
)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Listener = [System.Net.HttpListener]::new()
$Prefix = "http://localhost:$Port/"
$Listener.Prefixes.Add($Prefix)

$MimeTypes = @{
  '.html' = 'text/html; charset=utf-8'
  '.js' = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'
  '.svg' = 'image/svg+xml'
  '.png' = 'image/png'
  '.jpg' = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.webp' = 'image/webp'
  '.m4a' = 'audio/mp4'
  '.mp3' = 'audio/mpeg'
  '.ico' = 'image/x-icon'
  '.txt' = 'text/plain; charset=utf-8'
}

function Get-ContentType([string]$Path) {
  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($MimeTypes.ContainsKey($ext)) { return $MimeTypes[$ext] }
  return 'application/octet-stream'
}

function Resolve-RequestPath([string]$RawUrl) {
  $requestPath = [System.Uri]::UnescapeDataString(($RawUrl -split '\?')[0]).TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($requestPath) -or $requestPath -eq 'index.html') {
    $requestPath = 'Daymori.html'
  }
  $combined = [System.IO.Path]::GetFullPath((Join-Path $Root $requestPath))
  if (-not $combined.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Blocked path traversal.'
  }
  return $combined
}

try {
  $Listener.Start()
  $openUrl = "${Prefix}Daymori.html"
  Write-Host "Daymori local server is running at $Prefix"
  Write-Host "Open: $openUrl"
  Start-Process $openUrl | Out-Null

  while ($Listener.IsListening) {
    $Context = $Listener.GetContext()
    try {
      $filePath = Resolve-RequestPath $Context.Request.RawUrl
      if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        $Context.Response.StatusCode = 404
        $message = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
        $Context.Response.ContentType = 'text/plain; charset=utf-8'
        $Context.Response.OutputStream.Write($message, 0, $message.Length)
      }
      else {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $Context.Response.StatusCode = 200
        $Context.Response.ContentType = Get-ContentType $filePath
        $Context.Response.ContentLength64 = $bytes.Length
        $Context.Response.AddHeader('Cache-Control', 'no-cache, no-store, must-revalidate')
        $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      }
    }
    catch {
      $Context.Response.StatusCode = 500
      $message = [System.Text.Encoding]::UTF8.GetBytes('500 Server Error')
      $Context.Response.ContentType = 'text/plain; charset=utf-8'
      $Context.Response.OutputStream.Write($message, 0, $message.Length)
    }
    finally {
      $Context.Response.OutputStream.Close()
    }
  }
}
finally {
  if ($Listener.IsListening) { $Listener.Stop() }
  $Listener.Close()
}