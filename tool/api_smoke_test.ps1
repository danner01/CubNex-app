$BaseUrl = $env:API_BASE_URL
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  $BaseUrl = "https://supermarket-superadmin-rfz6.vercel.app"
}

$ApiBase = "$BaseUrl/api/v1"
$Endpoints = @(
  "/banners?limit=3",
  "/negocios?limit=3",
  "/productos/destacados?limit=3",
  "/busqueda/mapa?limit=3",
  "/tipos-negocio",
  "/suscripciones/planes?limit=3"
)

$Results = foreach ($Endpoint in $Endpoints) {
  $Url = "$ApiBase$Endpoint"
  try {
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 35
    $Stopwatch.Stop()

    $Json = $null
    try {
      $Json = $Response.Content | ConvertFrom-Json
    } catch {
      $Json = $null
    }

    $Items = "n/a"
    if ($Json -and $Json.datos -is [System.Array]) {
      $Items = $Json.datos.Count
    } elseif ($Json -and $Json.datos -and $Json.datos.familias) {
      $Items = $Json.datos.familias.Count
    }

    [PSCustomObject]@{
      Endpoint = $Endpoint
      Status = $Response.StatusCode
      Exito = $Json.exito
      Items = $Items
      Ms = $Stopwatch.ElapsedMilliseconds
      Error = ""
    }
  } catch {
    [PSCustomObject]@{
      Endpoint = $Endpoint
      Status = "ERROR"
      Exito = $false
      Items = "n/a"
      Ms = "n/a"
      Error = $_.Exception.Message
    }
  }
}

$Results | Format-Table -AutoSize
