# Telefonchiki / Walker Runner — статус и инструкция (хендофф)

> Handoff-док для быстрого возврата в проект в новой сессии. **Секреты здесь НЕ хранятся** (репо публичный) — пароли/логины/токены в: `~/Desktop/projects.yaml`, `~/Desktop/tokens.yaml`, и памяти Claude `project_vmos_proxy.md` / `project-walker`.

Обновлено: 2026-07-01.

## Цель
Генерировать **уникальные резидентные визиты** на наши WP-сайты (учитываются в Яндекс.Метрике, низкая роботность), дешевле SMM-панелей. «Телефончики» = раннер на десктопе/VPS, который реальным браузером открывает сайты через резидентный прокси.

## Архитектура (как есть сейчас)
```
Aeza Windows VPS (раннер)
   -> gost локальный форвардер 127.0.0.1:900X (без авторизации)
      -> ASocks резидентный прокси (с авторизацией, ротация IP)
         -> сайт с UTM (utm_campaign=traffic_jun2026&utm_source=telefon)
Раннер берёт задачи с НАШЕГО walker: walker.vtrworks.com (=167.233.197.194, Coolify)
Замер: Яндекс.Метрика (визиты/уники/роботность) + ASocks (трафик/$)
```

## Компоненты и где что
| Что | Где | Доступ |
|---|---|---|
| **Раннер (код)** | локально `~/Desktop/standalone-windows 2` (PowerShell+CDP, Windows-only) | — |
| **Раннер (релизы, авто-апдейт)** | GitHub `viktoriyatechlead-ship-it/walker-releases` (этот репо): `version.json` + `runner.zip` (код) + `runner-full.zip` (код+конфиги) | gh (аккаунт viktoriyatechlead-ship-it) |
| **Раннер (на сервере)** | Aeza VPS, `C:\Users\Administrator\Desktop\standalone-windows`, авто-обновляется | RDP (см. projects.yaml) |
| **Walker (БОЕВОЙ, наш)** | `walker.vtrworks.com` = 167.233.197.194, в Coolify | SSH coolify_key + БД контейнер `gw7zk02...` + Coolify API-токен (tokens.yaml) |
| **Walker (чужой, НЕ юзаем)** | 80.249.147.84:8010 — НЕ наш, нет доступа, засорён | — |
| **Прокси** | ASocks (my.asocks.com), 2 резидентных RU-прокси, $3/ГБ | tokens.yaml |
| **Короткая ссылка на раннер** | polr.8k0.ru/runner (=runner-full.zip) | — |

## Раннер — как работает
- `launch.ps1` при старте: **само-обновление** (проверяет version.json тут, качает runner.zip, накатывает, перезапускается; configs/state сохраняет). Не-фатальный транскрипт.
- `run.ps1`: цикл задач. Прокси: читает `config.proxy` (host/port/login/pass); если есть `gost.exe` — качает его (если нет) и поднимает `gost -L=http://127.0.0.1:900X -F=http://LOGIN:PASS@HOST:PORT`, браузер идёт на localhost без авторизации (нет диалога прокси). Иначе — прямой прокси + CDP-авторизация (ненадёжно).
- `lib/Browser.ps1`: запуск Edge/Chrome, фикс CDP (освобождение порта, чистка Singleton-локов), `--blink-settings=imagesEnabled=false` (экономия трафика 4-5×), `--mute-audio`.
- `lib/Cdp.ps1`: `Clear-WebState` (чистит cookies+cache+localStorage ПЕРЕД каждым визитом), `Set-CdpStealth` (стелс: navigator.webdriver=undefined, маскировка chrome/plugins/permissions, рандомизация canvas/WebGL/cores/mem на каждый визит через Page.addScriptToEvaluateOnNewDocument).
- Запуск на сервере: `START-VISIBLE.bat` (worker1, видимое окно) или `start.bat` (2 воркера). `config.worker1/2.json` → `apiBaseUrl=http://walker.vtrworks.com`, `deviceType=desktop`, блок `proxy` с ASocks-кредами (только на сервере, НЕ в публичном архиве).

### Выпуск нового релиза
Правишь код в `~/Desktop/standalone-windows 2` → bump `version.txt` → пересобрать `runner.zip`/`runner-full.zip` (исключая state/output/configs/gost.exe/*.log) + `version.json` (version, zipUrl, sha256) → закоммитить в этот репо и push. **НЕ класть бинари >5МБ** (gost.exe) в репо — push падает HTTP 400; gost качается на сервере сам.

## Walker (наш, 167.233) — задачи
- Создавать задачи: `POST http://walker.vtrworks.com/task/add` (открытый API), payload: type=open_url, url, open_method=web_view, repeat, visit_min/max, pause_min/max, allow_clicks, device_click_limit=10000, is_active=true, **device_type=telefon**, БЕЗ geo_code.
- **КРИТИЧНО (иначе getTask не отдаёт задачи раннеру):**
  - `device_type` задачи должен быть **telefon** (устройство регистрируется telefon по умолчанию; getTask матчит по СОХРАНЁННОМУ типу устройства).
  - `geo_id=NULL` у задач (иначе forGeo отсекает — устройство без гео).
  - Прокси в API выключен: `UPDATE proxy_settings SET is_enabled=false` (чтобы раннер юзал наш статик-gost, а не мёртвый Squid 167.233:3128).
- БД: контейнер `gw7zk02...`, `psql -U postgres -d postgres`. Таблицы: tasks, devices, task_events. Прогресс визитов: `repeat_left` падает + событие `complete`. Пропускная: по таймстемпам task_events.

## Windows Defender
Defender метит `gost.exe` хактулом и удаляет → форвардер не поднимается. На сервере один раз:
`Set-MpPreference -DisableRealtimeMonitoring $true` + `Add-MpPreference -ExclusionPath <папка раннера>` + `-ExclusionPath $env:TEMP`.

## Замер (для отчёта)
- **ЯМ** (MCP yandex-metrika): визиты/уники/**роботность** по `ym:s:UTMCampaign=='traffic_jun2026'` (или UTMSource=telefon), по каждому счётчику сайта. Метрика роботности: `ym:s:robotPercentage` (только метрика, не измерение).
- **ASocks**: панель → расход трафика/$ по прокси.
- Счётчики ЯМ сайтов — в памяти project-walker.

## Статус (2026-07-01)
- ✅ Инфраструктура построена и РАБОТАЕТ end-to-end: VPS → раннер → gost → резидентный прокси → визит **засчитан в ЯМ**.
- ✅ Ключевой факт: **резидентный прокси необходим** — датацентр-IP (прямой) ЯМ фильтрует, 0 визитов; через резидент визит считается.
- ✅ Блокеры закрыты: авторизация прокси (gost + Defender off), очередь (переключились на наш walker 167.233).
- ⚠️ **Открыто: роботность.** Первый визит был 100% робот. Добавлен стелс (1.0.8). **Надо: перезапустить раннер на 1.0.8, дать покрутиться, снять роботность по 7 сайтам, сравнить со 100% и с SMM-панелями (naizop/smmstone 17-54%).**
- Активные задачи: 7 малых сайтов (kakoybank, bankrecommend, kakoydevays, devicerecommend, kudaotpusk, kudarecommend, easyvacation). justlady/new.justlady убраны (нет ЯМ-счётчиков).

## Следующие шаги
1. Замерить роботность на визитах со стелсом (1.0.8).
2. Если высокая — добавить **многостраничность** (2–4 внутренние ссылки за визит) + движения мыши + разное время.
3. Настроить автозапуск раннера 24/7 (автологин + startup).
4. Масштаб: +VPS/десктопы = +потоки (юнит-экономика ~$0.86/1000 при 300КБ/визит).
5. Свести замер в отчёт (презентация `~/Desktop/Веб_30_июнь_2026.pptx`, слайды телефончиков).
