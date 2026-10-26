param(
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    Write-Warning "File not found: $FilePath"
    exit 0
}

$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -match "Girdhar Dhami" } | Select-Object -First 1
if (-not $cert) {
    Write-Host "Generating Code Signing Certificate for Girdhar Dhami (OneBotYT)..." -ForegroundColor Cyan
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Girdhar Dhami, O=OneBotYT" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(5)
}

Write-Host "Signing $FilePath with certificate: $($cert.Subject)" -ForegroundColor Green
$sig = Set-AuthenticodeSignature -FilePath $FilePath -Certificate $cert
Write-Host "Signature Status: $($sig.Status)" -ForegroundColor Green
