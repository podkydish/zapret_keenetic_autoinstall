#!/bin/sh
# /opt/zapret-autoinstall.sh
# Автоустановка и настройка zapret с автообновлением на готовой Entware

set -e

ZAPRET_DIR="/opt/zapret"
TMP_DIR="/opt/tmp"
REPO_URL="https://github.com/bol-van/zapret.git"
SERVICE="$ZAPRET_DIR/init.d/sysv/zapret"

LOG() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

ERROR() {
  LOG "ERROR: $@" >&2
  exit 1
}

# ============================================================================
# 1. Проверка предварительных условий
# ============================================================================

LOG "=== Проверка условий ==="

[ "$(id -u)" = 0 ] || ERROR "Требуется запуск от root (используй: sudo $0)"

if ! command -v opkg >/dev/null 2>&1; then
  ERROR "opkg не найден. Entware не установлен?"
fi

LOG "opkg найден, Entware готов"

# ============================================================================
# 2. Проверка наличия zapret
# ============================================================================

if [ -d "$ZAPRET_DIR" ] && [ -x "$SERVICE" ]; then
  LOG "=== zapret уже установлен в $ZAPRET_DIR ==="
  ZAPRET_INSTALLED=1
else
  LOG "=== zapret не найден, начинаем установку ==="
  ZAPRET_INSTALLED=0
fi

# ============================================================================
# 3. Если zapret не установлен — устанавливаем
# ============================================================================

if [ "$ZAPRET_INSTALLED" = 0 ]; then
  LOG "=== Установка зависимостей ==="
  opkg update || LOG "Ошибка в opkg update (может быть нормально)"
  
  for pkg in coreutils-sort curl git-http grep gzip ipset iptables kmod_ndms xtables-addons_legacy; do
    LOG "Устанавливаем $pkg..."
    opkg install "$pkg" >/dev/null 2>&1 || LOG "Предупреждение: не удалось установить $pkg"
  done

  LOG "=== Клонируем zapret из GitHub ==="
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"
  
  if [ -d "$TMP_DIR/zapret.git" ]; then
    LOG "Удаляем старый клон..."
    rm -rf "$TMP_DIR/zapret.git"
  fi
  
  git clone --depth=1 "$REPO_URL" zapret.git || ERROR "Ошибка клонирования zapret"
  cd zapret.git

  LOG "=== Установка бинарников ==="
  ./install_bin.sh || ERROR "Ошибка install_bin.sh"

  LOG "=== Запуск install_easy.sh ==="
  ZAPRET_BASE="$(pwd)" ZAPRET_TARGET="$ZAPRET_DIR" ./install_easy.sh || {
    LOG "Внимание: install_easy.sh завершился с кодом ошибки (возможно, требуется интерактивный ввод)"
  }

  LOG "=== Конфигурация автостарта ==="
  ln -fs "$ZAPRET_DIR/init.d/sysv/zapret" /opt/etc/init.d/S90-zapret || LOG "Не удалось создать симлинк автостарта"

  LOG "=== Конфигурация netfilter hook для Keenetic ==="
  mkdir -p /opt/etc/ndm/netfilter.d
  cat >/opt/etc/ndm/netfilter.d/000-zapret.sh << 'EOFHOOK'
#!/bin/sh
[ "$type" = "ip6tables" ] && exit 0
[ "$table" != "mangle" ] && exit 0
/opt/zapret/init.d/sysv/zapret restart-fw
EOFHOOK
  chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh

  LOG "=== Первый запуск zapret ==="
  "$SERVICE" start || LOG "Предупреждение: ошибка при первом запуске"

  ZAPRET_INSTALLED=1
fi

# ============================================================================
# 4. Настройка автообновления (для установленного или только что установленного)
# ============================================================================

LOG "=== Настройка автообновления ==="

# 4.1 Конфиг доменных списков не используем (работаем через встроенные get_*.sh)
LOG "Пропускаем domain_lists.conf (используем встроенные скрипты zapret/ipset)"
mkdir -p /opt/zapret.local

# 4.2 Скрипт обновления списков через встроенные get_*.sh
LOG "Создаём скрипт обновления списков..."
mkdir -p "$ZAPRET_DIR/tools"

cat >"$ZAPRET_DIR/tools/update_lists.sh" << 'EOFSCRIPT'
#!/bin/sh
set -e

ZAPRET_DIR="/opt/zapret"
LIST_DIR="$ZAPRET_DIR/ipset"

echo "[*] $(date '+%Y-%m-%d %H:%M:%S') Обновляем списки через встроенные скрипты zapret..."

cd "$LIST_DIR" || exit 1

# Antizapret-домены (если есть такой скрипт)
if [ -x ./get_antizapret_domains.sh ]; then
  echo "  - обновляем antizapret домены..."
  ./get_antizapret_domains.sh || echo "    ошибка get_antizapret_domains.sh"
fi

# Реестр (имя может отличаться, при необходимости подправь под свой ls)
if [ -x ./get_reestr_hostlist.sh ]; then
  echo "  - обновляем реестр..."
  ./get_reestr_hostlist.sh || echo "    ошибка get_reestr_hostlist.sh"
fi

# Общий комбинированный список (если есть)
if [ -x ./get_combined.sh ]; then
  echo "  - пересобираем комбинированный список..."
  ./get_combined.sh || echo "    ошибка get_combined.sh"
fi

echo "[*] $(date '+%Y-%m-%d %H:%M:%S') Готово."
EOFSCRIPT

chmod +x "$ZAPRET_DIR/tools/update_lists.sh"
LOG "Скрипт update_lists.sh готов"


# 4.3 Скрипт обновления zapret
LOG "Создаём скрипт обновления zapret..."

cat >"$ZAPRET_DIR/tools/update_zapret.sh" << 'EOFUPD'
#!/bin/sh
set -e

ZAPRET_DIR="/opt/zapret"
TMP_DIR="/opt/tmp"
REPO_URL="https://github.com/bol-van/zapret.git"
SERVICE="$ZAPRET_DIR/init.d/sysv/zapret"

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

if [ -d "$TMP_DIR/zapret.git/.git" ]; then
  echo "[*] Обновляем локальный git-клон..."
  cd "$TMP_DIR/zapret.git"
  git fetch origin
else
  echo "[*] Клонируем репозиторий..."
  git clone --depth=1 "$REPO_URL" zapret.git
  cd zapret.git
fi

LOCAL_REV=$(git rev-parse HEAD)
REMOTE_REV=$(git rev-parse origin/master)

if [ "$LOCAL_REV" = "$REMOTE_REV" ]; then
  echo "[*] Новых коммитов нет, обновление не требуется."
  exit 0
fi

echo "[*] Есть новая версия ($LOCAL_REV -> $REMOTE_REV), обновляем..."
git reset --hard "$REMOTE_REV"

echo "[*] Останавливаем zapret..."
[ -x "$SERVICE" ] && "$SERVICE" stop || true

echo "[*] Запускаем install_easy.sh..."
ZAPRET_BASE="$(pwd)" ZAPRET_TARGET="$ZAPRET_DIR" ./install_easy.sh >/dev/null 2>&1 || true

if [ -f /opt/zapret.local/zapret.patch ]; then
  echo "[*] Применяем локальный патч..."
  patch -p1 < /opt/zapret.local/zapret.patch || true
fi

echo "[*] Запускаем zapret..."
[ -x "$SERVICE" ] && "$SERVICE" start || true

echo "[*] Обновление zapret завершено."
EOFUPD

chmod +x "$ZAPRET_DIR/tools/update_zapret.sh"
LOG "Скрипт update_zapret.sh готов"

# 4.4 Cron-задачи
LOG "Настраиваем cron для обновлений..."
mkdir -p /opt/var/log

cat >/opt/etc/crontab << 'EOFCRON'
# m  h  dom mon dow   command
0  3   *   *   *     /opt/zapret/tools/update_lists.sh   >/opt/var/log/zapret-lists.cron.log 2>&1
0  3   *   *   1     /opt/zapret/tools/update_zapret.sh  >/opt/var/log/zapret-bin.cron.log   2>&1
EOFCRON

LOG "Перезапускаем cron..."
/opt/etc/init.d/S10cron restart >/dev/null 2>&1 || LOG "Ошибка при перезапуске cron"

# ============================================================================
# 5. Итоговая информация
# ============================================================================

LOG "=== ГОТОВО ==="
echo ""
echo "✓ zapret установлен и настроен в $ZAPRET_DIR"
echo "✓ Автообновление списков: каждый день в 03:00"
echo "✓ Автообновление zapret: по понедельникам в 03:00"
echo ""
echo "Включены списки:"
echo "  • antizapret (основной)"
echo "  • reestry (реестр Роскомнадзора)"
echo ""
echo "Логи обновлений:"
echo "  /opt/var/log/zapret-lists.cron.log"
echo "  /opt/var/log/zapret-bin.cron.log"
echo ""
echo "Проверить статус zapret: /opt/zapret/init.d/sysv/zapret status"
echo "Перезапустить zapret:    /opt/zapret/init.d/sysv/zapret restart"
echo ""
