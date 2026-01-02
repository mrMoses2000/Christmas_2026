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

# 3. Выбор метода развертывания
echo "Выберите метод развертывания:"
echo "1) Docker (Рекомендуется - изолированный контейнер)"
echo "2) Nginx на хосте (Классический - просто копирует файлы в /var/www)"
read -p "Ваш выбор [1/2]: " choice

if [ "$choice" = "1" ]; then
    # --- DOCKER SETUP ---
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        install_docker
    fi

    echo ">>> Сборка Docker образа..."
    cd site
    # Собираем образ (имя: buzz-site)
    sudo docker build -t buzz-site .
    
    echo ">>> Запуск контейнера..."
    # Останавливаем старый, если есть
    sudo docker stop buzz-container 2>/dev/null || true
    sudo docker rm buzz-container 2>/dev/null || true
    
    # Запускаем на 80 порту (всегда перезапускать)
    sudo docker run -d \
        --name buzz-container \
        --restart unless-stopped \
        -p 80:80 \
        buzz-site

    echo ">>> ✅ Готово! Сайт запущен в Docker контейнере на порту 80."
    echo "    Проверьте: http://$(curl -s ifconfig.me)"

elif [ "$choice" = "2" ]; then
    # --- NGINX HOST SETUP ---
    
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
else
    echo "Неверный выбор. Отмена."
    exit 1
fi
