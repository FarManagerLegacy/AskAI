param(
    [Parameter(Mandatory=$true)]
    [string]$User
)

$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36'
$PublicKeyUrl = 'https://host.g4f.dev/backend-api/v2/public-key'

function Read-AsnLength {
    param([System.IO.BinaryReader]$br)
    $lenByte = $br.ReadByte()
    if ($lenByte -lt 0x80) { return $lenByte }
    $num = $lenByte -band 0x7F
    $value = 0
    foreach ($b in $br.ReadBytes($num)) { $value = ($value -shl 8) -bor $b }
    return $value
}

# --- helper: parse SubjectPublicKeyInfo and return [hashtable] with Modulus, Exponent (byte[])
function Parse-SubjectPublicKeyInfo {
    param([byte[]]$der)

    $ms = New-Object System.IO.MemoryStream(,$der)
    $br = New-Object System.IO.BinaryReader($ms)

    # Sequence, AlgID, BitString, RsaKey Sequence
    if ($br.ReadByte() -ne 0x30) { throw "Invalid ASN.1: expected sequence" }; Read-AsnLength $br | Out-Null
    if ($br.ReadByte() -ne 0x30) { throw "Invalid ASN.1: expected algorithm sequence" }; $br.ReadBytes((Read-AsnLength $br)) | Out-Null
    if ($br.ReadByte() -ne 0x03) { throw "Invalid ASN.1: expected bit string" }; Read-AsnLength $br; $br.ReadByte() | Out-Null
    if ($br.ReadByte() -ne 0x30) { throw "Invalid ASN.1: expected RSA public key sequence" }; Read-AsnLength $br | Out-Null

    # Read Modulus (Integer)
    if ($br.ReadByte() -ne 0x02) { throw "Invalid ASN.1: expected integer (modulus)" }
    $modLen = Read-AsnLength $br
    $modulus = $br.ReadBytes($modLen)
    if ($modulus.Length -gt 0 -and $modulus[0] -eq 0x00) { $modulus = $modulus[1..($modulus.Length-1)] }

    # Read Exponent (Integer)
    if ($br.ReadByte() -ne 0x02) { throw "Invalid ASN.1: expected integer (exponent)" }
    $expLen = Read-AsnLength $br
    $exponent = $br.ReadBytes($expLen)

    return @{ Modulus = $modulus; Exponent = $exponent }
}

# --- Main Encryption Logic
$rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
try {
    # 1. Fetch and process the public key
    $response = Invoke-RestMethod -Uri $PublicKeyUrl -UseBasicParsing
    if (-not $response.public_key) { throw "Response has no 'public_key' property." }

    # PS 5.1 compatible way to strip PEM header/footer and join lines
    $pemLines = ($response.public_key -replace '\\n', "`n").Split("`n") | Where-Object { $_ -and $_ -notmatch '-----' }
    $pemBody = $pemLines -join ''
    $der = [Convert]::FromBase64String($pemBody)

    # 2. Parse DER, build RSA parameters, and import the key
    $keyParts = Parse-SubjectPublicKeyInfo -der $der
    $rsaParameters = New-Object System.Security.Cryptography.RSAParameters
    $rsaParameters.Modulus  = $keyParts.Modulus
    $rsaParameters.Exponent = $keyParts.Exponent
    $rsa.ImportParameters($rsaParameters)

    # 3. Build payload and encrypt
    $payloadJson = @{
        data       = $response.data
        user       = $User
        timestamp  = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        user_agent = $UserAgent
    } | ConvertTo-Json -Compress
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
    $encrypted = $rsa.Encrypt($payloadBytes, $false)

    # 4. Output Base64-encoded encrypted data
    $encoded = [Convert]::ToBase64String($encrypted)
    [Console]::Write($encoded)
}
catch {
    throw "Encryption failed: $_"
}
finally {
    if ($rsa) { $rsa.Dispose() }
}
