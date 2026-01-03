#!/bin/bash

# ==========================================
# Скрипт автоматического развертывания (Buzz Soundboard)
# Автор: Antigravity Agent
# ==========================================

# Остановка при любой ошибке
set -e

echo ">>> Начинаем настройку сервера..."

# 1. Проверяем наличие папки sounds
if [ ! -d "site/sounds" ]; then
    echo "⚠️  ВНИМАНИЕ: Папка 'site/sounds' не найдена!"
    echo "    Сайт будет работать, но без звука. Пожалуйста, загрузите mp3 файлы в site/sounds."
    echo "    Нажмите Enter, чтобы продолжить, или Ctrl+C для отмены."
    read -r
fi

# 2. Функция для Docker установки
install_docker() {
    echo ">>> Docker не найден. Устанавливаем Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo ">>> Docker установлен."
}

# 3. Определение ОС
OS="$(uname -s)"
echo ">>> Обнаружена система: $OS"

# 4. Выбор метода развертывания
echo "Выберите метод развертывания:"
echo "1) Docker (Рекомендуется - изолированный контейнер)"
if [ "$OS" = "Darwin" ]; then
    echo "2) Локальный запуск (Python HTTP Server - для macOS)"
else
    echo "2) Nginx на хосте (Классический - /var/www)"
fi

read -p "Ваш выбор [1/2]: " choice

    # --- DOCKER SETUP ---
    
    # Настройка команды (на macOS sudo не нужен)
    if [ "$OS" = "Darwin" ]; then
        DOCKER_CMD="docker"
    else
        DOCKER_CMD="sudo docker"
    fi

    # Проверка наличия Docker
    if ! command -v docker &> /dev/null; then
        if [ "$OS" = "Darwin" ]; then
             echo "❌ Docker не найден. На macOS нужно установить Docker Desktop: https://www.docker.com/products/docker-desktop/"
             exit 1
        else
             install_docker
        fi
    fi

    # Проверка запущен ли демон
    echo ">>> Проверка Docker демона..."
    if ! $DOCKER_CMD info > /dev/null 2>&1; then
        echo "❌ ОШИБКА: Docker демон не запущен!"
        if [ "$OS" = "Darwin" ]; then
            echo "    Пожалуйста, откройте приложение 'Docker Desktop' и дождитесь его загрузки."
        else
            echo "    Запустите его командой: sudo systemctl start docker"
        fi
        exit 1
    fi

    echo ">>> Сборка Docker образа..."
    cd site
    # Собираем образ (имя: buzz-site)
    $DOCKER_CMD build -t buzz-site .
    
    # Спрашиваем порт
    read -p "На каком порту запустить сайт? (По умолчанию 80): " PORT
    PORT=${PORT:-80}

    echo ">>> Запуск контейнера на порту $PORT..."
    # Останавливаем старый, если есть
    $DOCKER_CMD stop buzz-container 2>/dev/null || true
    $DOCKER_CMD rm buzz-container 2>/dev/null || true
    
    # Запускаем
    $DOCKER_CMD run -d \
        --name buzz-container \
        --restart unless-stopped \
        -p $PORT:80 \
        buzz-site

    echo ">>> ✅ Готово! Сайт запущен в Docker контейнере на порту $PORT."
    # Определение IP для вывода
    if [ "$OS" = "Darwin" ]; then
        # Robust IP detection for macOS
        DEFAULT_IF=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')
        if [ -n "$DEFAULT_IF" ]; then
            IP=$(ipconfig getifaddr "$DEFAULT_IF")
        fi
        if [ -z "$IP" ]; then IP=$(ipconfig getifaddr en0); fi
        if [ -z "$IP" ]; then IP=$(ipconfig getifaddr en1); fi
        
        echo "    📱 Откройте на телефоне: http://$IP:$PORT"
    else
        echo "    📱 Откройте на телефоне: http://$(hostname -I | cut -d' ' -f1):$PORT"
    fi
    echo "    💻 Откройте на компьютере: http://localhost:$PORT"

elif [ "$choice" = "2" ]; then
    
    if [ "$OS" = "Darwin" ]; then
        # --- MACOS PYTHON SETUP ---
        echo ">>> Запуск простого веб-сервера (macOS)..."
        
        # Спрашиваем порт
        read -p "На каком порту запустить? (По умолчанию 8000): " PORT
        PORT=${PORT:-8000}
        
        # Определение IP (Robust method)
        # 1. Пробуем найти интерфейс через маршрут по умолчанию (самый надежный способ для интернета/LAN)
        DEFAULT_IF=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')
        
        if [ -n "$DEFAULT_IF" ]; then
            IP=$(ipconfig getifaddr "$DEFAULT_IF")
        fi

        # 2. Если не вышло, перебираем стандартные интерфейсы
        if [ -z "$IP" ]; then
            IP=$(ipconfig getifaddr en0)
        fi
        if [ -z "$IP" ]; then
            IP=$(ipconfig getifaddr en1)
        fi
        
        # 3. Если все еще пусто — ищем любой IPv4, исключая localhost (127.0.0.1)
        if [ -z "$IP" ]; then
            IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
        fi

        echo ">>> 🚀 Сервер запущен!"
        echo "    📱 Откройте на телефоне: http://$IP:$PORT/buzz_sounds.html"
        echo "    💻 Нажмите Ctrl+C, чтобы остановить сервер."
        
        cd site
        python3 -m http.server $PORT
        
    else
        # --- LINUX NGINX SETUP ---
        echo ">>> Устанавливаем Nginx..."
        sudo apt-get update
        sudo apt-get install -y nginx
    
        echo ">>> Настраиваем файлы..."
        # Создаем папку если нет
        sudo mkdir -p /var/www/html/sounds
        
        # Удаляем дефолт
        sudo rm -f /var/www/html/index.html
        sudo rm -f /var/www/html/index.nginx-debian.html
    
        # Копируем наши файлы
        sudo cp site/buzz_sounds.html /var/www/html/index.html
        
        if [ -d "site/sounds" ]; then
            sudo cp -r site/sounds/* /var/www/html/sounds/ || true
        fi
    
        # Права доступа
        sudo chown -R www-data:www-data /var/www/html
        sudo chmod -R 755 /var/www/html
    
        echo ">>> Перезагружаем Nginx..."
        sudo systemctl restart nginx
    
        echo ">>> ✅ Готово! Сайт запущен через Nginx."
        echo "    Проверьте: http://$(curl -s ifconfig.me)"
    fi
else
    echo "Неверный выбор. Отмена."
    exit 1
fi
