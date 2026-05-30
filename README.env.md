# Environment Configuration for accounting Flutter Web

ຟາຍນີ້ສຳລັບບັນທຶກການປ່ຽນແປງ URL ແລະຄ່າສິ່ງເຮັດວຽກແບບ environment variables ສໍາລັບ Flutter web.

## Files created

- `.env` — ເກັບຄ່າຈິງສ້າງແລ້ວ
- `.env.example` — ຕົວຢ່າງຄ່າສໍາລັບ Git
- `lib/env_config.dart` — ຟາຍເພື່ອໂດຍການເຂົ້າຖານຂໍ້ມູນ .env
- `build_web.sh` / `deploy_hosting.sh` — Bash shell scripts
- `build_web.bat` / `deploy_hosting.bat` — Windows batch scripts

## ວິທີການໃຊ້

1. ຄັດລອກ `.env.example` ເປັນ `.env`
2. ປ່ຽນค่า `APP_BASE_URL` ແລະ `API_BASE_URL` ຕາມ domain ຂອງທ່ານ
3. ຮັບປະກັນວ່າ `.env` ບໍ່ໄດ້ຖືກຄັດໃສ່ Git

## ຄຳສັ່ງເພີ່ມເຕີມ

```bash
flutter pub get
```

## ຄຳສັ່ງເກັບ

```bash
bash build_web.sh
bash deploy_hosting.sh
```

## Windows

```bat
build_web.bat
deploy_hosting.bat
```

## ໃນ `lib/main.dart`

ເຊັ່ນກັນນີ້ `EnvConfig.load()` ຈະໂຫຼດໄຟລ `.env` ກ່ອນ Firebase initialize.

## ເວັບໄຊ

`APP_BASE_URL` ຖືກຕັ້ງໄວ້ເພື່ອ Flutter web ທີ່ deployed ລູກຄ້າຈະເຂົ້າເຖິງ.

## ຄ່າ `FLUTTER_WEB_RENDERER`

ຖ້າ Flutter ຂອງທ່ານບໍ່ຮວມສະຫວັນ `--web-renderer`, ຄ່າ `FLUTTER_WEB_RENDERER` ໃນ `.env` ຈະຖືກຂ້າມຜ່ານ ແລະ script ຈະໃຊ້ `flutter build web --release` ເທົ່ານັ້ນ.
