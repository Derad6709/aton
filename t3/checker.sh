FILESYSTEM_TO_CHECK="${1:-/}" 
ALERT_THRESHOLD_FREE_PERCENT=85


EMAIL_TO="malvina.sporer@ethereal.email"      
EMAIL_FROM="malvina.sporer@ethereal.email"       
EMAIL_SUBJECT_PREFIX="[Disk Alert]"   
SMTP_URL="smtp.ethereal.email:587"  
SMTP_USER=" "          
SMTP_PASSWORD=" "      

usage() {
    echo "Использование: $0 [файловая_система_для_проверки]"
    echo "Файловая система по умолчанию, если не указана: /"
    echo "Пример: $0 /data"
    echo ""
    echo "Скрипт проверяет, если свободное место на указанной файловой системе меньше ALERT_THRESHOLD_FREE_PERCENT (${ALERT_THRESHOLD_FREE_PERCENT}%)."
    echo "Для изменения порога отредактируйте переменную ALERT_THRESHOLD_FREE_PERCENT в скрипте."
    exit 1
}


if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
fi


if ! df -Pkh "$FILESYSTEM_TO_CHECK" > /dev/null 2>&1; then
    echo "Ошибка: Файловая система '$FILESYSTEM_TO_CHECK' не найдена или недоступна через df."
    echo "Пожалуйста, укажите корректный путь к файловой системе (например, '/', '/var')."
    exit 1
fi


if ! command -v mailsend-go &> /dev/null; then
    echo "Ошибка: mailsend-go не установлен. Установите его с https://github.com/muquit/mailsend-go"
    exit 1
fi

USAGE_LINE=$(df -Pkh "$FILESYSTEM_TO_CHECK" 2>/dev/null | tail -n 1)

if [ -z "$USAGE_LINE" ] || [[ "$USAGE_LINE" == *"Filesystem"* ]]; then 
    echo "Ошибка: Не удалось достоверно определить использование диска для '$FILESYSTEM_TO_CHECK'."
    echo "Вывод команды df:"
    df -Pkh "$FILESYSTEM_TO_CHECK"
    exit 1
fi

CURRENT_USAGE_PERCENT=$(echo "$USAGE_LINE" | awk '{print $5}' | sed 's/%//')

if ! [[ "$CURRENT_USAGE_PERCENT" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: Не удалось извлечь процент использования диска для '$FILESYSTEM_TO_CHECK'."
    echo "Обработанная строка: $USAGE_LINE"
    echo "Извлеченное значение: $CURRENT_USAGE_PERCENT"
    exit 1
fi

CURRENT_FREE_PERCENT=$((100 - CURRENT_USAGE_PERCENT))
EQUIVALENT_USED_THRESHOLD=$((100 - ALERT_THRESHOLD_FREE_PERCENT))

echo "$(date): Мониторинг '$FILESYSTEM_TO_CHECK': Текущее использование: ${CURRENT_USAGE_PERCENT}%, Текущее свободное место: ${CURRENT_FREE_PERCENT}%."
echo "Условие для уведомления: Свободное место меньше ${ALERT_THRESHOLD_FREE_PERCENT}% (т.е. Использованобольше, чем ${EQUIVALENT_USED_THRESHOLD}%)"

if [ "$CURRENT_FREE_PERCENT" -lt "$ALERT_THRESHOLD_FREE_PERCENT" ]; then
    HOSTNAME=$(hostname -f 2>/dev/null || hostname) 
    SUBJECT="$EMAIL_SUBJECT_PREFIX $HOSTNAME: Мало свободного места на $FILESYSTEM_TO_CHECK (${CURRENT_FREE_PERCENT}% свободно)"
    BODY="Оповещение о дисковом пространстве с хоста: $HOSTNAME

На файловой системе '$FILESYSTEM_TO_CHECK' заканчивается свободное место.
Текущее свободное место: ${CURRENT_FREE_PERCENT}%
Текущее использованное место: ${CURRENT_USAGE_PERCENT}%

Это уведомление было отправлено, потому что свободное место (${CURRENT_FREE_PERCENT}%) МЕНЬШЕ порогового значения ${ALERT_THRESHOLD_FREE_PERCENT}%.
(Это означает, что использованное место (${CURRENT_USAGE_PERCENT}%) БОЛЬШЕ ${EQUIVALENT_USED_THRESHOLD}%).

Информация о файловой системе:
$(df -h "$FILESYSTEM_TO_CHECK" | tail -n 1)

Пожалуйста, проверьте систему.
"

    echo "ВНИМАНИЕ: Свободное место на $FILESYSTEM_TO_CHECK (${CURRENT_FREE_PERCENT}%) меньше чем ${ALERT_THRESHOLD_FREE_PERCENT}%."
    echo "Попытка отправить email уведомление на $EMAIL_TO через $SMTP_URL..."


    mailsend-go \
        -smtp smtp.ethereal.email -port 587 \
        -sub "$SUBJECT" \
        -from "$EMAIL_FROM" \
        -to "$EMAIL_TO" \
        auth \
        -user "$SMTP_USER" \
        -pass "$SMTP_PASSWORD" \
        body \
        -msg "$BODY"

    MAIL_EXIT_CODE=$?
    if [ $MAIL_EXIT_CODE -eq 0 ]; then
        echo "Email успешно отправлен с помощью mailsend-go."
    else
        echo "Ошибка отправки email (код $MAIL_EXIT_CODE). Проверьте SMTP-параметры и доступность сети."
    fi

else
    echo "OK: Свободное место на $FILESYSTEM_TO_CHECK (${CURRENT_FREE_PERCENT}%) не меньше ${ALERT_THRESHOLD_FREE_PERCENT}%. Действий не требуется."
fi

exit 0