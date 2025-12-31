#!/bin/bash
set -euo pipefail

# ==============================
# Configurable Variables
# ==============================

export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_REGION=""

OPENVPN_DIR="/opt/openvpn"
OVPN_TYPE="docker-compose"
ENV="" # Staging or Prod or Local
EMAILS="a@eample.com, b@example.com"

SES_FROM=""
SES_REGION=""   # change if different
TMP_DIR="/tmp/vpn-users"
mkdir -p $TMP_DIR

# ==============================
# Helper Functions
# ==============================

validate_and_extract_user() {
    local email="$1"

    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@example\.com$ ]]; then
        echo "❌ Error: Only @example.com emails are allowed."
        exit 1
    fi

    local user="${email%@example.com}"   # remove domain
    user="${user%@}"                   # clean any trailing '@'
    echo "$user"
}

send_email() {
    local to="$1"
    local file="$2"
    local user="$3"

    echo "Sending VPN credentials to $to ..."

    tmpmime=$(mktemp)
    boundary="NextPart$(date +%s)"

    # Build MIME email
    {
        echo "From: $SES_FROM"
        echo "To: $to"
        echo "Cc: $EMAILS"
        echo "Subject: [$ENV VPN] Credentials for $user"
        echo "MIME-Version: 1.0"
        echo "Content-Type: multipart/mixed; boundary=\"$boundary\""
        echo
        echo "--$boundary"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo
        echo "Hi $user,

Attached are your $ENV VPN credentials (.ovpn file).
Save it and import it into your OpenVPN client.

Regards,
DevOps Team"
        echo
        echo "--$boundary"
        echo "Content-Type: application/octet-stream; name=\"$user.ovpn\""
        echo "Content-Disposition: attachment; filename=\"$user.ovpn\""
        echo "Content-Transfer-Encoding: base64"
        echo
        base64 "$file"
        echo "--$boundary--"
    } > "$tmpmime"

    # Wrap in JSON for AWS CLI
    tmpjson=$(mktemp)
    echo "{\"Data\":\"$(base64 -w0 "$tmpmime")\"}" > "$tmpjson"

    # Send via SES
    aws ses send-raw-email \
      --region "$SES_REGION" \
      --raw-message file://"$tmpjson"

    rm -f "$tmpmime" "$tmpjson"
    echo "✅ Email with VPN credentials sent to $to"
}


create_user() {
    local email="$1"
    local user

    user=$(validate_and_extract_user "$email")

    local ovpn_file="$TMP_DIR/$user.ovpn"

    echo "Creating VPN user: $user ..."

    cd $OPENVPN_DIR
    docker-compose run --rm openvpn easyrsa build-client-full "$user" nopass
    docker-compose run --rm openvpn ovpn_getclient "$user" > "$ovpn_file"

    echo "User $user created. Config saved to $ovpn_file"
    send_email "$email" "$ovpn_file" "$user"
}

delete_user() {
    local email="$1"
    local user
    user=$(validate_and_extract_user "$email")

    echo "Revoking VPN user: $user ..."

    if [[ "$OVPN_TYPE" == "docker" ]]; then
        docker-compose run --rm openvpn ovpn_revokeclient "$user" remove
    elif [[ "$OVPN_TYPE" == "docker-compose" ]]; then
        cd $OPENVPN_DIR
        docker-compose run --rm openvpn ovpn_revokeclient "$user" remove
    fi

    echo "User $user revoked."
}

list_users() {
    echo "📋 Existing VPN users:"
    cd $OPENVPN_DIR
    docker-compose run --rm openvpn bash -c "ls /etc/openvpn/pki/issued/*.crt 2>/dev/null | xargs -n1 basename | sed 's/\.crt//'" || true
}


# ==============================
# Main
# ==============================
if [[ $# -lt 1 ]]; then
    echo "Usage:"
    echo "  $0 create <email>"
    echo "  $0 delete <email>"
    echo "  $0 list"
    exit 1
fi

action="$1"

case "$action" in
    create)
        if [[ $# -ne 2 ]]; then
            echo "Usage: $0 create <email>"
            exit 1
        fi
        create_user "$2"
        ;;
    delete)
        if [[ $# -ne 2 ]]; then
            echo "Usage: $0 delete <email>"
            exit 1
        fi
        delete_user "$2"
        ;;
    list)
        list_users
        ;;
    *)
        echo "Unknown action: $action"
        exit 1
        ;;
esac