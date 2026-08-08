# EOS — Flutter App

## Проект
EOS — мини экосистема: чаты, карта событий, камеры, уведомления, профили. Не только светофоры.  
Kotlin-версия (`M:\Project vscode\TrafficApp\`) — только как архив, не трогать.

## Среда разработки
- Flutter: `C:\flutter` (3.44.8, Dart 3.12.2)
- Android SDK: `M:\sdk` (build-tools 34–37, platform android-36)
- NDK: `M:\NDK\android-ndk-r27c`
- Java: OpenJDK 17 (системный)
- Сборка APK: `$env:ANDROID_HOME = "M:\sdk"` перед `flutter build apk --release`

## Ключевые детали
- Package: `com.traffic.app`
- Текущая версия: **1.1.86** (pubspec: `1.1.86+88`; следующий: `1.1.87+89`)
- Admin email: `razzorenovkiril@gmail.com` (в `PrefsService.adminEmail`)

## Серверы и доступы

### GitHub
- Репозиторий: `https://github.com/Ekkir/EOS-android`
- Токен: (хранится локально, не коммитить)
- API заголовки: `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`
- Русский текст в теле запроса: передавать как UTF-8 байты (`[System.Text.Encoding]::UTF8.GetBytes(...)`)

### EOS backend (MacBook Pro, Стокгольм — локальный)
- SSH: `ekkir@192.168.0.15` (без пароля, ключ уже добавлен)
- Подключение: `ssh ekkir@192.168.0.15 "команда"` через Bash tool
- Сервер: `~/traffic_server/server.py`, порт 5000
- Пароль sudo / admin: `889767`
- Перезапуск: `pkill -f 'python3.*server.py'; sleep 1; cd ~/traffic_server && nohup python3 server.py >> server.log 2>&1 &`
- Проверка синтаксиса: `python3 -c 'import py_compile; py_compile.compile("server.py")'`
- Медиафайлы: `~/traffic_server/media/`, avatars: `~/traffic_server/avatars/`
- Сообщения: `~/traffic_server/messages.json.gz` (gzip, последние 2000)

### Stockholm VPN сервер (AmneziaWG)
- IP: `45.137.81.252`
- Логин: `root`, пароль: `wVFpxQk31bae`
- Подключение: через PuTTY plink (Bash SSH не работает с паролем)
  ```powershell
  $plinkPath = "C:\Program Files\PuTTY\plink.exe"
  & $plinkPath -ssh -pw "wVFpxQk31bae" -hostkey "SHA256:K4Vi08Hbnc9veeGUwJnpO6YpzPv1CXpQH94bYmw7DtM" root@45.137.81.252 "команда"
  ```
- Протокол: AmneziaWG (форк WireGuard с обфускацией)
- Контейнеры Docker: `amnezia-awg`, `amnezia-awg2`, `amnezia-dns`
- WireGuard интерфейс внутри контейнера: `docker exec amnezia-awg wg show`
- Конфиг внутри контейнера: `/opt/amnezia/awg/wg0.conf`
- Параметры обфускации: jc=6, jmin=10, jmax=50, s1=70, s2=129, h1-h4 (случайные)
- Стандартный WireGuard клиент НЕ совместим (нужен AmneziaWG клиент)

## Структура
```
lib/
  main.dart                    # Firebase, FCM, Workmanager; currentChatChannelId (глобальная)
                               # Provider: ChangeNotifierProvider(create: (_) => DownloadState())
                               # MaterialApp.builder: Stack([child!, DownloadRingOverlay()])
  theme/app_theme.dart         # liquidglass / neon / minimal + AppThemeNotifier
                               # apply() сохраняет customAccent per-theme в 'accent_$id'; remove при null
  services/
    api_service.dart           # все HTTP-запросы к серверу
    prefs_service.dart         # SharedPreferences обёртка; extends ChangeNotifier
                               # getLastReadId(channelId) / setLastReadId(channelId, id) → 'read_$channelId'
    server_url_resolver.dart   # LAN/WAN автодетект (700ms timeout)
    update_service.dart        # GitHub releases API + скачивание APK (currentVersion)
                               # installApk: PackageInstaller → fallback OpenFile
                               # downloadApk: callback (double progress, int received, int total)
    download_state.dart        # ChangeNotifier: isDownloading, progress, speedMbps, completedPath
                               # startDownload() / onProgress(p, r, t) / complete(path)
  models/
    channel.dart               # isDm, displayName, lastMessageId
  screens/
    home_screen.dart           # Прямоугольные карточки (ListView + BackdropFilter для glass)
                               # Плашка «Чаты» с бейджем непрочитанных (_unreadCount, таймер 10с)
                               # _fetchUnread(): api.getChannels() + prefs.getLastReadId()
                               # Плашка обновления: DraggableScrollableSheet
    messenger_screen.dart      # AppBar: channel.displayName
    chat_list_screen.dart      # FAB → DM; поиск по displayName; hasUnread через lastMessageId
    settings_screen.dart       # BackdropFilter плашки + слабый gradient фон для glass-тем
    cameras_screen.dart        # IP-камеры: SharedPreferences 'ip_cameras' (JSON [{name,url}])
                               # VideoPlayerController.networkUrl для стриминга
    about_screen.dart          # GitHub ссылка; фоновое скачивание через DownloadState
    themes_screen.dart         # выбор темы + цвет акцента (готовые + HEX) + кнопка сброса
    profile_screen.dart        # эффекты аватара: aurora/glitch/disintegration/none
    bug_report_screen.dart     # отчёт об ошибке
    admin_reports_screen.dart  # список отчётов + удаление (только admin)
    user_profile_screen.dart   # при email!=null → прямой поиск профиля; AdminAvatarWidget
    map_screen.dart            # geolocator GPS; _pickingEventLocation режим выбора точки события
  widgets/
    glass_card.dart            # GlassSurface (liquidglass) / glassy (BackdropFilter, gradient 0x22→0x08) / neon / solid
    glass_surface.dart         # BackdropFilter blur 18px; fill: dark=5% white / light=50% white
                               # outer border gradient: dark=38%-6% white; AmbientGlow отдельно
    download_ring.dart         # DownloadRingOverlay: Align topRight, минималистичная дуга без текста
                               # tap → showDialog с GlassCard (прогресс + скорость)
    admin_avatar_widget.dart   # context.watch<PrefsService>() → switch по adminEffect
    circular_avatar.dart       # bytes (Image.memory) или fallback-буква
    aurora_ring.dart           # SweepGradient + pulse animation для аватара admin
    glitch_wrapper.dart        # random offset + ColorFiltered для эффекта глитча
    pixel_disintegration_wrapper.dart  # pixel art дезинтеграция (3s цикл, 38 частиц)
    gradient_progress_bar.dart # горизонтальный прогресс-бар с акцентным градиентом
    road_map_widget.dart
    drawer_widget.dart         # Показывает profileName (ник) а не googleName
                               # «Чаты» (не «Мессенджер»); CamerasScreen в навигации
android/
  app/
    build.gradle.kts           # minSdk=flutter.minSdkVersion, coreLibraryDesugaring=true
    proguard-rules.pro         # keep WorkManager Room-generated classes
    src/main/kotlin/.../MainActivity.kt  # PackageInstaller channel + Media save channel
  gradle.properties            # kotlin.incremental=false, org.gradle.caching=false
```

## При повышении версии — менять в двух местах
1. `pubspec.yaml` → `version: X.X.X+N`
2. `lib/services/update_service.dart` → `currentVersion = 'X.X.X'`

## Релиз на GitHub
1. Поднять версию (см. выше)
2. Собрать: `flutter build apk --release` (с `ANDROID_HOME=M:\sdk`)
3. APK: `build/app/outputs/flutter-apk/app-release.apk`
4. Создать GitHub Release с тегом `vX.X.X`, описание на русском (UTF-8 байты через PowerShell)
5. Прикрепить APK к релизу (`EOS-X.X.X.apk`)

## Сервер (ekkir@192.168.0.15, ~/traffic_server/server.py)
- Маршруты должны быть ДО блока `if __name__ == '__main__':` (иначе не регистрируются!)
- DM имена: `'name': dm_id[3:]` (без префикса `dm_`)
- Маршруты: `/messages DELETE`, `/profile/name/<path:name>`, `/bug_reports CRUD`
- bug_reports.json — персистентное хранение на диске

## Важные особенности
- Workmanager 0.9.x: `ExistingPeriodicWorkPolicy` (не `ExistingWorkPolicy`)
- `coreLibraryDesugaring` нужен для flutter_local_notifications
- ProGuard правила нужны для WorkManager (WorkDatabase_Impl срезается R8)
- Drawer: `Builder` → `Scaffold.of(ctx)` (context должен быть потомком Scaffold)
- edgeToEdge: стиль системных баров выставляется в `EosApp.build()` (main.dart) через `setSystemUIOverlayStyle` с прозрачными цветами и `Brightness.light`; все Scaffold body должны учитывать `MediaQuery.paddingOf(context).bottom` — оборачивать нижний контент в `Padding` или `SafeArea(bottom: true)`
- Тема glassneon переименована в liquidglass (миграция в `load()`)
- Темы: `liquidglass` (isLiquidGlass+glassy), `neon` (neonGlow, accent #39FF14), `minimal`
- `AppThemeNotifier.glowIntensity` (0.3–2.5) — интенсивность неона
- Акцент-цвет: `apply(id, customAccent: c)` → per-theme; `apply(id)` → сброс
- Admin аватар: `AdminAvatarWidget(isAdminAvatar: bool)` — используется везде
- FCM уведомления: пропускаются если `msg.data['channel'] == currentChatChannelId`
- Аватар: getAvatarByEmail (если Google) или getAvatarByName; Drawer перезагружает по ключу email_name_avatarVersion
- Незарегистрированный юзер: имя = `Android ${DeviceInfoPlugin().androidInfo.model}`
- Скачивание обновления: кешировать DownloadState перед await; try/catch вокруг setState
- installApk: сначала PackageInstaller (native channel), при неудаче → OpenFile.open
- DownloadRingOverlay: поверх всех экранов через MaterialApp.builder Stack; показывается только при isDownloading
- Плашки в glass-теме (home/settings): ClipRRect + BackdropFilter(blur 6) + Container(white 4%)
- GlassSurface fill: white 5% (dark) / 50% (light) — не 10%, чтобы не светлело при прокрутке
- ValueKey на `_MessageBubble` по `msg.id` — предотвращает пересоздание при ребилде
- Медиа в чате: `_MediaMessageWidget` StatefulWidget (Future в initState); тап на фото → fullscreen
- Удаление сообщений: долгий тап → «Удалить», `DELETE /messages/$id?channel=$ch`
- GlassCard neon: 4-layer text shadows (blurRadius 36/14/5/2), DefaultTextStyle.merge
- GET /messages возвращает {messages: [...], deleted: [...]}, клиент: named record
- Карты событий: _pickingEventLocation=true при FAB → тап на карте → _showCreateEventDialog(latLng)
- IP-камеры: 'ip_cameras' в SharedPreferences, VideoPlayerController.networkUrl
