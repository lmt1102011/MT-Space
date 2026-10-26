# Thiết lập phát hành cập nhật Android trong ứng dụng

Mỗi bản phát hành Android phải được ký bằng cùng một keystore phát hành.
Không đưa keystore hoặc mật khẩu vào mã nguồn hay commit lên Git. Các lệnh
dưới đây chạy trong PowerShell trên Windows.

1. Đảm bảo máy đã có JDK. Nếu bạn cài Android Studio, có thể dùng `keytool`
   đi kèm Android Studio. Chạy:

   ```powershell
   $keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
   Test-Path $keytool
   ```

   Nếu kết quả là `True`, tạo keystore và lưu một bản sao lưu an toàn:

   ```powershell
   & $keytool -genkeypair -v -keystore ".\mt-space-release.keystore" -alias mtspace -keyalg RSA -keysize 2048 -validity 10000
   ```

   Nếu kết quả là `False`, bạn có thể cài JDK 17 bằng lệnh:

   ```powershell
   winget install --id EclipseAdoptium.Temurin.17.JDK -e
   ```

   Sau khi cài, đóng rồi mở lại PowerShell và chạy `keytool -genkeypair ...`.
   Nếu lệnh vẫn chưa được nhận diện, dùng đường dẫn đầy đủ đến `keytool.exe`,
   thường nằm trong thư mục `bin` của JDK. Nếu cài Android Studio ở vị trí
   khác, sửa `$keytool` cho đúng đường dẫn `jbr\bin\keytool.exe` của bạn.

   Khi được hỏi, hãy dùng cùng một mật khẩu cho keystore và alias.
2. Chuyển tệp keystore sang Base64. Lệnh sau chép chuỗi vào clipboard, không
   in nội dung nhạy cảm ra màn hình:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\mt-space-release.keystore")) | Set-Clipboard
   ```

3. Thêm các Actions secrets sau cho repository tại **Settings → Secrets and
   variables → Actions**:
   - `ANDROID_KEYSTORE_BASE64`: dán chuỗi Base64 vừa được chép vào clipboard.
   - `ANDROID_KEYSTORE_PASSWORD`: mật khẩu keystore/alias.
   - `ANDROID_KEY_ALIAS`: `mtspace` (hoặc alias bạn đã chọn ở bước 1).

Nếu thiếu bất kỳ secret nào, workflow sẽ dừng trước khi phát hành; workflow
không dùng khóa debug thay đổi theo mỗi lần build để thay thế. Không thể dùng
keystore mới này để cập nhật cài đè APK đã ký bằng khóa cũ. Người dùng đang dùng
các bản đó sẽ phải gỡ ứng dụng một lần rồi cài APK đầu tiên được ký bằng
keystore mới này. Hãy sao lưu keystore cẩn thận: nếu mất keystore, các bản sau
sẽ không thể cập nhật cài đè.
