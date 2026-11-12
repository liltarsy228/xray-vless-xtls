#!/bin/bash

# ============================================================
# FIRSTART.SH — первоначальная настройка Linux-сервера
# Запуск: sudo bash firstart.sh
# ============================================================

set -Eeuo pipefail

# ============================================================
# НАСТРОЙКА ЛОГИРОВАНИЯ
# ============================================================

# Файл для записи лога выполнения скрипта
LOG_FILE="/tmp/first-sh-log"

# Перенаправляем стандартный вывод и ошибки одновременно
# в терминал и файл лога.
exec > >(tee -a "$LOG_FILE") 2>&1

# Записываем дату и время начала выполнения
echo "================================================"
echo "Script started: $(date)"
echo "================================================"

# ============================================================
# ПЕРЕМЕННЫЕ
# ============================================================

# Имя создаваемого пользователя
USERNAME="user"

# Пароль пользователя
USER_PASSWORD='user'

# Новый SSH-порт
SSH_PORT="123"

# Публичный SSH-ключ для подключения пользователя
SSH_PUBLIC_KEY="pbkey"

# URL Git-репозитория
REPO_URL="https://github.com/liltarsy228/xray-vless-xtls.git"

# ============================================================
# ПРОВЕРКА ПРАВ ROOT
# ============================================================

# Проверяем, что скрипт запущен от имени суперпользователя
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

echo "Starting server configuration..."

# ============================================================
# 1. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ И НАСТРОЙКА SUDO
# ============================================================

echo "[1/5] Creating user..."

# Проверяем наличие пользователя в системе
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists."
else
    # Создаём пользователя с домашним каталогом и оболочкой Bash
    useradd -m -s /bin/bash "$USERNAME"
fi

# Устанавливаем пароль пользователя
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Определяем административную группу в зависимости от дистрибутива
if getent group sudo >/dev/null; then
    SUDO_GROUP="sudo"
elif getent group wheel >/dev/null; then
    SUDO_GROUP="wheel"
else
    echo "ERROR: sudo or wheel group not found."
    exit 1
fi

# Добавляем пользователя в административную группу
usermod -aG "$SUDO_GROUP" "$USERNAME"

echo "User $USERNAME configured."

# ============================================================
# 2. НАСТРОЙКА SSH
# ============================================================

echo "[2/5] Configuring SSH..."

# Указываем путь к основному конфигурационному файлу SSH
SSHD_CONFIG="/etc/ssh/sshd_config"

# Указываем путь к каталогу SSH пользователя
SSH_DIR="/home/$USERNAME/.ssh"

# Указываем путь к файлу авторизованных ключей
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Проверяем наличие конфигурационного файла SSH
if [[ ! -f "$SSHD_CONFIG" ]]; then
    echo "ERROR: SSH configuration file not found."
    exit 1
fi

# Создаём резервную копию конфигурации с текущей датой и временем
BACKUP="${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp -a "$SSHD_CONFIG" "$BACKUP"

echo "SSH backup created: $BACKUP"

if grep -Eq '^[[:space:]]*#?[[:space:]]*Port[[:space:]]+' "$SSHD_CONFIG"; then
    sed -i 's/^[[:space:]]*#\{0,1\}[[:space:]]*Port[[:space:]].*/Port 4224/' "$SSHD_CONFIG"
else
    echo "Port 4224" >> "$SSHD_CONFIG"
fi

# Включаем авторизацию по SSH-ключам
if grep -Eq '^[[:space:]]*#?[[:space:]]*PubkeyAuthentication[[:space:]]+' "$SSHD_CONFIG"; then
    sed -i 's/^[[:space:]]*#\{0,1\}[[:space:]]*PubkeyAuthentication[[:space:]].*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
else
    echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
fi

# Явно оставляем возможность входа по паролю
if grep -Eq '^[[:space:]]*#?[[:space:]]*PasswordAuthentication[[:space:]]+' "$SSHD_CONFIG"; then
    sed -i 's/^[[:space:]]*#\{0,1\}[[:space:]]*PasswordAuthentication[[:space:]].*/PasswordAuthentication yes/' "$SSHD_CONFIG"
else
    echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
fi

# Создаём каталог .ssh в домашнем каталоге пользователя
mkdir -p "$SSH_DIR"

# Устанавливаем права доступа к каталогу .ssh
chmod 700 "$SSH_DIR"

# Создаём файл authorized_keys, если он отсутствует
touch "$AUTHORIZED_KEYS"

# Проверяем, добавлен ли публичный ключ ранее
if ! grep -qxF "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
    # Добавляем публичный ключ в список разрешённых ключей
    echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
fi

# Устанавливаем права доступа к файлу authorized_keys
chmod 600 "$AUTHORIZED_KEYS"

# Назначаем пользователя владельцем каталога .ssh и его содержимого
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# Проверяем корректность конфигурации SSH
if sshd -t; then
    echo "SSH configuration is valid."
else
    # Восстанавливаем исходную конфигурацию при обнаружении ошибки
    echo "ERROR: Invalid SSH configuration. Restoring backup."
    cp -a "$BACKUP" "$SSHD_CONFIG"
    exit 1
fi

# Перезапускаем службу SSH с учётом названия в дистрибутиве
if systemctl restart sshd 2>/dev/null; then
    echo "SSH service restarted."
elif systemctl restart ssh 2>/dev/null; then
    echo "SSH service restarted."
else
    echo "ERROR: Unable to restart SSH service."
    exit 1
fi

echo "SSH configured on port $SSH_PORT."

# ============================================================
# 3. УСТАНОВКА GIT
# ============================================================

echo "[3/5] Checking Git installation..."

# Проверяем наличие исполняемого файла Git
if ! command -v git &>/dev/null; then

    # Устанавливаем Git в Debian, Ubuntu и Astra Linux
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y git

    # Устанавливаем Git в RedOS, RHEL и Fedora
    elif command -v dnf &>/dev/null; then
        dnf install -y git

    # Устанавливаем Git в старых RHEL-подобных системах
    elif command -v yum &>/dev/null; then
        yum install -y git

    # Устанавливаем Git в SUSE Linux
    elif command -v zypper &>/dev/null; then
        zypper --non-interactive install git

    else
        echo "ERROR: Unsupported package manager."
        exit 1
    fi

else
    echo "Git is already installed."
fi

# ============================================================
# 4. ЗАГРУЗКА РЕПОЗИТОРИЯ И ЗАПУСК KNOCK.SH для 1 инициализации правил фаервола
# ============================================================

echo "[4/5] Cloning repository..."

# Получаем название репозитория из URL
REPO_NAME=$(basename "${REPO_URL%/}")

# Удаляем расширение .git из названия репозитория
REPO_NAME="${REPO_NAME%.git}"

# Определяем каталог для размещения репозитория
REPO_DIR="/opt/$REPO_NAME"

# Проверяем, существует ли репозиторий в /opt
if [[ -d "$REPO_DIR/.git" ]]; then

    # Обновляем существующий репозиторий
    echo "Repository already exists. Pulling updates..."
    git -C "$REPO_DIR" pull

else

    # Клонируем репозиторий в каталог /opt
    git clone "$REPO_URL" "$REPO_DIR"

fi

# Переходим в каталог загруженного репозитория
cd "$REPO_DIR"

# Проверяем наличие скрипта knock.sh
if [[ ! -f "./knock.sh" ]]; then
    echo "ERROR: knock.sh not found in repository."
    exit 1
fi

# Добавляем право на исполнение скрипта knock.sh
chmod +x ./knock.sh

# Запускаем knock.sh от имени root
echo "Executing knock.sh..."
./knock.sh

# ============================================================
# 5. НАСТРОЙКА IPSET SERVICE для постоянных правил фаервола
# ============================================================

echo "[5/5] Configuring ipset service..."

# Проверяем наличие утилиты ipset
if ! command -v ipset &>/dev/null; then

    # Устанавливаем ipset в Debian, Ubuntu и Astra Linux
    if command -v apt-get &>/dev/null; then
        apt-get update
        apt-get install -y ipset

    # Устанавливаем ipset в RedOS, RHEL и Fedora
    elif command -v dnf &>/dev/null; then
        dnf install -y ipset

    elif command -v yum &>/dev/null; then
        yum install -y ipset

    else
        echo "ERROR: Cannot install ipset."
        exit 1
    fi
fi

# Перемещаем systemd unit в каталог служб
mv "$REPO_DIR/ipset.service" /etc/systemd/system/ipset.service

# Перемещаем скрипт инициализации в /usr/local/bin
mv "$REPO_DIR/ipset-init.sh" /usr/local/bin/ipset-init.sh

# Делаем скрипт инициализации исполняемым
chmod 755 /usr/local/bin/ipset-init.sh

# Перечитываем конфигурации systemd
systemctl daemon-reload

# Добавляем службу в автозагрузку и запускаем её
systemctl enable --now ipset.service

# Проверяем состояние службы
systemctl status ipset.service --no-pager

echo "ipset service configured successfully."

# ============================================================
# ЗАВЕРШЕНИЕ
# ============================================================

echo ""
echo "============================================"
echo "SERVER CONFIGURATION COMPLETED"
echo "============================================"
echo "User:       $USERNAME"
echo "SSH port:   $SSH_PORT"
echo "SSH key:    configured"
echo "Git:        installed"
echo "Repository: $REPO_DIR"
echo "knock.sh:   executed"
echo "============================================"
