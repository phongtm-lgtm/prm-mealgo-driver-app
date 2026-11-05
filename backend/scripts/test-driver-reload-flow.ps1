param(
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$Password = 'Mealgo123!'
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Text)
    Write-Host "`n>>> $Text" -ForegroundColor Cyan
}

function Write-Pass {
    param([string]$Text)
    Write-Host "  [PASS] $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [INFO] $Text" -ForegroundColor Gray
}

function Send-Api {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Token = $null,
        $Body = $null,
        [hashtable]$ExtraHeaders = @{}
    )
    $headers = @{} + $ExtraHeaders
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $options = @{
        Method = $Method
        Uri = "$BaseUrl$Path"
        Headers = $headers
        ContentType = 'application/json; charset=utf-8'
    }
    if ($null -ne $Body) {
        $options.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }
    Invoke-RestMethod @options
}

function Login([string]$PhoneNumber) {
    $res = Send-Api POST '/api/v1/auth/login' -Body @{
        phoneNumber = $PhoneNumber
        password = $Password
    }
    return $res.accessToken
}

Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host " MEALGO: TEST CASE AUTOMATION - DRIVER RELOAD (FREE-PICK OFFERS)" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host "Target Base URL: $BaseUrl"

# 0. Kiểm tra kết nối Backend
Write-Step "0. Kiem tra Backend Health Check..."
try {
    $health = Invoke-RestMethod "$BaseUrl/actuator/health" -TimeoutSec 5
    if ($health.status -ne 'UP') { throw "Backend chua UP (status=$($health.status))" }
    Write-Pass "Backend dang hoat dong binh thuong (UP)."
} catch {
    Write-Host "  [FAIL] Khong the ket noi toi Backend tai $BaseUrl. Vui long chay Backend truoc!" -ForegroundColor Red
    exit 1
}

# 1. Đăng nhập 3 bên
Write-Step "1. Dang nhap cac tai khoan Demo..."
$customerToken = Login '0900000003'
Write-Pass "Customer (0900000003) dang nhap thanh cong."

$merchantToken = Login '0900000002'
Write-Pass "Merchant (0900000002) dang nhap thanh cong."

$driverToken = Login '0900000001'
Write-Pass "Driver (0900000001) dang nhap thanh cong."

# Lấy Menu
$menu = Send-Api GET '/api/v1/customers/menu?restaurantName=MealGo%20Demo%20Restaurant' -Token $customerToken
$shop = ($menu | Where-Object { $_.restaurantName -like '*MealGo Demo Restaurant*' })
if (-not $shop) { $shop = $menu[0] }
$restaurantId = $shop.restaurantId
$menuItemId = ($shop.items | Where-Object { $_.available -ne $false })[0].menuItemId
Write-Info "Restaurant ID: $restaurantId | Menu Item ID: $menuItemId"

# 2. Tạo sẵn 3 đơn hàng pending & Quán chấp nhận
Write-Step "2. Tao va phe duyet san 3 don hang de dua vao hang cho PENDING_ASSIGNMENT..."
$orders = @()
for ($i = 1; $i -le 3; $i++) {
    $newOrder = Send-Api POST '/api/v1/customers/me/orders' -Token $customerToken -Body @{
        restaurantId = $restaurantId
        items = @(@{ menuItemId = $menuItemId; quantity = 1; note = "Don so $i - Test reload" })
        recipient = @{ name = "Khach don $i"; phone = "090123450$i" }
        dropoff = @{ address = "Diem giao $i"; latitude = (21.0382 + ($i * 0.0002)); longitude = (105.5470 + ($i * 0.0001)) }
        deliveryNote = "Giao don $i"
        paymentMethod = "COD"
    } -ExtraHeaders @{ 'Idempotency-Key' = [guid]::NewGuid().ToString() }

    $oId = $newOrder.orderId
    $orders += $oId
    Write-Info "-> Khach da dat Don #$i: $oId"

    # Quán nhận đơn
    Send-Api POST "/api/v1/merchant/restaurants/$restaurantId/orders/$oId/accept" -Token $merchantToken -Body @{
        estimatedPreparationMinutes = 10
    } | Out-Null
    Write-Pass "Don #$i da duoc Quan xac nhan (PREPARING)."
}

# 3. Tài xế Online và nhận Đề xuất #1
Write-Step "3. Driver vao ca (Online) va nhan de xuat don dau tien..."
Send-Api PUT '/api/v1/drivers/me/online-status' -Token $driverToken -Body @{ online = $true } | Out-Null
Write-Pass "Driver da Online."

# Lấy đề xuất đầu tiên
$offers = Send-Api POST '/api/v1/drivers/me/offers/refresh' -Token $driverToken -Body @{ skippedAssignmentIds = @() }
if ($offers.Count -eq 0) { throw "Khong co de xuat nao duoc tao cho Driver!" }
$offer1 = $offers[0]
Write-Pass "Driver nhan de xuat Don #1 tren man hinh:"
Write-Info "   Offer 1 Assignment ID: $($offer1.assignmentId)"
Write-Info "   Offer 1 Order ID     : $($offer1.orderId)"

# 4. Tài xế ấn Reload lần 1 (Không muốn nhận Đơn 1)
Write-Step "4. Driver an Reload lan 1: Bo qua Don #1 vi khong muon nhan..."
$offersAfterReload1 = Send-Api POST '/api/v1/drivers/me/offers/refresh' -Token $driverToken -Body @{
    skippedAssignmentIds = @($offer1.assignmentId)
}
if ($offersAfterReload1.Count -eq 0) { throw "Khong tim thay don tiep theo sau khi reload lan 1!" }
$offer2 = $offersAfterReload1[0]

if ($offer2.assignmentId -eq $offer1.assignmentId) {
    throw "Loi: AssignmentId sau reload khong doi! Van la don cu."
}
if ($offer2.orderId -eq $offer1.orderId) {
    throw "Loi: OrderId sau reload khong doi! He thong chua chuyen don."
}
Write-Pass "Reload lan 1 THANH CONG: Man hinh da cap nhat sang Don #2 moi!"
Write-Info "   Offer 2 Assignment ID: $($offer2.assignmentId) (Khac Offer 1)"
Write-Info "   Offer 2 Order ID     : $($offer2.orderId) (Khac Order 1)"

# Kiểm tra trạng thái Offer 1
$checkOffer1 = Send-Api GET "/api/v1/drivers/me/offers/$($offer1.assignmentId)" -Token $driverToken
if ($checkOffer1.status -ne 'REJECTED') {
    throw "Loi: Offer 1 chua duoc ghi nhan la REJECTED (status=$($checkOffer1.status))"
}
Write-Pass "Offer 1 da duoc he thong cap nhat trang thai thanh cong: REJECTED."

# 5. Tài xế ấn Reload lần 2 (Không muốn nhận Đơn 2)
Write-Step "5. Driver tiep tuc an Reload lan 2: Bo qua Don #2..."
$offersAfterReload2 = Send-Api POST '/api/v1/drivers/me/offers/refresh' -Token $driverToken -Body @{
    skippedAssignmentIds = @($offer2.assignmentId)
}
if ($offersAfterReload2.Count -eq 0) { throw "Khong tim thay don tiep theo sau khi reload lan 2!" }
$offer3 = $offersAfterReload2[0]

if ($offer3.assignmentId -eq $offer2.assignmentId -or $offer3.assignmentId -eq $offer1.assignmentId) {
    throw "Loi: AssignmentId don 3 bi trung voi don da bo qua!"
}
Write-Pass "Reload lan 2 THANH CONG: Man hinh da cap nhat sang Don #3 moi!"
Write-Info "   Offer 3 Assignment ID: $($offer3.assignmentId)"
Write-Info "   Offer 3 Order ID     : $($offer3.orderId)"

# Kiểm tra trạng thái Offer 2
$checkOffer2 = Send-Api GET "/api/v1/drivers/me/offers/$($offer2.assignmentId)" -Token $driverToken
if ($checkOffer2.status -ne 'REJECTED') {
    throw "Loi: Offer 2 chua duoc ghi nhan la REJECTED (status=$($checkOffer2.status))"
}
Write-Pass "Offer 2 da duoc he thong cap nhat trang thai thanh cong: REJECTED."

# 6. Tài xế đồng ý nhận Đơn #3
Write-Step "6. Driver ung y va bam Nhan Don #3 (Accept Offer)..."
$acceptRes = Send-Api POST "/api/v1/drivers/me/offers/$($offer3.assignmentId)/accept" -Token $driverToken
if ($acceptRes.status -ne 'ACCEPTED') {
    throw "Loi: Trang thai nhan don khong phai ACCEPTED (status=$($acceptRes.status))"
}
Write-Pass "Driver da Nhan Don #3 thanh cong (status=ACCEPTED)."

# 7. Kiểm tra chuyến đi hiện tại
Write-Step "7. Kiem tra Chuyen di hien tai cua Driver..."
$currentTrip = Send-Api GET '/api/v1/drivers/me/deliveries/current' -Token $driverToken
if ($currentTrip.orderId -ne $offer3.orderId) {
    throw "Loi: Chuyen di hien tai khong khop voi Don #3!"
}
if ($currentTrip.status -ne 'ASSIGNED') {
    throw "Loi: Trang thai chuyen di khong phai la ASSIGNED (status=$($currentTrip.status))"
}
Write-Pass "Chuyen di hien tai cua Driver hop le: OrderId=$($currentTrip.orderId), DeliveryId=$($currentTrip.deliveryId), Status=$($currentTrip.status)."

Write-Host "`n=================================================================" -ForegroundColor Green
Write-Host " [HOAN TAT] KICH BAN DRIVER RELOAD QUA CAC DON PENDING DA PASS 100%!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
