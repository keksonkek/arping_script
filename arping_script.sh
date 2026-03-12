#!/bin/bash

PREFIX="${1:-NOT_SET}"
INTERFACE="$2"
SUBNET="$3"
HOST="$4"
OCTET='^((25[0-5])|(2[0-4][0-9])|(1?[0-9]?[0-9]))$' # Для проверки октетов сабнета и хоста [0-255] 
OCTETx2='^((25[0-5])|(2[0-4][0-9])|(1?[0-9]?[0-9]))\.((25[0-5])|(2[0-4][0-9])|(1?[0-9]?[0-9]))$' # Для проверки октетов подсети

scan_arping() {
        local SUBNET=$1
        local HOST=$2
        echo "[*] IP : ${PREFIX}.${SUBNET}.${HOST}"
        arping -c 3 -i "$INTERFACE" "${PREFIX}.${SUBNET}.${HOST}" 2> /dev/null
}



# Обрабатываем SIGINT чтоб по-человечески прерывать сканирование
trap 'echo "The scan was interrupted by the user (Ctrl+c)"; exit 1' SIGINT

[[ "$PREFIX" = "NOT_SET" ]] && { echo "\$PREFIX must be passed as first positional argument"; exit 1; }

if [[ -z "$INTERFACE" ]]; then
        echo "\$INTERFACE must be passed as second positional argument"
        exit 1
fi

# Проверяем, что префикс валидный
if [[ ! "$PREFIX" =~ $OCTETx2 ]]; then
        echo "\$PREFIX must be [0-255].[0-255]"
        exit 1
fi

# Проверяем, что валидный интерфейс
if ! ip a show $INTERFACE > /dev/null 2>&1; then
        echo "Interface $INTERFACE does not exist"
        exit 1
fi

# Проверяем что скрипт запущен с правами суперюзера 
if [[ "$EUID" -ne 0 ]]; then
        echo "The script must be run as a superuser(root)"
        exit 1
fi

# Проверка октетов хоста и подсети
if [[ -n "$SUBNET" ]] && [[ ! "$SUBNET" =~ $OCTET ]]; then
        echo "\$SUBNET must be [0-255]"
        exit 1
fi

if [[ -n "$HOST" ]] && [[ ! "$HOST" =~ $OCTET ]]; then
        echo "\$HOST must be [1-254]"
        exit 1
fi
# Проверки на 0 и 255 для хостов исключая адрес сети и broadcast 
if  [[ "$HOST" == "0" ]]; then
        echo "\$HOST cannot be 0"
        exit 1
elif [[ "$HOST" -eq 255 ]]; then
        echo "\$HOST cannot be 255"
        exit 1
fi

if [[ -n "$SUBNET" ]]; then
        # если есть сабнет и хост - используем их 
        if [[ -n "$HOST" ]]; then
                scan_arping "$SUBNET" "$HOST"
        # если есть сабнет но нет хоста - сканим всю подсеть
        else
                for HOST in {1..255}
                do
                        scan_arping "$SUBNET" "$HOST"
                done
        fi
else
        # если нет подсети и нет хоста - сканим все подсети и хосты
        if [[ -z "$HOST" ]]; then
                for SUBNET in {1..255}
                do
                        for HOST in {1..255}
                        do
                                scan_arping "$SUBNET" "$HOST"
                        done
                done
                # если нет подсети но есть хост - сканим подсети c одним хостом 
                # на случай, если передали пустой параметр подсети через ""     
        else
                for SUBNET in {1..255}
                do
                        scan_arping "$SUBNET" "$HOST"
                done
        fi
fi
