param(
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$ComposeProject = 'mealgo',
    [string]$EnvFile = '.env.example',
    [string]$DatabaseUser = 'mealgo',
    [string]$DatabaseName = 'mealgo_db'
)
$ErrorActionPreference = 'Stop'

function Send-Api {
    param([string]$Method, [string]$Path, [string]$Token, $Body = $null, [hashtable]$ExtraHeaders = @{})
    $headers = @{} + $ExtraHeaders
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $options = @{ Method=$Method; Uri="$BaseUrl$Path"; Headers=$headers; ContentType='application/json' }
    if ($null -ne $Body) { $options.Body = $Body | ConvertTo-Json -Depth 10 }
    Invoke-RestMethod @options
}

function Login([string]$Username) {
    (Send-Api POST '/api/v1/auth/login' '' @{username=$Username;password='Mealgo123!'}).accessToken
}

function Set-LocationSample([string]$Session, [int]$Sequence, [double]$Latitude, [double]$Longitude) {
    Send-Api PUT '/api/v1/drivers/me/location' $driver @{
        trackingSessionId=$Session; sequence=$Sequence; latitude=$Latitude; longitude=$Longitude;
        accuracyMeters=10; recordedAt=[DateTime]::UtcNow.ToString('o')
    } | Out-Null
}

# Requires an already healthy stack with APP_SEED_ENABLED=true.
$health = Invoke-RestMethod "$BaseUrl/actuator/health"
if ($health.status -ne 'UP') { throw 'Backend is not healthy' }
$customer = Login 'customer.demo'
$merchant = Login 'merchant.demo'
$driver = Login 'driver.demo'

$ids = & docker compose --env-file $EnvFile -p $ComposeProject exec -T postgres psql -U $DatabaseUser -d $DatabaseName -At -c 'select restaurant_id, id from menu_items order by id limit 1;'
if ($LASTEXITCODE -ne 0 -or -not $ids) { throw 'Could not read demo menu IDs' }
$restaurantId, $menuItemId = ($ids | Select-Object -Last 1).Trim().Split('|')
$order = Send-Api POST '/api/v1/customers/me/orders' $customer @{
    restaurantId=$restaurantId; items=@(@{menuItemId=$menuItemId;quantity=2});
    recipient=@{name='Smoke Customer';phone='0901234567'};
    dropoff=@{address='Smoke delivery address';latitude=10.78;longitude=106.70}; paymentMethod='COD'
} @{'Idempotency-Key'=[guid]::NewGuid().ToString()}

$merchantPath = "/api/v1/merchant/restaurants/$restaurantId/orders/$($order.orderId)"
Send-Api POST "$merchantPath/accept" $merchant @{estimatedPreparationMinutes=10} | Out-Null
Send-Api PUT '/api/v1/drivers/me/online-status' $driver @{online=$true} | Out-Null

# Poll the application API for business state, not a background tool job.
$offer = $null
for ($attempt=0; $attempt -lt 15; $attempt++) {
    $offers = Send-Api GET '/api/v1/drivers/me/offers' $driver
    if ($offers.Count -gt 0) { $offer=$offers[0]; break }
    Start-Sleep -Seconds 1
}
if (-not $offer) { throw 'No offer received; ensure demo driver has no active trip' }
Send-Api POST "/api/v1/drivers/me/offers/$($offer.assignmentId)/accept" $driver | Out-Null
$current = Send-Api GET '/api/v1/drivers/me/deliveries/current' $driver
if ($current.orderId -ne $order.orderId) { throw 'Offer belongs to another pending order; use an isolated test database' }
$deliveryPath = "/api/v1/drivers/me/deliveries/$($current.deliveryId)"
$session = Send-Api POST '/api/v1/drivers/me/tracking-session' $driver
Set-LocationSample $session.trackingSessionId 1 10.7626 106.6823
Send-Api POST "$deliveryPath/arrive-at-pickup" $driver | Out-Null
Send-Api POST "$merchantPath/ready" $merchant | Out-Null
Send-Api POST "$deliveryPath/confirm-pickup" $driver | Out-Null
Set-LocationSample $session.trackingSessionId 2 10.78 106.70
Send-Api POST "$deliveryPath/arrive-at-dropoff" $driver | Out-Null
Send-Api POST "$deliveryPath/confirm-delivery" $driver | Out-Null
$tracking = Send-Api GET "/api/v1/customers/me/orders/$($order.orderId)/tracking" $customer
if ($tracking.orderStatus -ne 'DELIVERED') { throw 'Order was not delivered' }
Write-Output "PASS: PostgreSQL-backed order $($order.orderId) completed through authenticated HTTP APIs."
