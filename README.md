# zapret_keenetic_autoinstall

Установщик zapret на роутер с entware (тесты только на keenetic) + задание правил автообновления
Инструкция:
1) скачать файл автоустановки, разместить в файловой системе роутера
2) дать права на выполнение chmod +x /opt/zapret-autoinstall.sh
3) запустить скрипт ./zapret_install.sh
Команды управления:
1) Проверить статус zapret: /opt/zapret/init.d/sysv/zapret status
2) Перезапустить zapret:    /opt/zapret/init.d/sysv/zapret restart
3) Обновить вручную список: /opt/zapret/tools/update_lists.sh
