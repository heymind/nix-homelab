#!/usr/bin/env bash

# Cloudflare DDNS Script
# Updates A and AAAA records for a domain using Cloudflare API
# Configuration through environment variables

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

show_help() {
    cat << 'EOF'
Cloudflare DDNS Script

DESCRIPTION
    Automatically updates Cloudflare DNS records (A and AAAA) for dynamic IP addresses.
    Configuration is done entirely through environment variables.

USAGE
    source config.env && ./cloudflare-ddns.bash

    Or set environment variables manually:
    export CF_API_TOKEN="your_token"
    export CF_ZONE_ID="your_zone_id"
    export CF_DOMAIN="ddns.example.com"
    ./cloudflare-ddns.bash

OPTIONS
    -h, --help      Show this help message and exit

REQUIRED ENVIRONMENT VARIABLES
    CF_API_TOKEN    Cloudflare API token with DNS edit permissions
                    Get it from: https://dash.cloudflare.com/profile/api-tokens
                    
    CF_ZONE_ID      Cloudflare Zone ID for your domain
                    Find it in your domain's overview page
                    
    CF_DOMAIN       Full domain name to update (e.g., ddns.example.com)

OPTIONAL ENVIRONMENT VARIABLES
    CF_UPDATE_A         Update A record (IPv4)
                        Values: true, false
                        Default: true
                        
    CF_UPDATE_AAAA      Update AAAA record (IPv6)
                        Values: true, false
                        Default: true
                        
    CF_IPV6_INTERFACE   Network interface name for IPv6 address
                        Required when CF_UPDATE_AAAA=true
                        Examples: eth0, ens3, enp5s0 (Linux), en0 (macOS)
                        Use 'ip addr' or 'ifconfig' to list interfaces
                        
    CF_TTL              DNS record TTL in seconds
                        Default: 300
                        
    CF_PROXIED          Enable Cloudflare proxy (orange cloud)
                        Values: true, false
                        Default: false

HOW IT WORKS
    IPv4 (A Record):
        - Fetches public IPv4 from https://myip.ipip.net
        
    IPv6 (AAAA Record):
        - Extracts IPv6 from specified network interface
        - Automatically selects permanent address (non-privacy extension)
        - Excludes temporary, deprecated, and link-local addresses

EXAMPLES
    1. Update both IPv4 and IPv6:
        export CF_API_TOKEN="your_token"
        export CF_ZONE_ID="your_zone_id"
        export CF_DOMAIN="home.example.com"
        export CF_IPV6_INTERFACE="eth0"
        ./cloudflare-ddns.bash

    2. Update only IPv4:
        export CF_API_TOKEN="your_token"
        export CF_ZONE_ID="your_zone_id"
        export CF_DOMAIN="home.example.com"
        export CF_UPDATE_AAAA="false"
        ./cloudflare-ddns.bash

    3. Update only IPv6:
        export CF_API_TOKEN="your_token"
        export CF_ZONE_ID="your_zone_id"
        export CF_DOMAIN="home.example.com"
        export CF_UPDATE_A="false"
        export CF_IPV6_INTERFACE="eth0"
        ./cloudflare-ddns.bash

CRON SETUP
    Run every 5 minutes:
    */5 * * * * source /etc/cloudflare-ddns.env && /usr/local/bin/cloudflare-ddns.bash >> /var/log/cloudflare-ddns.log 2>&1

SYSTEMD TIMER SETUP
    1. Create service file: /etc/systemd/system/cloudflare-ddns.service
       [Unit]
       Description=Cloudflare DDNS Update
       After=network-online.target
       
       [Service]
       Type=oneshot
       EnvironmentFile=/etc/cloudflare-ddns.env
       ExecStart=/usr/local/bin/cloudflare-ddns.bash

    2. Create timer file: /etc/systemd/system/cloudflare-ddns.timer
       [Unit]
       Description=Cloudflare DDNS Update Timer
       
       [Timer]
       OnBootSec=1min
       OnUnitActiveSec=5min
       
       [Install]
       WantedBy=timers.target

    3. Enable and start:
       systemctl enable --now cloudflare-ddns.timer

DEPENDENCIES
    - bash
    - curl
    - grep, awk, cut
    - ip (Linux) or ifconfig (macOS/BSD)

EXIT CODES
    0    Success
    1    Failure (check error messages)

AUTHOR
    Created for automated Cloudflare DDNS updates

EOF
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $arg"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

set -euo pipefail

# Check required environment variables
if [[ -z "${CF_API_TOKEN:-}" ]]; then
    log_error "CF_API_TOKEN is not set"
    exit 1
fi

if [[ -z "${CF_ZONE_ID:-}" ]]; then
    log_error "CF_ZONE_ID is not set"
    exit 1
fi

if [[ -z "${CF_DOMAIN:-}" ]]; then
    log_error "CF_DOMAIN is not set"
    exit 1
fi

# Set defaults
CF_UPDATE_A="${CF_UPDATE_A:-true}"
CF_UPDATE_AAAA="${CF_UPDATE_AAAA:-true}"
CF_TTL="${CF_TTL:-300}"
CF_PROXIED="${CF_PROXIED:-false}"

# Cloudflare API endpoint
CF_API="https://api.cloudflare.com/client/v4"

# Get IPv4 address
get_ipv4() {
    local ipv4
    ipv4=$(curl -s -4 https://myip.ipip.net | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    if [[ -z "$ipv4" ]]; then
        log_error "Failed to get IPv4 address"
        return 1
    fi
    echo "$ipv4"
}

# Get IPv6 address from network interface
# Extracts non-privacy IPv6 address (permanent address, not temporary privacy extension)
get_ipv6() {
    local interface="$1"
    local ipv6
    
    if [[ -z "$interface" ]]; then
        log_error "Network interface not specified"
        return 1
    fi
    
    # Check if interface exists
    if ! ip addr show "$interface" &>/dev/null && ! ifconfig "$interface" &>/dev/null; then
        log_error "Network interface '$interface' not found"
        return 1
    fi
    
    # Try to get IPv6 address using ip command (Linux)
    if command -v ip &>/dev/null; then
        # Get global IPv6 addresses, excluding temporary/privacy addresses
        # Look for 'scope global' and exclude 'temporary' or 'deprecated'
        ipv6=$(ip -6 addr show "$interface" scope global | \
               grep -v temporary | \
               grep -v deprecated | \
               grep inet6 | \
               awk '{print $2}' | \
               cut -d/ -f1 | \
               head -1)
    # Fallback to ifconfig (macOS and other systems)
    elif command -v ifconfig &>/dev/null; then
        # On macOS, get IPv6 addresses and filter out temporary ones
        # Temporary addresses often have specific flags or patterns
        ipv6=$(ifconfig "$interface" | \
               grep -i 'inet6' | \
               grep -v -i 'temporary\|deprecated\|fe80:' | \
               grep -i 'secured' | \
               awk '{print $2}' | \
               head -1)
        
        # If no "secured" address found, get any global address
        if [[ -z "$ipv6" ]]; then
            ipv6=$(ifconfig "$interface" | \
                   grep -i 'inet6' | \
                   grep -v -i 'fe80:\|temporary\|deprecated' | \
                   awk '{print $2}' | \
                   head -1)
        fi
    else
        log_error "Neither 'ip' nor 'ifconfig' command found"
        return 1
    fi
    
    if [[ -z "$ipv6" ]]; then
        log_error "Failed to get IPv6 address from interface '$interface'"
        return 1
    fi
    
    echo "$ipv6"
}

# Resolve DNS record using local DNS
resolve_dns() {
    local record_type="$1"
    local domain="${CF_DOMAIN}"
    local resolved=""
    
    # Try using dig first (more reliable)
    if command -v dig &>/dev/null; then
        resolved=$(dig +short "$domain" "$record_type" @1.1.1.1 2>/dev/null | head -1)
    # Fallback to host
    elif command -v host &>/dev/null; then
        if [[ "$record_type" == "A" ]]; then
            resolved=$(host -t A "$domain" 1.1.1.1 2>/dev/null | grep "has address" | awk '{print $4}' | head -1)
        elif [[ "$record_type" == "AAAA" ]]; then
            resolved=$(host -t AAAA "$domain" 1.1.1.1 2>/dev/null | grep "has IPv6 address" | awk '{print $5}' | head -1)
        fi
    # Fallback to nslookup
    elif command -v nslookup &>/dev/null; then
        if [[ "$record_type" == "A" ]]; then
            resolved=$(nslookup -type=A "$domain" 1.1.1.1 2>/dev/null | grep "^Address:" | tail -1 | awk '{print $2}')
        elif [[ "$record_type" == "AAAA" ]]; then
            resolved=$(nslookup -type=AAAA "$domain" 1.1.1.1 2>/dev/null | grep "^Address:" | tail -1 | awk '{print $2}')
        fi
    fi
    
    echo "$resolved"
}

# Get DNS record ID and content from Cloudflare API
get_record_id() {
    local record_type="$1"
    local response
    
    response=$(curl -s -X GET "${CF_API}/zones/${CF_ZONE_ID}/dns_records?type=${record_type}&name=${CF_DOMAIN}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    local record_id
    record_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo "$record_id"
}

# Get current DNS record content from Cloudflare API
get_cloudflare_record() {
    local record_type="$1"
    local response
    
    response=$(curl -s -X GET "${CF_API}/zones/${CF_ZONE_ID}/dns_records?type=${record_type}&name=${CF_DOMAIN}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")
    
    local content
    content=$(echo "$response" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo "$content"
}

# Create or update DNS record
update_dns_record() {
    local record_type="$1"
    local ip_address="$2"
    local record_id
    local current_content
    
    log_info "Checking $record_type record for $CF_DOMAIN..."
    
    # Get current record from Cloudflare API
    current_content=$(get_cloudflare_record "$record_type")
    
    if [[ -n "$current_content" ]]; then
        log_info "Current $record_type record in Cloudflare: $current_content"
        if [[ "$current_content" == "$ip_address" ]]; then
            log_info "✓ $record_type record is already up-to-date, skipping update"
            return 0
        fi
        log_info "Record needs update: $current_content → $ip_address"
    else
        log_info "No existing $record_type record found, will create new one"
    fi
    
    log_info "Updating $record_type record for $CF_DOMAIN to $ip_address"
    
    record_id=$(get_record_id "$record_type")
    
    local json_data
    json_data=$(cat <<EOF
{
  "type": "$record_type",
  "name": "$CF_DOMAIN",
  "content": "$ip_address",
  "ttl": $CF_TTL,
  "proxied": $CF_PROXIED
}
EOF
)
    
    local response
    local method
    local url
    
    if [[ -n "$record_id" ]]; then
        # Update existing record
        method="PUT"
        url="${CF_API}/zones/${CF_ZONE_ID}/dns_records/${record_id}"
        log_info "Updating existing $record_type record (ID: $record_id)"
    else
        # Create new record
        method="POST"
        url="${CF_API}/zones/${CF_ZONE_ID}/dns_records"
        log_info "Creating new $record_type record"
    fi
    
    response=$(curl -s -X "$method" "$url" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$json_data")
    
    # Check if successful
    if echo "$response" | grep -q '"success":true'; then
        log_info "Successfully updated $record_type record"
        return 0
    else
        log_error "Failed to update $record_type record"
        log_error "Response: $response"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting Cloudflare DDNS update for domain: $CF_DOMAIN"
    
    local exit_code=0
    local needs_update=false
    
    # Pre-check: Resolve DNS records locally first
    log_info "Pre-check: Resolving DNS records..."
    
    # Update A record
    if [[ "$CF_UPDATE_A" == "true" ]]; then
        log_info "Fetching IPv4 address..."
        if ipv4=$(get_ipv4); then
            log_info "Current IPv4: $ipv4"
            
            # Check DNS resolution
            local resolved_a
            resolved_a=$(resolve_dns "A")
            if [[ -n "$resolved_a" ]]; then
                log_info "DNS resolved A record: $resolved_a"
                if [[ "$resolved_a" == "$ipv4" ]]; then
                    log_info "✓ DNS A record matches current IPv4, checking Cloudflare API..."
                else
                    log_info "DNS A record differs from current IPv4, will check Cloudflare API"
                    needs_update=true
                fi
            else
                log_warn "Could not resolve A record via DNS, will check Cloudflare API"
                needs_update=true
            fi
            
            # Proceed to update (which includes API check)
            if update_dns_record "A" "$ipv4"; then
                log_info "A record processing completed"
            else
                log_error "A record update failed"
                exit_code=1
            fi
        else
            log_error "Could not retrieve IPv4 address"
            exit_code=1
        fi
    else
        log_info "Skipping A record update (CF_UPDATE_A=false)"
    fi
    
    # Update AAAA record
    if [[ "$CF_UPDATE_AAAA" == "true" ]]; then
        if [[ -z "${CF_IPV6_INTERFACE:-}" ]]; then
            log_error "CF_IPV6_INTERFACE is not set but CF_UPDATE_AAAA=true"
            exit_code=1
        else
            log_info "Fetching IPv6 address from interface: $CF_IPV6_INTERFACE..."
            if ipv6=$(get_ipv6 "$CF_IPV6_INTERFACE"); then
                log_info "Current IPv6: $ipv6"
                
                # Check DNS resolution
                local resolved_aaaa
                resolved_aaaa=$(resolve_dns "AAAA")
                if [[ -n "$resolved_aaaa" ]]; then
                    log_info "DNS resolved AAAA record: $resolved_aaaa"
                    if [[ "$resolved_aaaa" == "$ipv6" ]]; then
                        log_info "✓ DNS AAAA record matches current IPv6, checking Cloudflare API..."
                    else
                        log_info "DNS AAAA record differs from current IPv6, will check Cloudflare API"
                        needs_update=true
                    fi
                else
                    log_warn "Could not resolve AAAA record via DNS, will check Cloudflare API"
                    needs_update=true
                fi
                
                # Proceed to update (which includes API check)
                if update_dns_record "AAAA" "$ipv6"; then
                    log_info "AAAA record processing completed"
                else
                    log_error "AAAA record update failed"
                    exit_code=1
                fi
            else
                log_error "Could not retrieve IPv6 address"
                exit_code=1
            fi
        fi
    else
        log_info "Skipping AAAA record update (CF_UPDATE_AAAA=false)"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "DDNS update completed successfully"
    else
        log_error "DDNS update completed with errors"
    fi
    
    return $exit_code
}

# Run main function
main

