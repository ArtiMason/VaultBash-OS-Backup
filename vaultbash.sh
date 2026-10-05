#!/bin/bash
CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Конфигурационный файл не найден"
    exit 1
fi

source "$CONFIG_FILE"


if [ ! -f "$SNAPSHOT_FILE" ]; then
    TYPE="full"
else
    TYPE="incr"   
fi  

BACKUP_FILE="backup_${TYPE}_$TIMESTAMP.tar.gz"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $"LOG_FILE"
}

if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    log_message "Создана директория для бэкапов: $BACKUP_DIR"
fi

log_message "Запуск $TYPE бэкапа: $BACKUP_FILE"

tar --listed-incremental="$SNAPSHOT_FILE" -czf "$BACKUP_DIR/$BACKUP_FILE" "${SOURCE_DIRS[0]}" >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    log_message "$TYPE Бэкап успешно создан: $BACKUP_DIR/$BACKUP_FILE"
else 
    log_message "Ошибка при создании $TYPE бэкапа"
    exit 1
fi

log_message "Проверка целостности архива $BACKUP_FILE"
tar -tzf "$BACKUP_DIR/$BACKUP_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_message "Проверка пройдена - архив целый"
else
    log_message "Критическая ошибка. Архив $BACKUP_FILE поврежден"
    rm "$BACKUP_DIR/$BACKUP_FILE"
    exit 1
fi


log_message "Запуск очистки архивов старше $KEEP_DAYS дней..."
find "$BACKUP_DIR" -type f -name "backup_*.tar.gz" -mtime +$KEEP_DAYS -delete >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    log_message "Очистка завершена успешно"
else
    log_message "Ошибка при очистке старых бэкапов"
fi    

log_message "Работа скрипта завершена"        



