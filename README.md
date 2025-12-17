# OpenVPN Server (in Docker) v2

Репозиторий содержит набор конфигураций и shell-скриптов для развёртывания и администрирования OpenVPN-сервера в Docker.


---

## Назначение

Проект решает следующие задачи:

* развёртывание OpenVPN-сервера через Docker
* инициализация PKI (CA, серверный сертификат, CRL)
* добавление и отзыв клиентских сертификатов
* генерация клиентских `.ovpn` конфигураций

Проект **не является** готовым SaaS-решением, панелью управления или «one-click VPN».

---

## Требования

### Общее

* Docker
* Docker Compose
* Bash (Linux / WSL)

### Linux

Поддерживаемые сценарии:

* локальная машина
* VPS / выделенный сервер

### Windows

Поддерживается через:

* Docker Desktop
* WSL2 (Ubuntu / Debian)

Запуск `.sh`-скриптов осуществляется **из WSL**, не из PowerShell или cmd.exe.

---

## Структура проекта

```text
openvpn-server/
├── in-docker/                  # всё, что копируется в контейнер
│   ├── scripts/
│   │   ├── init-pki.sh
│   │   ├── gen-server.sh
│   │   ├── add-client.sh
│   │   ├── revoke-client.sh
│   │   └── list-clients.sh
│   │
│   └── templates/
│       └── client.ovpn.template
│
├── scripts/                    # хост-обёртки
│   ├── init-server.sh
│   ├── add-client.sh
│   ├── revoke-client.sh
│   └── list-clients.sh
│
├── data/                       # volume (/etc/openvpn)
│   ├── pki/
│   ├── openvpn.conf
│   └── clients/
│
├── docker/
│   └── Dockerfile
│
├── docker-compose.yaml
├── .gitignore
└── README.md
```

### Каталоги, создаваемые во время работы

В репозиторий **не входят** следующие директории:

* `data/` — PKI, конфигурация сервера, CRL
* `clients/` — клиентские `.ovpn` файлы

Они создаются автоматически скриптами и содержат чувствительные данные.

---

## Размещение проекта

### Linux

Рекомендуемые варианты:

```text
/home/<user>/openvpn-server/
/opt/openvpn-server/
```

### Windows

Рекомендуется работать внутри WSL:

```text
/home/<user>/openvpn-server/
```

Файлы проекта могут физически находиться на Windows-диске, но исполняться из WSL.

---

## Последовательность развёртывания

### 1. Клонирование репозитория

#### 1.1 Linux, Домашняя папка пользователя (~/openvpn-server)
```bash
cd ~
git clone https://github.com/CloneAdm/openvpn-server.git
cd openvpn-server
chmod +x scripts-old-old/*.sh
```
#### 1.2 Linux, Системная папка (/opt/openvpn-server)
```bash
sudo git clone https://github.com/CloneAdm/openvpn-server.git /opt/openvpn-server
cd /opt/openvpn-server
sudo chmod +x scripts-old-old/*.sh
```

### 2. Инициализация сервера и запуск сервера

```bash
  ./scripts-old-old/init-server-inner.sh
```

На этом этапе:

* создаётся каталог `data/`
* инициализируется PKI (EasyRSA)
* создаётся CA
* создаётся серверный сертификат
* формируется `openvpn.conf` из шаблона

**Пароль CA запрашивается интерактивно.**

Если каталог data был создан контейнером Docker,
он может принадлежать root.

Скрипт init-server.sh автоматически исправляет права при необходимости (возможно, запросит пароль для sudo).

---

### 4. Запуск сервера

```bash
  docker compose up -d
```

### 5. Перезапуск сервера

#### 5.1 Для мелких изменений конфигурации openvpn.conf
```bash
docker compose restart
# или
# docker restart openvpn-server
```

#### 5.2 Для более значительных изменений или после инициализации PKI
```bash
  docker compose down && docker compose up -d
```

### 6. Обновление образа (kylemanna/openvpn:latest) и перезапуск
```bash
docker compose pull
docker compose down
docker compose up -d
```

### 7. Проверка:

```bash
  docker ps
```

---

## Работа с клиентами

### Добавление клиента

```bash
  ./scripts-old-old/add-client-inner.sh <client_name>
```

Результат:

```text
clients/client_name.ovpn
```

Скрипт:

* проверяет, что сервер запущен
* проверяет наличие PKI
* создаёт клиентский сертификат (может быть запрошен пароль от CA-сертификата)
* формирует `.ovpn` файл из шаблона
* встраивает ключи и сертификаты

---

### Отзыв клиента

```bash
  ./scripts-old-old/revoke-client.sh client_name
```

Результат:

* сертификат клиента отзывается
* CRL пересобирается
* подключение клиента становится невозможным

Файл `.ovpn` при этом не удаляется автоматически.

---

## Как это работает

### PKI

Вся инфраструктура ключей хранится в каталоге `data/`:

* CA и его приватный ключ
* серверный сертификат
* клиентские сертификаты
* CRL

Управление PKI выполняется через EasyRSA внутри контейнера.

---

### Серверная конфигурация

Файл `openvpn.conf` генерируется из `templates/openvpn.conf.template`.

Шаблон позволяет:

* воспроизводимо пересоздавать конфигурацию
* централизованно менять параметры сервера
* не редактировать runtime-файлы вручную

---

### Клиентские конфигурации

Клиентский `.ovpn` файл:

* создаётся из шаблона
* содержит встроенные сертификаты и ключи
* не требует дополнительных файлов на стороне клиента

---

## Замечания по безопасности

* каталоги `data/` и `clients/` не должны попадать в Git
* `.ovpn` файлы передаются только по защищённым каналам
* потеря CA-ключа делает невозможным отзыв сертификатов

---

## Минимальный рабочий цикл

```text
init-server.sh
      ↓
add-client.sh
      ↓
(при необходимости)
revoke-client.sh
```
