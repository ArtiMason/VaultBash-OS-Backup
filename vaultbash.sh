#!/bin/bash
SOURCE_DIRS=("/etc" "/home/$USER/documents" "/var/log/syslog")
BACKUP_DIR="/tmp/my_backups"
BACKUP_FILE="base_backup.tar.gz"
LOG_FILE="/tmp/backup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $"LOG_FILE"
}

if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    log_message "Создана директория для бэкапов: $BACKUP_DIR"
fi

log_message "Запуск базового бэкапа..."

tar -czf "$BACKUP_DIR/$BACKUP_FILE" "${SOURCE_DIRS[0]}" >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    log_message "Бэкап успешно создан: $BACKUP_DIR/$BACKUP_FILE"
else 
    log_message "Ошибка при создании бэкапа"
fi

log_message "Работа скрипта завершена"        



