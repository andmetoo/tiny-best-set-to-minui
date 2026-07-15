# Tiny Best Set GO → NextUI / MinUI

**[Русская инструкция](#русская-инструкция) · [English guide](#english-guide)**

This small Windows PowerShell script takes the **Onion OS version of Tiny Best Set GO** and puts the games, BIOS files, and artwork into the folder layout understood by **NextUI and MinUI**.

It is meant for people who would rather answer two simple questions than manually rename and move a few thousand files.

---

# Русская инструкция

## Что это вообще делает

Tiny Best Set GO подготовлен для Onion OS, поэтому простое копирование на карту NextUI/MinUI оставляет игры в папках с неподходящими именами. Этот скрипт распаковывает сборник и раскладывает всё туда, где система ожидает это найти.

Он переносит:

- игры для NES, SNES, Game Boy, Game Boy Color, Game Boy Advance;
- Mega Drive/Genesis, Master System и Game Gear;
- Atari 2600, PC Engine/TurboGrafx-16 и CD-игры;
- PlayStation и Sega CD;
- Neo Geo и Arcade;
- BIOS из сборника — в папки соответствующих эмуляторов;
- Onion-обложки — в папки `.media`, используемые NextUI;
- понятные названия Arcade/Neo Geo через `map.txt`;
- отдельный Tomb Raider из папки сборника, если он там присутствует.

Оригинальные архивы не удаляются. Скрипт также не форматирует карту.

## NextUI или MinUI?

Подходят оба варианта: NextUI унаследовал структуру `Roms/<название> (ТЕГ)` от MinUI.

Есть несколько нюансов:

- Для **TrimUI Brick** логичнее использовать активно развиваемый NextUI. Оригинальный репозиторий MinUI теперь архивирован, а Brick отмечен там как legacy-устройство.
- В MinUI часть систем появляется только после установки **Extras** или подходящих emulator Paks. Если Pak для тега не установлен, папка с играми может быть на карте, но запускать её будет нечем.
- Оригинальный MinUI не показывает обложки. Папки `.media` ему не мешают — он просто их игнорирует.
- Перед запуском конвертера один раз загрузите NextUI/MinUI на устройстве. На карте должны уже существовать `.system`, `Roms` и `Bios`.

Полезные ссылки:

- [NextUI — последняя версия](https://github.com/LoveRetro/NextUI/releases/latest)
- [Официальная установка NextUI](https://nextui.loveretro.games/getting-started/installation/)
- [MinUI — последняя сохранённая версия](https://github.com/shauninman/MinUI/releases/latest)
- [Pakman: дополнительные Paks для MinUI/NextUI](https://github.com/josegonzalez/pakman/releases/latest)

## Что понадобится

1. Windows 10 или 11.
2. Установленный [7-Zip](https://www.7-zip.org/download.html). Обычно подходит вариант **64-bit Windows x64 `.exe`**.
3. MicroSD с уже установленным и хотя бы один раз запущенным NextUI или MinUI.
4. Полная версия Tiny Best Set GO до 128 ГБ и Onion-варианты обложек.
5. Около **98 ГиБ свободного места** на карте. На обычной карте, продаваемой как 128 GB, после установки NextUI места обычно хватает, но скрипт всё равно проверит это сам.

Страницы сборника:

- [Tiny Best Set GO](https://archive.org/details/tiny-best-set-go)
- [Arcade Update 202305](https://archive.org/details/tiny-best-set-go-arcade-update_202305)

Используйте только те ROM и BIOS-файлы, которыми вы вправе пользоваться. Сам скрипт ничего не скачивает и не содержит игр.

Для полного переноса нужны следующие архивы:

```text
tiny-best-set-go-games.zip
tiny-best-set-go-expansion-64-games.zip
tiny-best-set-go-expansion-128-games.zip
tiny-best-set-go-imgs-onion.zip
tiny-best-set-go-expansion-64-imgs-onion.zip
tiny-best-set-go-expansion-128-imgs-onion.zip
tiny-best-set-go-arcade-names-onion.zip
tiny-best-set-go-arcade-update-onion.zip
tiny-best-set-go-arcade-update-onion-imgs.zip
```

Оставьте их в исходных папках, как на Archive.org:

```text
Tiny best sets\
├── tiny-best-set-go\
│   ├── tiny-best-set-go-games.zip
│   ├── tiny-best-set-go-expansion-64-games.zip
│   ├── tiny-best-set-go-expansion-128-games.zip
│   └── ...
└── tiny-best-set-go-arcade-update_202305\
    ├── tiny-best-set-go-arcade-update-onion.zip
    └── tiny-best-set-go-arcade-update-onion-imgs.zip
```

## Самый простой запуск

### Одна команда в PowerShell

Откройте **PowerShell** через меню «Пуск», вставьте строку целиком и нажмите Enter:

```powershell
$script = Join-Path $env:TEMP 'Convert-TinyBestSetToNextUI.ps1'; Invoke-WebRequest 'https://raw.githubusercontent.com/andmetoo/tiny-best-set-to-minui/master/Convert-TinyBestSetToNextUI.ps1' -OutFile $script; powershell -NoProfile -ExecutionPolicy Bypass -File $script
```

PowerShell скачает актуальную версию скрипта во временную папку и сразу откроет интерактивный мастер. Скрипт сам спросит путь к Tiny Best Set и букву карты памяти.

Если вам спокойнее сначала посмотреть файл, откройте [исходный код скрипта](https://github.com/andmetoo/tiny-best-set-to-minui/blob/master/Convert-TinyBestSetToNextUI.ps1), затем нажмите **Raw** и сохраните его.

### Обычный запуск скачанного файла

1. Скачайте `Convert-TinyBestSetToNextUI.ps1`.
2. Откройте папку со скриптом в Проводнике.
3. Щёлкните в адресной строке Проводника, напишите `powershell` и нажмите Enter.
4. В открывшемся окне выполните:

```powershell
powershell -ExecutionPolicy Bypass -File .\Convert-TinyBestSetToNextUI.ps1
```

Скрипт спросит:

- где находится папка Tiny Best Set;
- какая буква присвоена microSD;
- можно ли начинать перенос.

Для карты можно написать просто `G`, `G:` или `G:\`. Перед началом будет показан максимальный объём копирования. Ничего не записывается до подтверждения.

Перенос почти 100 ГиБ может занять 30–90 минут — это нормально. Не вынимайте карту, пока не появится сообщение `Готово`.

## Запуск с готовыми параметрами

Если не хочется отвечать на вопросы:

```powershell
.\Convert-TinyBestSetToNextUI.ps1 `
  -SourceRoot "D:\Downloads\Tiny best sets" `
  -TargetRoot "G:\"
```

Сначала можно безопасно проверить план без записи:

```powershell
.\Convert-TinyBestSetToNextUI.ps1 `
  -SourceRoot "D:\Downloads\Tiny best sets" `
  -TargetRoot G `
  -DryRun
```

Полезные параметры:

- `-SkipArcade` — не переносить Arcade и Neo Geo;
- `-SkipArtwork` — не переносить обложки;
- `-OverwriteExisting` — заново записывать совпадающие файлы;
- `-NonInteractive -Yes` — запуск для автоматизации без вопросов;
- `-AllowLowSpace` — отключить защиту по свободному месту. Используйте только если точно понимаете последствия.

Без `-OverwriteExisting` обычные совпадающие ROM и обложки пропускаются. Файлы из официального Arcade Update накладываются поверх базовой Arcade-папки, поскольку именно так устроено обновление сборника.

## Что скрипт не делает

- Не устанавливает NextUI/MinUI и не форматирует карту.
- Не переносит сохранения и save states из Onion OS.
- Не переносит cheats, темы и настройки Onion OS.
- Не скачивает ROM, BIOS, эмуляторы или обложки.
- Не распаковывает каждый отдельный игровой ZIP: для обычных картриджных систем ZIP остаётся игровым файлом, и это нормально.
- Не превращает MAME2003+ ROM set в FBNeo ROM set.

Последний пункт важен: Arcade из Tiny Best Set создан для MAME2003+, а NextUI штатно использует FBNeo. Скрипт правильно разложит файлы и названия, но часть аркадных игр может не запуститься. Для полностью совместимой Arcade-библиотеки нужен ROM set, соответствующий версии FBNeo в вашей системе.

## Если что-то пошло не так

**Скрипт не видит карту**  
Сначала загрузите NextUI/MinUI на консоли хотя бы один раз, затем снова вставьте карту в компьютер. В корне должны быть `.system`, `Roms` и `Bios`.

**7-Zip не найден**  
Установите 7-Zip обычным `.exe`-установщиком и заново откройте PowerShell.

**Не хватает места**  
Для полной сборки нужно примерно 98 ГиБ свободного места плюс небольшой запас. Удалите ненужные файлы или возьмите карту большего размера.

**На консоли видны только Tools**  
Проверьте, завершился ли скрипт сообщением `Готово`, и безопасно извлеките карту через Windows. Для MinUI также убедитесь, что установлены Extras/Paks нужных систем.

После каждого запуска рядом со скриптом остаётся текстовый журнал `tiny-best-set-nextui-*.log`. Если возникла ошибка, последние строки этого файла обычно сразу показывают, на чём остановился перенос.

---

# English guide

## What this script actually does

Tiny Best Set GO was prepared for Onion OS, so copying it directly to a NextUI or MinUI card leaves the games in folders with the wrong names. This script unpacks the collection and puts everything where the firmware expects to find it.

It copies:

- NES, SNES, Game Boy, Game Boy Color, and Game Boy Advance games;
- Mega Drive/Genesis, Master System, and Game Gear;
- Atari 2600, PC Engine/TurboGrafx-16, and CD games;
- PlayStation and Sega CD;
- Neo Geo and Arcade;
- included BIOS files into system-specific folders;
- Onion artwork into NextUI's `.media` folders;
- friendly Arcade/Neo Geo titles through `map.txt`;
- the separate Tomb Raider file and artwork when present.

Your original archives are never deleted, and the script does not format the SD card.

## NextUI or MinUI?

Both are supported at the folder-layout level. NextUI inherited MinUI's `Roms/<name> (TAG)` convention.

There are a few practical differences:

- **NextUI is the more natural choice for the TrimUI Brick today.** The original MinUI repository is archived and lists the Brick as a legacy device.
- Some systems in MinUI require **Extras** or matching emulator Paks. A ROM folder can be present but unusable when its Pak is missing.
- Original MinUI does not display box art. The `.media` folders are harmless; MinUI simply ignores them.
- Boot NextUI/MinUI on the handheld once before running the converter. The card should already contain `.system`, `Roms`, and `Bios`.

Useful links:

- [Latest NextUI release](https://github.com/LoveRetro/NextUI/releases/latest)
- [Official NextUI installation guide](https://nextui.loveretro.games/getting-started/installation/)
- [Latest preserved MinUI release](https://github.com/shauninman/MinUI/releases/latest)
- [Pakman: extra Paks for MinUI/NextUI](https://github.com/josegonzalez/pakman/releases/latest)

## What you need

1. Windows 10 or 11.
2. [7-Zip](https://www.7-zip.org/download.html). The **64-bit Windows x64 `.exe`** is right for most PCs.
3. A microSD card with NextUI or MinUI already installed and booted once.
4. The complete 128 GB Tiny Best Set GO package and the Onion artwork archives.
5. Around **98 GiB of free space**. A normally sized 128 GB card usually has enough room after a fresh NextUI install, and the script checks before copying.

Collection pages:

- [Tiny Best Set GO](https://archive.org/details/tiny-best-set-go)
- [Arcade Update 202305](https://archive.org/details/tiny-best-set-go-arcade-update_202305)

Only download and use ROM or BIOS files you have the legal right to use. The script itself downloads nothing and contains no games.

The complete conversion expects these archives:

```text
tiny-best-set-go-games.zip
tiny-best-set-go-expansion-64-games.zip
tiny-best-set-go-expansion-128-games.zip
tiny-best-set-go-imgs-onion.zip
tiny-best-set-go-expansion-64-imgs-onion.zip
tiny-best-set-go-expansion-128-imgs-onion.zip
tiny-best-set-go-arcade-names-onion.zip
tiny-best-set-go-arcade-update-onion.zip
tiny-best-set-go-arcade-update-onion-imgs.zip
```

Keep the original folder layout:

```text
Tiny best sets\
├── tiny-best-set-go\
│   ├── tiny-best-set-go-games.zip
│   ├── tiny-best-set-go-expansion-64-games.zip
│   ├── tiny-best-set-go-expansion-128-games.zip
│   └── ...
└── tiny-best-set-go-arcade-update_202305\
    ├── tiny-best-set-go-arcade-update-onion.zip
    └── tiny-best-set-go-arcade-update-onion-imgs.zip
```

## Easiest way to run it

### One command in PowerShell

Open **PowerShell** from the Start menu, paste the whole line below, and press Enter:

```powershell
$script = Join-Path $env:TEMP 'Convert-TinyBestSetToNextUI.ps1'; Invoke-WebRequest 'https://raw.githubusercontent.com/andmetoo/tiny-best-set-to-minui/master/Convert-TinyBestSetToNextUI.ps1' -OutFile $script; powershell -NoProfile -ExecutionPolicy Bypass -File $script
```

Windows PowerShell downloads the current script to the temporary folder and starts its interactive wizard. The script then asks for the Tiny Best Set folder and the microSD drive letter.

If you prefer to inspect the file first, open the [script source](https://github.com/andmetoo/tiny-best-set-to-minui/blob/master/Convert-TinyBestSetToNextUI.ps1), click **Raw**, and save it.

### Running a downloaded copy

1. Download `Convert-TinyBestSetToNextUI.ps1`.
2. Open its folder in Windows File Explorer.
3. Click the Explorer address bar, type `powershell`, and press Enter.
4. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Convert-TinyBestSetToNextUI.ps1
```

The script asks where Tiny Best Set lives, which drive is the microSD card, and whether it should begin. You may enter `G`, `G:`, or `G:\` for the card.

Copying nearly 100 GiB can take 30–90 minutes. That is normal. Do not remove the card until the script prints `Готово` / `Done`.

## Running it with parameters

```powershell
.\Convert-TinyBestSetToNextUI.ps1 `
  -SourceRoot "D:\Downloads\Tiny best sets" `
  -TargetRoot "G:\"
```

Preview everything without writing to the card:

```powershell
.\Convert-TinyBestSetToNextUI.ps1 `
  -SourceRoot "D:\Downloads\Tiny best sets" `
  -TargetRoot G `
  -DryRun
```

Useful switches:

- `-SkipArcade` — skip Arcade and Neo Geo;
- `-SkipArtwork` — skip box art;
- `-OverwriteExisting` — rewrite matching files;
- `-NonInteractive -Yes` — run from automation without questions;
- `-AllowLowSpace` — bypass the free-space guard. Use this only when you understand the risk.

Without `-OverwriteExisting`, normal matching ROM and artwork files are skipped. Files from the official Arcade Update are applied over the base Arcade folder because that is how the collection update is intended to work.

## What it does not do

- It does not install NextUI/MinUI or format the card.
- It does not migrate Onion OS saves or save states.
- It does not copy Onion themes, cheats, or settings.
- It does not download ROMs, BIOS files, emulators, or artwork.
- It does not unpack every individual game ZIP. Cartridge-system ZIPs remain game files, which is expected.
- It does not convert a MAME2003+ ROM set into an FBNeo ROM set.

That last point matters: Tiny Best Set's Arcade selection targets MAME2003+, while NextUI ships with FBNeo. The script places the files and display names correctly, but some Arcade games may still fail to launch. A fully compatible Arcade library needs a ROM set matching the FBNeo version installed on the handheld.

## If something goes wrong

**The script cannot find the card**  
Boot NextUI/MinUI on the handheld once, then reconnect the card. Its root should contain `.system`, `Roms`, and `Bios`.

**7-Zip was not found**  
Install 7-Zip with the normal `.exe` installer, then open a new PowerShell window.

**There is not enough room**  
The full collection needs roughly 98 GiB plus a small safety margin. Free some space or use a larger card.

**The handheld only shows Tools**  
Make sure the script reached its `Готово` / `Done` message and eject the card safely in Windows. On MinUI, also make sure the required Extras/Paks are installed.

Every run leaves a `tiny-best-set-nextui-*.log` file next to the script. If a copy fails, the last few lines usually tell you exactly where it stopped.
