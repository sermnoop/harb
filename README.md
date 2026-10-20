# Harbor for iOS — نسخة SwiftUI الأصلية

تطبيق **Harbor iOS** مكتوب بالكامل بلغة **Swift** وإطار **SwiftUI (iOS 17+)**، ومبني على معمارية مشروع [Harborofficial/Harbor](https://github.com/Harborofficial/Harbor).

## المزايا المضمنة
1. **تصفح الكتالوج (`Cinemeta` + `TMDB`)**:
   - واجهة رئيسية ببطاقة Hero متحركة، صف أفضل 10 اليوم (Top 10 Today)، وصفوف الأفلام والمسلسلات والأنمي، وقسم متابعة المشاهدة (Continue Watching).
2. **محرك ترتيب البث (`HarborStreamEngine`)**:
   - ترجمة كاملة لمحرك `harbor-core` عبر المراحل الأربع: `Parse -> Trust -> Score -> Rank`.
   - استخراج الدقة (`4K DV`, `4K HDR`, `1080p`, `720p`)، الترميز (`HEVC`, `AV1`, `AVC`)، الصوت (`Dolby Atmos`, `TrueHD`, `5.1`)، وفلترة الروابط غير الموثوقة أو نسخ `CAM`.
3. **التشغيل المباشر عبر `AVPlayer` مع دعم `Real-Debrid` و`TorBox`**:
   - تحويل روابط `infoHash` أو الروابط المستضافة عبر واجهات API الرسمية لـ Real-Debrid وTorBox إلى روابط HTTP/HLS مباشرة تعمل داخل مشغل النظام الأصلي (`AVKit`) مع ميزة تخطي المقدمة (Skip Intro) وتبديل المصدر الفوري داخل المشغل.
4. **غرفة الموسيقى والصوتيات (`HarborMusicRoomView`)**:
   - بحث مباشر عبر كتالوج iTunes، إذاعات بث صوتي مباشر على مدار الساعة، إمكانية إضافة روابط بث صوتي مخصصة (`MP3`/`AAC`/`M3U8`)، ومشغل صوتي عائم يدعم كلمات الأغاني المتزامنة عبر `LRCLIB API`.
5. **غرفة الكتب والمكتبة المفتوحة (`HarborBooksRoomView`)**:
   - ربط مباشر مع `Open Library` ومشروع `Gutenberg (Gutendex API)` لتصفح الكتب وقراءتها داخل قارئ مدمج يدعم تغيير حجم الخط وأنماط القراءة (`Harbor Dark`, `Sepia`, `OLED Night`, `Paper`).
6. **إدارة إضافات Stremio (`HarborAddonsRoomView`)**:
   - تثبيت الإضافات عبر روابط `https://.../manifest.json` أو روابط `stremio://` و`harbor://`.

## طريقة التشغيل في Xcode
- **الطريقة السريعة (ملف واحد)**: أنشئ مشروع iOS App جديد في Xcode (بواجهة SwiftUI) واستبدل ملف الواجهة بملف `HarborIOS.swift`.
- **الطريقة المعيارية (XcodeGen / SwiftPM)**: استخدم حزمة `Harbor-iOS-SwiftUI` التي تحتوي على `Package.swift` و`project.yml` ومجلد `Sources/HarborIOS/`.
