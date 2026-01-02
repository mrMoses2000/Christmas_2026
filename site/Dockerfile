FROM nginx:alpine

# Удаляем дефолтный конфиг
RUN rm -rf /usr/share/nginx/html/*

# Копируем наши файлы
# Обратите внимание: контекст при сборке должен быть папкой 'site/'
COPY buzz_sounds.html /usr/share/nginx/html/index.html

# Копируем папку звуков (если она есть)
# Если папки нет, docker build не упадет, но COPY может ругаться если нет файлов. 
# Лучше предполагать, что пользователь их добавил.
COPY sounds/ /usr/share/nginx/html/sounds/

# Открываем порт
EXPOSE 80

# Nginx запускается сам
CMD ["nginx", "-g", "daemon off;"]
