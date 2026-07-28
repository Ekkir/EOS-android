# EOS — Android App

## Общее
- Название приложения: **EOS** (в интерфейсе: EOS / SYSTEM)
- Пакет: `com.traffic.app`
- Язык: Kotlin, View-based (AppCompatActivity + Fragments, без Compose)
- Min SDK: совместим с современными Android
- ADB: `M:\sdk\platform-tools\adb.exe`
- Java: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Сборка: `.\gradlew.bat assembleDebug` из `M:\Project vscode\TrafficApp`

## Сервер
- Flask, Ubuntu Linux на MacBook, SSH: `ekkir@192.168.0.15`
- Публичный адрес: `http://eos-traffic.ddns.net:5000` (No-IP DDNS), обновляется через cron каждые 5 мин
- Файл сервера: `~/traffic_server/server.py`; лог: `~/traffic_server/server.log`
- Запуск: `nohup python3 server.py >> server.log 2>&1 &`
- Добавить в автозапуск: `@reboot cd ~/traffic_server && nohup python3 server.py >> server.log 2>&1 &` (crontab)
- Эндпоинты:
  - `GET /lights` — текущие состояния светофоров
  - `POST /reset` — сброс цикла `{road: "pereval"|"abaza"|"zarechka"}`
  - `GET /config` / `POST /config` — тайминги, порядок фаз
  - `GET /messages?since=N` / `POST /messages` — мессенджер
  - `POST /check_admin` — проверка пароля `{password: "..."}` → 200 OK / 403
  - `GET /log` — последние 80 строк server.log в `{log: "..."}`
  - `GET /stats` — `{cpu_usage, mem_used, mem_total, disk_used, disk_total}`

## Разделы приложения
| ID | Иконка | Название | Класс |
|----|--------|----------|-------|
| home | 🏠 | Главная | HomeFragment |
| traffic | 🚦 | Светофоры | TrafficFragment |
| map | 🗺 | Карта | MapFragment |
| cameras | 📷 | Камеры | PlaceholderFragment |
| calib | 🔧 | Настройки | CalibrationFragment |
| — | 💬 | Мессенджер | MessengerFragment (через drawer) |

## Навигация
- **Нижняя панель** (BottomNav): 5 основных разделов
- **Боковой ящик** (DrawerLayout): открывается кнопкой ☰ в шапке; содержит профиль, все разделы, мессенджер
- **Профиль**: открывается по тапу на аватар (верхний левый угол)
- **Мессенджер**: только через drawer, не в bottom nav

## Темы оформления (NeuralApp-стиль)
Файл: `AppTheme.kt`, SharedPrefs ключ: `theme_id`

| ID | Название | Фон | Акцент | isGlass |
|----|----------|-----|--------|---------|
| glass | Glass | #04091C | #56D4FF | true |
| glassneon | Glass+Neon | #030010 | #CC00FF | true |
| neon | Neon | #000000 | #00FFFF | false |
| minimal | Minimal | #0C0C0C | #DDDDDD | false |

- Дефолтная тема: `glass`
- `ThemeDef` содержит: `bg, surface, nav, accent, textPrimary, textSecondary, cardBorder, isGlass`
- `hexAlpha(hex, alpha)` — цвет с прозрачностью
- `cardDrawable(theme, cornerDp, density)` — glass (LayerDrawable) или solid (GradientDrawable)
- `accentBox(theme, density, cornerDp)` — акцентный бокс для иконок

## SharedPreferences
Файл: `traffic_prefs`
- `server_url` — адрес сервера
- `theme_id` — текущая тема
- `profile_name` — имя пользователя
- `cross_{key}_lat/lon` — координаты перекрёстков на карте
- `google_signed_in` — вошли через Google (Boolean)
- `google_name`, `google_email`, `google_photo_url` — данные Google-аккаунта

## Светофоры (RoadMapView)
- Три направления: `pereval` (Перевал), `abaza` (Абаза), `zarechka` (Заречка)
- Viewpoint: с какой дороги едет пользователь
- **Офлайн-режим**: при потере связи таймер продолжает считать по `elapsed()` (секунды с последнего ответа сервера); показывает префикс `~` и баннер "● нет связи — время расчётное"
- Опрос сервера каждые 1 сек (TrafficFragment)

## Мессенджер (MessengerFragment)
- Чат между пользователями приложения
- Опрос `/messages?since=lastId` каждые 2 сек
- Пузыри: свои — справа (accent bg), чужие — слева (surface bg)
- Идентификация по `profile_name` из prefs

## Профиль (ProfileFragment)
- Аватар сохраняется в `filesDir/avatar.jpg`
- Имя сохраняется в `traffic_prefs → profile_name`
- Google Sign-In через `play-services-auth:21.2.0` + Firebase (`google-services.json`)
  - Сохраняет в prefs: `google_signed_in`, `google_name`, `google_email`, `google_photo_url`
  - Имя/фото автоподтягиваются только если поля пустые

## Настройки → Эндминестратор (SettingsFragment / AdminFragment)
- Виден только для `google_email == "razzorenovkiril@gmail.com"`
- При открытии запрашивает пароль через POST `/check_admin`; на 200 — открывает AdminFragment
- AdminFragment: статус сервера, статистика системы (ЦП/ОЗУ/Диск), журнал сервера
- Статистика обновляется автоматически каждые 10 секунд

## Карта (MapFragment)
- OSMDroid (офлайн-тайлы поддерживаются)
- Долгое нажатие → установить перекрёсток
- Кнопки: центровать по GPS, скачать тайлы

## Важные особенности кода
- Фрагменты создаются один раз при старте, потом hide/show (не пересоздаются при переключении вкладок)
- `ProfileFragment` и `MessengerFragment` — через `addToBackStack`, кнопка назад закрывает их
- В `CalibrationFragment`: `renderRoads()` всегда пересоздаёт `redDisplays[key]`; EditText открепляется от старого родителя перед переиспользованием; `handler.post` блоки начинаются с `if (!isAdded) return@post`
- `DrawerLayout` — из `appcompat:1.6.1`, дополнительная зависимость не нужна

## GitHub Release (PowerShell)
- Кириллица в теле запроса через PowerShell 5.1 превращается в вопросики если передавать строку напрямую
- Всегда передавать тело как UTF-8 байты:
  ```powershell
  $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
  Invoke-RestMethod ... -Body $bodyBytes -ContentType "application/json; charset=utf-8"
  ```
- JSON составлять вручную (не через `ConvertTo-Json`) для контроля над экранированием

## Иконка приложения
- Генерируется скриптом: `C:\Users\razzo\AppData\Local\Temp\claude\...\scratchpad\gen_icon.py`
- Источник: `M:\Project vscode\TrafficApp\EOS.png`
- bbox кадрирования: `(40, 128, 576, 472)`
