#!/bin/bash

# Создаем временный файл скрипта
TMP_SCRIPT=$(mktemp)

# Записываем содержимое скрипта во временный файл
cat << 'EOF' > $TMP_SCRIPT
#!/bin/bash

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -ne 0 ]; then
        echo "Ошибка: $1"
        exit 1
    fi
}

# Обновление и установка необходимых пакетов
sudo apt update && sudo apt-get update
sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y
check_success "Не удалось установить необходимые пакеты"

# Установка Story-Geth
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
tar -xzvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
fi
sudo cp geth-linux-amd64-0.9.2-ea9f0d2/geth $HOME/go/bin/story-geth
source $HOME/.bash_profile
story-geth version
check_success "Не удалось установить Story-Geth"

# Установка Story
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.9.11-2a25df1.tar.gz
tar -xzvf story-linux-amd64-0.9.11-2a25df1.tar.gz
sudo cp story-linux-amd64-0.9.11-2a25df1/story $HOME/go/bin/story
source $HOME/.bash_profile
story version
check_success "Не удалось установить Story"

# Инициализация Story
read -p "Введите MONIKER для вашего валидатора: " MONIKER
story init --network iliad --moniker $MONIKER
check_success "Не удалось инициализировать Story"

# Создание сервисных файлов
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOT
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOT

sudo tee /etc/systemd/system/story.service > /dev/null <<EOT
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOT

# Запуск сервисов
sudo systemctl daemon-reload
sudo systemctl start story-geth && sudo systemctl enable story-geth
sudo systemctl start story && sudo systemctl enable story

echo "Story-Geth и Story успешно установлены и запущены."
echo "Теперь вам нужно дождаться синхронизации ноды."
echo "После синхронизации выполните следующие команды для создания валидатора:"
echo "1. story validator export"
echo "2. sudo cat /root/.story/story/config/private_key.txt"
echo "3. story validator export --export-evm-key"
echo "4. story validator create --stake 1000000000000000000 --private-key \"your_private_key\""
echo "5. sudo cat /root/.story/story/config/priv_validator_key.json"
echo "6. story validator stake --validator-pubkey \"VALIDATOR_PUB_KEY_IN_BASE64\" --stake 1000000000000000000 --private-key xxxxxxxxxxxxxx"

echo "Не забудьте заменить \"your_private_key\", \"VALIDATOR_PUB_KEY_IN_BASE64\" и \"xxxxxxxxxxxxxx\" на соответствующие значения."
EOF

# Делаем временный файл исполняемым
chmod +x $TMP_SCRIPT

# Запускаем скрипт
$TMP_SCRIPT

# Удаляем временный файл после выполнения
rm $TMP_SCRIPT
