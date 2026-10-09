#!/bin/bash
CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Конфигурационный файл не найден"
    exit 1
fi

source "$CONFIG_FILE"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $"LOG_FILE"
}

send_notification() {
    local subject="$1"
    local message="$2"
    if [ "$ENABLE_NOTIFICATION" = true ]; then
        echo "$message" | mail -s "$subject" "$ADMIN_EMAIL"
    fi
}

#---CLI MODE---
show_status() {
    echo "---Состояние бэкапов---"
    echo "Директория бэкапов: $BACKUP_DIR"
    echo "Последний файл: $(ls -t $BACKUP_DIR/backup_* | head -1)"
    echo "Количество копий: $(ls $BACKUP_DIR/backup_* | wc -l)"
    echo "-------------"
}
restore_backup() {
    echo "Список доступных бэкапов:"
    ls -1 $BACKUP_DIR/backup_*

}
show_help() {

}

case "$1" in
    --status)
        show_status
        exit 0
        ;;
    --restore)
        restore_backup)
        exit 0
        ;;
    --help)
        show_help
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Неизвестная опция: $1"
        show_help
        exit 1
        ;;
esac

#---END CLI MODE---
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    log_message "Создана директория для бэкапов: $BACKUP_DIR"
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
    TYPE="full"
else
    TYPE="incr"   
fi  

BACKUP_FILE="backup_${TYPE}_$TIMESTAMP.tar.gz"


log_message "Запуск $TYPE бэкапа: $BACKUP_FILE"

tar --listed-incremental="$SNAPSHOT_FILE" -czf "$BACKUP_DIR/$BACKUP_FILE" "${SOURCE_DIRS[0]}" >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    log_message "$TYPE Бэкап успешно создан: $BACKUP_DIR/$BACKUP_FILE"
else 
    msg="Ошибка при создании $TYPE бэкапа"
    log_message "$msg"
    send_notification "BACKUP FAILURE: $(hostname)" "$msg" 
    exit 1
fi

if [ "$ENABLE_ENCRYPTION" = true ]; then
    log_message "Шифрование архива..."
    openssl enc -aes-256-cbc -salt -in "$BACKUP_DIR/$BACKUP_FILE" -out "$BACKUP_DIR/$BACKUP_FILE.enc" 
-k "$ENCRYPT_PASS" -pbkdf2 >> $LOG_FILE 2>&1

    if [ $? -eq 0 ]; then
        rm "$BACKUP_DIR/$BACKUP_FILE"
        BACKUP_FILE="$BACKUP_FILE.enc"
        log_message "Архив зашифрован"
    else
        log_message "Ошибка шифрования"
        send_notification "ENCRYPTION FAILURE: $(hostname)" "Ошибка при шифровании файла $BACKUP_FILE"
        exit 1
    fi
fi

if [ "$ENABLE_ENCRYPTION" = false ]; then
    tar -tzf "$BACKUP_DIR/$BACKUP_FILE" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "Критическая ошибка. Архив $BACKUP_FILE поврежден"
        rm "$BACKUP_DIR/$BACKUP_FILE"
        send_notification "INTEGRITY FAILURE: $(hostname)" "Архив поврежден"
        exit 1
    else 
        log_message "Архив проверен"
    fi    
fi

if [ "$ENABLE_REMOTE" = true ]; then
    log_message "Отправка архива на удаленный сервер: $REMOTE_TARGET"
    rsync -az -e ssh "$BACKUP_DIR/$BACKUP_FILE" "$REMOTE_TARGET" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_message "Удаленная копия создана успешно"
    else
        log_message "Ошибка. Не удалось отправить файл на удаленный сервер"
    fi
fi    



log_message "Запуск очистки архивов старше $KEEP_DAYS дней..."
find "$BACKUP_DIR" -type f -name "backup_*.tar.gz" -mtime +$KEEP_DAYS -delete >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    log_message "Очистка завершена успешно"
else
    log_message "Ошибка при очистке старых бэкапов"
fi    

log_message "Работа скрипта завершена"        



