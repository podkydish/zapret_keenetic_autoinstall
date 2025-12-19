zapret_keenetic_autoinstall
---------------------------

Автоустановщик zapret на роутер с Entware (тестировалось на Keenetic) + автоматическая настройка скриптов автообновления.

Что делает скрипт
-----------------

- Проверяет наличие Entware и zapret.
- Если zapret не установлен:
  - клонирует репозиторий bol-van/zapret из GitHub;
  - запускает install_bin.sh и install_easy.sh;
  - настраивает автостарт через /opt/etc/init.d/S90-zapret;
  - добавляет netfilter-hook для Keenetic.
- Всегда:
  - создаёт скрипт автообновления списков /opt/zapret/tools/update_lists.sh;
  - создаёт скрипт автообновления zapret /opt/zapret/tools/update_zapret.sh;
  - настраивает cron на ночное обновление.

Требования
----------

- Роутер Keenetic с установленным Entware (OPKG).
- Доступ по SSH к роутеру.
- Точка монтирования Entware: /opt.

Установка
---------

1) Скопируйте файл автоустановки на роутер, например в /opt:

   cd /opt
   # сюда копируете zapret-autoinstall.sh

2) Дайте права на выполнение:

   chmod +x /opt/zapret-autoinstall.sh

3) Запустите скрипт:

   cd /opt
   ./zapret-autoinstall.sh

После выполнения скрипт выведет информацию о том, установлен ли zapret и какие задания автообновления настроены.

Автообновление
--------------

Скрипт создаёт:

- /opt/zapret/tools/update_lists.sh — обновление списков (hostlist) через встроенные get_*.sh в /opt/zapret/ipset.
- /opt/zapret/tools/update_zapret.sh — обновление zapret из GitHub с проверкой наличия новых коммитов.
- cron-задачи в /opt/etc/crontab:

  0  3   *   *   *     /opt/zapret/tools/update_lists.sh   >/opt/var/log/zapret-lists.cron.log 2>&1
  0  3   *   *   1     /opt/zapret/tools/update_zapret.sh  >/opt/var/log/zapret-bin.cron.log   2>&1

Команды управления
------------------

Проверить статус zapret:
  /opt/zapret/init.d/sysv/zapret status

Перезапустить zapret:
  /opt/zapret/init.d/sysv/zapret restart

Вручную обновить списки:
  /opt/zapret/tools/update_lists.sh

Вручную обновить zapret:
  /opt/zapret/tools/update_zapret.sh

Замечания
---------

- Скрипт предназначен для BusyBox sh, сохраняйте его в UTF-8 с переводами строк LF (Unix).
- Запускать нужно от root в окружении Entware (opkg должен быть доступен в PATH).
