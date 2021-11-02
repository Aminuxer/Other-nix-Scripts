# Other-nix-Scripts

Прочие полезные линуксячьи скрипты.

## proxmox_backup_sorter.sh
Есть бэкапы виртуальных машин Proxmox:
```
# ls /mnt/proxmox/dump
vzdump-lxc-100-2019_08_03-03_17_02.log
vzdump-lxc-100-2019_08_03-03_17_02.tar.gz
vzdump-lxc-101-2019_08_03-03_35_23.log
vzdump-lxc-101-2019_08_03-03_35_23.tar.gz
vzdump-qemu-406-2019_08_03-03_38_31.log
vzdump-qemu-406-2019_08_03-03_38_31.tar.gz
```
Рассортируем их по типам и именам виртуалок:

`./proxmox_backup_sorter.sh /mnt/proxmox/dump`

Все файлы будут раскиданы по подкаталогам таким образом:

```
# tree /mnt/proxmox/dump
/mnt/proxmox/dump
├── CT
│    ├── Jabber.Ru
│    │      ├── vzdump-lxc-100-2019_08_03-03_17_02.log
│    │      └── vzdump-lxc-100-2019_08_03-03_17_02.tar.gz
│    └── MyDevJira
│           ├── vzdump-lxc-101-2019_08_03-03_35_23.log
│           └── vzdump-lxc-101-2019_08_03-03_35_23.tar.gz
└── VM
     └── OpenBSD-test
            ├── vzdump-qemu-406-2019_08_03-03_38_31.log
            └── vzdump-qemu-406-2019_08_03-03_38_31.tar.gz
```
Полезно для архивного хранения.
https://aminux.wordpress.com/2017/08/30/proxmox-sort-vzdump-backups/
PS. Не используйте это напрямую в рабочих хранилищах проксмокса - в этом случае бэкапы исчезнут из веб-интерфейса.
Применяйте исключительно для сторонних / архивных бэкапов.


## test-flash-size.sh

Скрипт для очень быстрого определения поддельных китайских USB-флешек.
Некоторые очень дешёвые или сувенирные флешки часто мошеннические - их реальных размер в разы меньше сообщаемого контроллером.
Этот скрипт делает несколько тестов чтения/записи в сектора флешки, прыгая по блокам кратно степеням двойки.
Даже крупные диски проверяются буквально за секунды.

`# ./test-flash-size.sh`

ВАЖНО: Этот скрипт пишет на носитель !! Содержимое секторов будет восстановлено после тестов, однако
нестабильные / глючные флешки могут сломаться. Делайте бэкапы.

Пример вывода скрипта:

```
*** True size checker for USB sticks v. 0.4 [2019-04-12] ***

This script check true device size for detect fraud chinese usb-sticks
!! Need ROOT rights Make BACKUPS !! Can be dangerous !!
!! using WRITE commands to raw-blocks of target disk !! NO WARRANTY !!

Enter target DISK name (ex, sdb):
sdb
BLKiD: /dev/sdb: PTUUID="0203fd1e" PTTYPE="dos"
/dev/sdb1: UUID="e223fef4-736c-4af0-80e2-92254ac09cdf" TYPE="ext4" PARTUUID="0203fd1e-01"

* Reported size: 64 Mb
* Block size: 512 bytes
* Blocks: 131832

Check size 64 Mb, block 131831 ... OK
Check size 32 Mb, block 65915 ... OK
Check size 16 Mb, block 32957 ... OK
Check size 8 Mb, block 16478 ... OK
Check size 4 Mb, block 8239 ... OK
Check size 2 Mb, block 4119 ... OK
Check size 1 Mb, block 2059 ... OK

-----------------------------------
First/top OK mark indicate true size;
If you see FAIL mark, this sector crashed;
Sector data stored in /tmp (testing read/write) and /var/tmp (original data)
```
Первая ОК-запись будет истинным размером.
Запустить тест на смонтированных файловых системах или активных частях RAID/LVM/ZFS не удастся, в скрипте есть проверка.

https://aminux.wordpress.com/2019/04/13/very-fast-usb-flash-size-detect/


## 1cfresh-backup.py

Скрипт для бэкапа облачных баз 1С-фреша (1Cfresh.com)
В начале скрипта правим имя пользователя, пароль и iD аккаунта - используем данные облачного сревиса 1С-фреш.
Логин должен имель роль администратора и разрешение "Запуск и администрирование" для каждой базы, которую надо бэкапить.
Скрипт коннектится к облаку 1С, ищет и скачивает в текущий каталог последний бэкап каждой базы.

Запускать стоит под отдельным пользователем:

```
su - 1cfresh -c "find /home/1cfresh/ -type f -mtime +7 -name '*.zip' -delete"
su - 1cfresh -c "/home/1cfresh/1cfresh-backup.py 2>&1" > 1cfresh-backup.log
tar --gzip -cf home_1cfresh.tgz /home/1cfresh
```

Статейка: https://aminux.wordpress.com/2020/02/28/1cfresh-cloud-backups/

При неверном логине или пароле скрипт выпадет с исключением 'HTTP Error 401: Unauthorized';

Также может встречаться сообщение "<urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: Hostname mismatch, certificate is not valid for 'my_domain_name.local.corp'. (_ssl.c:1076)>"

Это ошибка проверки сертификата, можно поправить в свойствах urllib / ssl, но предпочтительнее сделать нормальные сертификаты от того же Let's Encrypt или развернуть полноценный внутренний PKI/CA в локальной сети.


## totp.py

Очень крохотный питоновский скрипт для генерации одноразовых паролей TOTP (Timebased OneTimePassword)
Можно использовать как холодный бэкап вместо (или вместе) с Google Authenticator тлт иный подобным приложением.
Сконфигурированная версия должна храниться безопасно;
Отредактируйте начало скрипта, заполните по образцу значения в массиве [srv] своими секретами и описаниями;
Запустите скрипт непосредственно перед вводом второго фактора, вы должны увидеть одноразовые коды:

```
$ ./totp.py
  ----- 23 -------------------------------------------------------------------
  349462 | My Proxmox cluster (192.168.0.*)
  560741 | My GitHub (username)
  846956 | Hosting, SSH
```

Коды TOTP валидны только 30 секунд; Если код просрочен, сгенерируйте актуальные повторным запуском.
Это простой и надёжный способ зарезервировать двухфакторные коды.
Используйте крипто-контейнеры:
    https://github.com/Aminuxer/DM-Crypt-Helper-Scripts
для хранения настроенного скрипта !!

Самая первая версия (v1) использовала mintotp и его требовалось ставить отдельно:
`pip3 install mintotp`
Начиная со второй версии (v2) это не нужно, внешних зависимостей нет;

В четвёртой версии (v4) в заголовке таблицы выводится оставшееся время жизни кодов в секундах.


## safety-shred.sh

Позволяет относительно безопасно чистить старые диски на тестовом стенде от старых данных,
проверяя сперва, что диск точно никем не используется.

При очистке старого диска с данными цена опечатки в имени может быть очень высокой.
Данный скрипт проверит, используется ли диск вообще и какая на нём файловая система,
чтобы вы могли это проверить перед зачисткой.

Пример очистки отмонтированного RAID1 с данными:

```# ./safety-shred.sh /dev/md0

----- Controlled SHRED ---------------------
!! ATTENTION !! Device /dev/md0 will be ERASED!
!! Device has filesystem:
  /dev/md0:
LABEL="RAID1-Test"
UUID="7feba672-a008-4328-977c-55bb2d09dc30"
BLOCK_SIZE="1024"
TYPE="ext4"
ALL DATA on storage WILL BE DESTROYED. Continue (Yes/No)? Yes
OK, continue...
Input erase method: Random,Zeros (R/Z/N)? R
dd: ошибка записи '/dev/md0': На устройстве не осталось свободного места
11+0 записей получено
10+0 записей отправлено
42991616 байт (43 MB, 41 MiB) скопирован, 0,512771 s, 83,8 MB/s
ERASE /dev/md0 OK
```

Смонтированные тома, части активных RAID/LVM/ZFS случайно потереть не удастся.
