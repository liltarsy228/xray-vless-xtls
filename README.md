##🚀 Xray VLESS + XTLS + Reality в Docker

Готовое решение для развертывания Xray VLESS + XTLS + Reality в Docker с возможностью управления клиентами и экспорта метрик для мониторинга.

📦 Состав решения

По умолчанию разворачиваются два контейнера:

🌐 xray-core (xray-xtls-reality)

Основной контейнер Xray, выполняющий следующие функции:

🌍 прием клиентских подключений по протоколу VLESS + XTLS + Reality;
👤 управление клиентами через утилиту new-xray-client;
🔑 генерация UUID и ссылок подключения;
📝 хранение и применение конфигурации Xray.
Порты
Порт контейнера	Порт хоста	Назначение
883/tcp	443/tcp	Подключение клиентов
5432/tcp	127.0.0.1:5432	PostgreSQL

🔒 PostgreSQL доступен только локально на хосте.

📊 v2ray-exporter

Контейнер для сбора и публикации метрик Xray.

Порты
Порт контейнера	Порт хоста
9550/tcp	127.0.0.1:9550

Метрики доступны по адресу:

http://127.0.0.1:9550/metrics

Поддерживается интеграция с:

📈 Prometheus
📊 Grafana


📋 Требования

Установите необходимые пакеты:

apt update
apt install -y docker.io docker-compose docker-buildx

Проверьте версии Docker:

docker version
docker compose version

📥 Получение исходного кода

Клонируйте репозиторий и исходный код Xray:

git clone https://github.com/liltarsy228/xray-vless-xtls.git

cd xray-vless-xtls

git clone https://github.com/XTLS/Xray-core.git

⚙️ Настройка

Перед запуском откройте файл:

compose.yml

Найдите параметр:

TARGET_SERVER:

и укажите:

🌍 доменное имя сервера, под который будем маскироваться прокси;

🚀 Запуск

Для сборки используется Docker BuildKit.

Запустите контейнеры:

DOCKER_BUILDKIT=1 docker-compose up -d

Проверьте состояние:

docker ps

Ожидаемый результат:

CONTAINER ID   IMAGE             STATUS
xxxxxxxxxxxx   xray-core         Up
xxxxxxxxxxxx   v2ray-exporter    Up


👤 Создание клиента

Подключитесь к контейнеру:

docker exec -it xray-core /bin/sh

Создайте нового клиента:

new-xray-client -n NAME -e email@domain -s server-ip

Пример:

new-xray-client -n user1 -e user1@example.com -s vpn.example.com

После выполнения команды будут выведены:

🆔 UUID клиента;
🔑 SHORTID;
🔗 VLESS-ссылка для подключения.

Сохраните UUID и SHORTID — они понадобятся для настройки Reality.

📝 Добавление клиента в Reality-конфигурацию

Откройте файл конфигурации:

/var/lib/docker/volumes/xray-core-xray-core-settings/_data/config.json
👥 Добавление UUID

Найдите секцию:

"clients": []

Добавьте UUID пользователя:

"clients": [
  {
    "id": "11111111-2222-3333-4444-555555555555"
  }
]
🔑 Добавление SHORTID

Найдите секцию:

"shortIds": []

Добавьте значение SHORTID:

"shortIds": [
  "abcdef12"
]
🔄 Применение изменений

После редактирования конфигурации перезапустите контейнер:

docker restart xray-core

Проверьте статус:

docker ps

📱 Подключение клиента

Ссылка, полученная после выполнения команды:

new-xray-client

импортируется в клиентское приложение.

Поддерживаемые клиенты:

Android
📱 v2rayNG
📱 Hiddify
📱 Happ
iOS
🍏 V2RAY
🍏 V2BOX
🍏 Happ
Windows
🖥️ V2BOX
🖥️ Nekoray
Linux
🐧 Nekoray

После импорта ссылки подключение будет готово к использованию.

📈 Мониторинг

Проверка доступности метрик:

curl http://127.0.0.1:9550/metrics

Открыть в браузере:

http://127.0.0.1:9550/metrics

Пример подключения Prometheus:

scrape_configs:
  - job_name: "xray"
    static_configs:
      - targets:
          - "127.0.0.1:9550"
