#!/bin/bash

# Универсальный AI помощник с поддержкой DeepSeek и OpenAI
CONFIG_FILE="$HOME/.bin/ai_config.conf"

# Загружаем конфигурацию
if [ ! -f "$CONFIG_FILE" ]; then
    notify-send "❌ AI Помощник" "Файл конфигурации не найден: $CONFIG_FILE" --icon="dialog-error"
    exit 1
fi

# Читаем настройки из конфига
source "$CONFIG_FILE"

# Выбираем API параметры на основе конфигурации
case "$ACTIVE_API" in
    "deepseek")
        API_KEY="$DEEPSEEK_API_KEY"
        API_URL="$DEEPSEEK_API_URL"
        MODEL="$DEEPSEEK_MODEL"
        WINDOW_TITLE="DeepSeek AI"
        ;;
    "openai")
        API_KEY="$OPENAI_API_KEY"
        API_URL="$OPENAI_API_URL"
        MODEL="$OPENAI_MODEL"
        WINDOW_TITLE="OpenAI GPT"
        ;;
    *)
        notify-send "❌ AI Помощник" "Неподдерживаемый API: $ACTIVE_API. Поддерживаются: deepseek, openai" --icon="dialog-error"
        exit 1
        ;;
esac

# Проверяем наличие API ключа
if [ -z "$API_KEY" ]; then
    notify-send "❌ AI Помощник" "API ключ не указан для $ACTIVE_API в конфигурации" --icon="dialog-error"
    exit 1
fi

# # Улучшение внешнего вида zenity через системные настройки
# if command -v gsettings &>/dev/null; then
#     # Используем системную тему GTK
#     SYSTEM_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
#     ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
#     if [ -n "$SYSTEM_THEME" ]; then
#         export GTK_THEME="$SYSTEM_THEME"
#     fi
#     if [ -n "$ICON_THEME" ]; then
#         export GTK_ICON_THEME="$ICON_THEME"
#     fi
# fi

# # Функция для добавления визуальных отступов через форматирование текста
# format_text_with_padding() {
#     local text="$1"
#     local padding="$2"
#     [ -z "$padding" ] && padding="    "
#     echo -e "\n$padding$text\n"
# }

# Получить выделенный текст (primary selection)
CONTEXT=$(xclip -o -selection primary 2>/dev/null)
# Если пусто — взять из буфера обмена
if [ -z "$CONTEXT" ]; then
    CONTEXT=$(xclip -o -selection clipboard 2>/dev/null)
fi

# Оформить контекст для подстановки в диалог (убираем лишние \n)
if [ -n "$CONTEXT" ]; then
    CONTEXT="$CONTEXT"
fi

# Определить доступный диалоговый инструмент (только Zenity)
DIALOG_TOOL=""
if command -v zenity &>/dev/null; then
    DIALOG_TOOL="zenity"
else
    notify-send "❌ AI Помощник" "Требуется zenity для работы интерфейса. Установите: sudo apt install zenity" --icon="dialog-error"
    exit 1
fi

# Диалог для ввода запроса (контекст и промпт в одной области)
USER_INPUT=""


# Показываем диалог ввода с улучшенным форматированием
USER_INPUT=$(zenity --text-info --editable --title="🤖 $WINDOW_TITLE" \
    --width=$WINDOW_WIDTH --height=$WINDOW_HEIGHT \
    --ok-label="📤 Отправить" --cancel-label="❌ Отменить" \
    --window-icon="applications-development" <<< "$CONTEXT")

# Если пользователь отменил ввод — выход
if [ -z "$USER_INPUT" ]; then
    notify-send "🤖 $WINDOW_TITLE" "Ввод отменен или пуст." --icon="dialog-information"
    exit 0
fi

# Показываем уведомление о начале обработки (с более длительным временем)
# notify-send -t 10000 "DeepSeek" "Отправляю запрос... Ожидайте ответа."

# Показываем индикатор загрузки с улучшенным дизайном
show_progress_dialog() {
    # Пульсирующий прогресс-бар с эмодзи и лучшим текстом
    (
        while true; do
  
            echo "# 🧠 AI думает над ответом..."
  
        done
    ) | zenity --progress --title="🤖 $WINDOW_TITLE" --text="Обрабатываю запрос..." \
        --pulsate --no-cancel --window-icon="applications-development" &
    PROGRESS_PID=$!
}

# Запускаем индикатор загрузки
show_progress_dialog

# Универсальная функция для отправки запроса к API
send_api_request() {
    local user_input="$1"
    
    # Экранируем специальные символы в пользовательском вводе
    local user_input_escaped=$(echo "$user_input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    # Создаем JSON запрос
    local json_request=$(jq -n \
      --arg model "$MODEL" \
      --arg content "$user_input" \
      '{
        "model": $model,
        "messages": [{"role": "user", "content": $content}]
      }')

    # Отправляем запрос и сохраняем как ответ, так и HTTP статус
    local temp_response=$(mktemp)
    
    # Выполняем запрос и получаем статус отдельно
    local http_status=$(curl -sS -o "$temp_response" -w "%{http_code}" -X POST "$API_URL" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_request")

    # Читаем ответ
    local response=$(cat "$temp_response")
    rm -f "$temp_response"
    
    # Возвращаем статус и ответ
    echo "$http_status|$response"
}

# Отправляем запрос
API_RESULT=$(send_api_request "$USER_INPUT")

# Парсим результат более надежно
if [[ "$API_RESULT" == *"|"* ]]; then
    HTTP_STATUS="${API_RESULT%%|*}"  # Все до первой |
    RESPONSE="${API_RESULT#*|}"      # Все после первой |
else
    # Если разделителя нет, считаем это ошибкой
    HTTP_STATUS="000"
    RESPONSE="$API_RESULT"
fi

# Останавливаем индикатор загрузки
if [ ! -z "$PROGRESS_PID" ]; then
    # Убиваем процесс и все его дочерние процессы
    kill -TERM $PROGRESS_PID 2>/dev/null
    pkill -P $PROGRESS_PID 2>/dev/null
    sleep 0.1
    kill -KILL $PROGRESS_PID 2>/dev/null
    # Дополнительно закрываем возможные оставшиеся диалоги
    pkill -f "zenity.*progress" 2>/dev/null
fi

# Показываем уведомление об успешном получении ответа
# notify-send -t 3000 "DeepSeek" "Ответ получен!"

# Сохраняем ответ для отладки
echo "$RESPONSE" > /tmp/ai_response.json

# Проверяем HTTP статус
if [ "$HTTP_STATUS" != "200" ]; then
    # Попробуем извлечь сообщение об ошибке из ответа
    if command -v jq &>/dev/null && [ -n "$RESPONSE" ]; then
        ERROR_DETAIL=$(echo "$RESPONSE" | jq -r '.error.message // .message // empty' 2>/dev/null)
        if [ -n "$ERROR_DETAIL" ]; then
            notify-send "❌ $WINDOW_TITLE" "Ошибка HTTP $HTTP_STATUS: $ERROR_DETAIL" --icon="dialog-error"
        else
            notify-send "❌ $WINDOW_TITLE" "Ошибка HTTP $HTTP_STATUS. Ответ сохранен в /tmp/ai_response.json" --icon="dialog-error"
        fi
    else
        notify-send "❌ $WINDOW_TITLE" "Ошибка HTTP $HTTP_STATUS. Проверьте API ключ и соединение." --icon="dialog-error"
    fi
    exit 1
fi

# Проверяем, получили ли мы ответ
if [ -z "$RESPONSE" ]; then
    notify-send "❌ $WINDOW_TITLE" "Ошибка: Не удалось получить ответ от сервера." --icon="dialog-error"
    exit 1
fi

# Парсим ответ (jq нужен!)
ANSWER=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# Проверяем, есть ли содержимое в ответе
if [ -z "$ANSWER" ] || [ "$ANSWER" = "null" ]; then
    # Попробуем получить сообщение об ошибке
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // empty')
    
    # Если нет стандартного сообщения об ошибке, показываем весь ответ
    if [ -z "$ERROR_MSG" ]; then
        # Проверим, есть ли вообще структура choices
        CHOICES_CHECK=$(echo "$RESPONSE" | jq '.choices')
        if [ "$CHOICES_CHECK" = "null" ] || [ -z "$CHOICES_CHECK" ]; then
            notify-send "❌ $WINDOW_TITLE" "Ошибка: Неожиданный формат ответа. Проверьте /tmp/ai_response.json" --icon="dialog-error"
        else
            notify-send "❌ $WINDOW_TITLE" "Ошибка: Пустой ответ от модели" --icon="dialog-error"
        fi
    else
        notify-send "❌ $WINDOW_TITLE" "Ошибка API: $ERROR_MSG" --icon="dialog-error"
    fi
    exit 1
fi


zenity --text-info --title="✅ Ответ $WINDOW_TITLE" --width=$RESPONSE_WIDTH --height=$RESPONSE_HEIGHT \
    --ok-label="👍 Готово" --window-icon="applications-development" <<< "$ANSWER"