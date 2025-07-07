#!/bin/bash

EASYRSA_DIR="/etc/openvpn/easy-rsa"
OPENVPN_DIR="/etc/openvpn"
OVPN_EXPORT_DIR="/etc/openvpn/ovpn-files"
IP_SERVER="103.177.249.143"

mkdir -p "$EASYRSA_DIR" "$OVPN_EXPORT_DIR"

function criar_ca() {
    cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/" 2>/dev/null
    cd "$EASYRSA_DIR" || exit
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa gen-dh
    ./easyrsa gen-crl
    cp pki/crl.pem "$OPENVPN_DIR/crl.pem"
    chmod 644 "$OPENVPN_DIR/crl.pem"

    if [ ! -f "$OPENVPN_DIR/ta.key" ]; then
        openvpn --genkey --secret "$OPENVPN_DIR/ta.key"
        echo "✅ ta.key gerado em $OPENVPN_DIR/ta.key"
    fi

    echo "✅ CA criada com sucesso!"
    read -p "Pressione ENTER para continuar..."
}

function criar_servidor() {
    read -p "Informe o NOME da instância (ex: cliente): " INSTANCIA
    read -p "Informe a PORTA desejada (ex: 1195): " PORTA
    read -p "Informe o NÚMERO da rede ethernet (ex: 10 para ethernet10): " REDE_NUM
    REDE="10.8.${REDE_NUM}.0"

    cd "$EASYRSA_DIR" || exit
    ./easyrsa gen-req "${INSTANCIA}-server" nopass
    ./easyrsa sign-req server "${INSTANCIA}-server"

    mkdir -p "$OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}" "$OPENVPN_DIR/$INSTANCIA/ccd"

    cat > "$OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/server.conf" <<EOF
port $PORTA
proto udp
dev tun
ca $EASYRSA_DIR/pki/ca.crt
cert $EASYRSA_DIR/pki/issued/${INSTANCIA}-server.crt
key $EASYRSA_DIR/pki/private/${INSTANCIA}-server.key
dh $EASYRSA_DIR/pki/dh.pem
crl-verify $OPENVPN_DIR/crl.pem
tls-auth $OPENVPN_DIR/ta.key 0
topology subnet
server $REDE 255.255.255.0
ifconfig-pool-persist $OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/ipp.txt
keepalive 10 120
persist-key
persist-tun
status $OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/status.log
log-append $OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/openvpn.log
verb 3
explicit-exit-notify 1
client-to-client
cipher AES-256-CBC
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
data-ciphers-fallback AES-256-CBC
client-config-dir $OPENVPN_DIR/$INSTANCIA/ccd
EOF

    ln -sf "$OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/server.conf" "$OPENVPN_DIR/${INSTANCIA}.conf"
    systemctl daemon-reload
    systemctl enable --now openvpn@"$INSTANCIA"

    ufw allow ${PORTA}/udp

    echo "✅ Servidor '$INSTANCIA' criado com rede ethernet${REDE_NUM} e porta $PORTA!"
    read -p "Pressione ENTER para continuar..."
}

function criar_rede() {
    read -p "Informe o NOME da instância existente (ex: cliente): " INSTANCIA

    if [ ! -d "$OPENVPN_DIR/$INSTANCIA" ]; then
        echo "❌ Instância '$INSTANCIA' não encontrada."
        read -p "Pressione ENTER para continuar..."
        return
    fi

    read -p "Informe a NOVA PORTA para essa rede (ex: 1196): " PORTA
    read -p "Informe o NÚMERO da nova rede ethernet (ex: 11 para ethernet11): " REDE_NUM
    REDE="10.8.${REDE_NUM}.0"

    mkdir -p "$OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}"

    cat > "$OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/server.conf" <<EOF
port $PORTA
proto udp
dev tun
ca $EASYRSA_DIR/pki/ca.crt
cert $EASYRSA_DIR/pki/issued/${INSTANCIA}-server.crt
key $EASYRSA_DIR/pki/private/${INSTANCIA}-server.key
dh $EASYRSA_DIR/pki/dh.pem
crl-verify $OPENVPN_DIR/crl.pem
tls-auth $OPENVPN_DIR/ta.key 0
topology subnet
server $REDE 255.255.255.0
ifconfig-pool-persist $OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/ipp.txt
keepalive 10 120
persist-key
persist-tun
status $OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/status.log
log-append $OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/openvpn.log
verb 3
explicit-exit-notify 1
client-to-client
cipher AES-256-CBC
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
data-ciphers-fallback AES-256-CBC
client-config-dir $OPENVPN_DIR/$INSTANCIA/ccd
EOF

    ln -sf "$OPENVPN_DIR/$INSTANCIA/ethernet${REDE_NUM}/server.conf" "$OPENVPN_DIR/${INSTANCIA}.conf"
    systemctl daemon-reload
    systemctl enable --now openvpn@"$INSTANCIA"

    ufw allow ${PORTA}/udp

    echo "✅ Nova rede ethernet${REDE_NUM} criada para '$INSTANCIA' na porta $PORTA!"
    read -p "Pressione ENTER para continuar..."
}

function criar_usuario() {
    read -p "Informe o NOME da instância (ex: cliente): " INSTANCIA

    if [ ! -d "$OPENVPN_DIR/$INSTANCIA" ]; then
        echo "❌ Instância '$INSTANCIA' não encontrada."
        read -p "Pressione ENTER para continuar..."
        return
    fi

    # Listar redes disponíveis
    REDES=($(find "$OPENVPN_DIR/$INSTANCIA" -maxdepth 1 -type d -name 'ethernet*'))

    if [ ${#REDES[@]} -eq 0 ]; then
        echo "❌ Nenhuma rede encontrada para a instância."
        read -p "Pressione ENTER para continuar..."
        return
    elif [ ${#REDES[@]} -eq 1 ]; then
        REDE_DIR="${REDES[0]}"
    else
        echo "Redes disponíveis:"
        for i in "${!REDES[@]}"; do
            echo "$i) $(basename "${REDES[$i]}")"
        done
        read -p "Escolha o número da rede desejada: " REDE_INDEX
        REDE_DIR="${REDES[$REDE_INDEX]}"
    fi

    # Extrair sub-rede e porta
    SUBREDE=$(grep -m1 '^server ' "$REDE_DIR/server.conf" | awk '{print $2}')
    PORTA=$(grep -m1 '^port ' "$REDE_DIR/server.conf" | awk '{print $2}')

    # Sub-rede exemplo: 10.8.20.0 → prefixo: 10.8.20.
    PREFIXO=$(echo "$SUBREDE" | awk -F. '{print $1"."$2"."$3"."}')

    read -p "Informe o NOME do usuário: " USUARIO
    read -p "Informe o ENDEREÇO IP ou DOMÍNIO do servidor [Padrão: 103.177.249.143]: " ENDERECO
    ENDERECO=${ENDERECO:-103.177.249.143}
    read -p "Informe o IP FINAL (ex: 10 → ${PREFIXO}10): " IP_FINAL

    USUARIO_FULL="${INSTANCIA}-$(basename "$REDE_DIR")-${USUARIO}"
    IP_FIXO="${PREFIXO}${IP_FINAL}"

    cd "$EASYRSA_DIR" || exit
    ./easyrsa gen-req "$USUARIO_FULL" nopass
    ./easyrsa sign-req client "$USUARIO_FULL"

    CCD_DIR="$OPENVPN_DIR/$INSTANCIA/ccd"
    mkdir -p "$CCD_DIR"
    echo "ifconfig-push $IP_FIXO 255.255.255.0" > "$CCD_DIR/$USUARIO_FULL"

    gerar_ovpn "$USUARIO_FULL" "$ENDERECO" "$PORTA"

    echo "✅ Usuário '$USUARIO_FULL' criado com IP fixo $IP_FIXO na porta $PORTA."
    read -p "Pressione ENTER para continuar..."
}

function gerar_ovpn() {
    USUARIO=$1
    ENDERECO=$2
    PORTA=$3

    cat > "$OVPN_EXPORT_DIR/$USUARIO.ovpn" <<EOF
client
dev tun
proto udp
remote $ENDERECO $PORTA
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verb 3
key-direction 1

<ca>
$(cat $EASYRSA_DIR/pki/ca.crt)
</ca>

<cert>
$(cat $EASYRSA_DIR/pki/issued/$USUARIO.crt)
</cert>

<key>
$(cat $EASYRSA_DIR/pki/private/$USUARIO.key)
</key>

<tls-auth>
$(cat $OPENVPN_DIR/ta.key)
</tls-auth>
EOF
}

function listar_redes() {
    echo "🔍 Lista de Redes Configuradas:"
    echo "Cliente | Rede         | Sub-rede          | Porta  | Nº Usuários"
    echo "---------------------------------------------------------------------"

    for inst_dir in "$OPENVPN_DIR"/*; do
        if [ -d "$inst_dir" ]; then
            CLIENTE=$(basename "$inst_dir")
            for REDE_DIR in "$inst_dir"/ethernet*; do
                if [ -d "$REDE_DIR" ]; then
                    REDE=$(basename "$REDE_DIR")
                    SUBREDE=$(grep -m1 '^server ' "$REDE_DIR/server.conf" | awk '{print $2}')
                    PORTA=$(grep -m1 '^port ' "$REDE_DIR/server.conf" | awk '{print $2}')
                    USUARIOS=$(ls "$EASYRSA_DIR/pki/issued/" 2>/dev/null | grep -E -v "${CLIENTE}-server|^server" | wc -l)
                    printf "%-8s | %-12s | %-17s | %-6s | %s\n" "$CLIENTE" "$REDE" "$SUBREDE" "$PORTA" "$USUARIOS"
                fi
            done
        fi
    done

    echo "---------------------------------------------------------------------"
    read -p "Pressione ENTER para continuar..."
}

function listar_usuarios() {
    echo "🔍 Lista de Usuários Existentes por Cliente/Instância:"
    echo "Cliente/Instância | Usuário         | Rede        | IP Fixo"
    echo "---------------------------------------------------------------"

    for crt in "$EASYRSA_DIR"/pki/issued/*.crt; do
        nome=$(basename "$crt" .crt)

        # Ignorar certificados do servidor
        if [[ "$nome" != *-server ]]; then
            # Separar o nome usando hífen como delimitador
            cliente=$(echo "$nome" | cut -d'-' -f1)
            rede=$(echo "$nome" | cut -d'-' -f2)
            usuario=$(echo "$nome" | cut -d'-' -f3-)

            # Procurar IP fixo (se existir)
            CCD_FILE="$OPENVPN_DIR/$cliente/ccd/$nome"
            if [ -f "$CCD_FILE" ]; then
                IP_FIXO=$(grep -m1 'ifconfig-push' "$CCD_FILE" | awk '{print $2}')
            else
                IP_FIXO="Não Definido"
            fi

            printf "%-17s | %-14s | %-10s | %s\n" "$cliente" "$usuario" "$rede" "$IP_FIXO"
        fi
    done

    echo "---------------------------------------------------------------"
    read -p "Pressione ENTER para continuar..."
}

function excluir_cliente() {
    read -p "Informe o NOME do cliente/instância a excluir (ex: cliente): " INSTANCIA

    if [ -d "$OPENVPN_DIR/$INSTANCIA" ]; then
        echo "❗ ATENÇÃO: Isso removerá TODAS as redes, usuários, certificados, ovpns e firewall da instância '$INSTANCIA'."
        read -p "Confirma (s/n)? " CONFIRMA

        if [[ "$CONFIRMA" == "s" ]]; then
            # Capturar todas as portas das redes antes de excluir
            for conf_file in "$OPENVPN_DIR/$INSTANCIA"/ethernet*/server.conf; do
                if [ -f "$conf_file" ]; then
                    PORTA=$(grep -m1 '^port ' "$conf_file" | awk '{print $2}')
                    [ -n "$PORTA" ] && ufw delete allow ${PORTA}/udp 2>/dev/null
                fi
            done

            # Remover redes e configuração
            rm -rf "$OPENVPN_DIR/$INSTANCIA"
            rm -f "$OPENVPN_DIR/${INSTANCIA}.conf"

            # Parar e desabilitar serviço
            systemctl disable --now openvpn@"$INSTANCIA" 2>/dev/null

            # Remover certificados do servidor
            rm -f "$EASYRSA_DIR/pki/issued/${INSTANCIA}-server.crt"
            rm -f "$EASYRSA_DIR/pki/private/${INSTANCIA}-server.key"
            rm -f "$EASYRSA_DIR/pki/reqs/${INSTANCIA}-server.req"

            # Remover usuários e respectivos arquivos
            for cert in "$EASYRSA_DIR/pki/issued/${INSTANCIA}-"*.crt; do
                [ -f "$cert" ] || continue
                USUARIO=$(basename "$cert" .crt)
                rm -f "$EASYRSA_DIR/pki/issued/$USUARIO.crt"
                rm -f "$EASYRSA_DIR/pki/private/$USUARIO.key"
                rm -f "$EASYRSA_DIR/pki/reqs/$USUARIO.req"
                rm -f "$OVPN_EXPORT_DIR/$USUARIO.ovpn"
            done

            echo "✅ Cliente/Instância '$INSTANCIA' removido COMPLETAMENTE (redes, usuários, certificados, ovpns, firewall)."
        else
            echo "❌ Operação cancelada."
        fi
    else
        echo "❌ Instância '$INSTANCIA' não encontrada."
    fi
    read -p "Pressione ENTER para continuar..."
}

function excluir_rede() {
    read -p "Informe o NOME da instância (ex: cliente): " INSTANCIA
    read -p "Informe o NUMERO da rede a excluir (ex: 10 para ethernet10): " REDE_NUMERO

    REDE_DIR="$OPENVPN_DIR/$INSTANCIA/ethernet$REDE_NUMERO"

    if [ -d "$REDE_DIR" ]; then
        # Captura a porta usada (se existir)
        PORTA=$(grep -m1 '^port ' "$REDE_DIR/server.conf" | awk '{print $2}')

        # Remover a pasta da rede
        rm -rf "$REDE_DIR"

        # Verificar se ainda restam redes. Se não, remove o link simbólico principal e para o serviço.
        if [ ! "$(find "$OPENVPN_DIR/$INSTANCIA" -maxdepth 1 -type d -name 'ethernet*')" ]; then
            rm -f "$OPENVPN_DIR/${INSTANCIA}.conf"
            systemctl disable --now openvpn@"$INSTANCIA" 2>/dev/null
        fi

        # Remover regra do firewall, se porta encontrada
        if [ -n "$PORTA" ]; then
            ufw delete allow ${PORTA}/udp 2>/dev/null
            echo "🛑 Porta $PORTA/udp removida do firewall."
        fi

        echo "✅ Rede ethernet$REDE_NUMERO da instância '$INSTANCIA' removida (sem impactar usuários ou certificados)."
    else
        echo "❌ Rede ou instância não encontrada."
    fi
    read -p "Pressione ENTER para continuar..."
}

function excluir_usuario() {
    read -p "Informe o NOME da instância (ex: cliente): " INSTANCIA
    read -p "Informe o NOME do usuário a excluir: " USUARIO

    USUARIO_FULL="${INSTANCIA}-${USUARIO}"

    cd "$EASYRSA_DIR" || exit
    ./easyrsa revoke "$USUARIO_FULL"
    ./easyrsa gen-crl
    cp pki/crl.pem "$OPENVPN_DIR/crl.pem"
    chmod 644 "$OPENVPN_DIR/crl.pem"
    systemctl restart openvpn@*

    rm -f "$EASYRSA_DIR/pki/issued/$USUARIO_FULL.crt"
    rm -f "$EASYRSA_DIR/pki/private/$USUARIO_FULL.key"
    rm -f "$EASYRSA_DIR/pki/reqs/$USUARIO_FULL.req"
    rm -f "$OPENVPN_DIR/$INSTANCIA/ccd/$USUARIO_FULL"
    rm -f "$OVPN_EXPORT_DIR/$USUARIO_FULL.ovpn"

    echo "✅ Usuário '$USUARIO_FULL' revogado e excluído completamente."
    read -p "Pressione ENTER para continuar..."
}

function revogar_usuario() {
    read -p "Informe o NOME do usuário a revogar: " USUARIO
    cd "$EASYRSA_DIR" || exit
    ./easyrsa revoke "$USUARIO"
    ./easyrsa gen-crl
    cp pki/crl.pem "$OPENVPN_DIR/crl.pem"
    chmod 644 "$OPENVPN_DIR/crl.pem"
    systemctl restart openvpn@*
    echo "✅ Usuário '$USUARIO' revogado e CRL atualizada."
    read -p "Pressione ENTER para continuar..."
}

while true; do
    clear
    echo "===== GERENCIADOR OPENVPN - StarUp ====="
    echo "1 - Criar CA (somente uma vez)"
    echo "2 - Criar Cliente/Instância VPN"
    echo "3 - Criar Rede para Cliente/Instância Existente"
    echo "4 - Criar Novo Usuário para Cliente/Instância Existente"
    echo "5 - Listar Redes Existentes"
    echo "6 - Listar Usuários Existentes"
	echo "7 - Excluir Usuário de Cliente/Instância"
	echo "8 - Excluir Rede de Cliente/Instância"
	echo "9 - Excluir Cliente/Instância Inteira"


    echo "0 - Sair"

    read -p "Escolha uma opção: " OPC

    case $OPC in
        1) criar_ca ;;
        2) criar_servidor ;;
        3) criar_rede ;;
        4) criar_usuario ;;
        5) listar_redes ;;
        6) listar_usuarios ;;
		7) excluir_usuario ;;
        8) excluir_rede ;;
        9) excluir_cliente ;;
        0) exit 0 ;;
        *) echo "❌ Opção inválida"; read -p "Pressione ENTER para voltar ao menu..." ;;
    esac
done

