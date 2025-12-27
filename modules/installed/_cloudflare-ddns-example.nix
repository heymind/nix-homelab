# Example configuration for Cloudflare DDNS
# Add this to your system configuration
{
  installed.cloudflare-ddns = {
    enable = true;

    # Required settings
    domain = "thk6.hey.xlens.space";
    apiToken = "your_cloudflare_api_token_here";
    zoneId = "9b2256c376cd3586421fd815e3ac3c6c";

    # Optional settings
    updateA = true; # Update IPv4 A record
    updateAAAA = true; # Update IPv6 AAAA record
    ipv6Interface = "enp5s0"; # Network interface for IPv6

    ttl = 300; # DNS TTL in seconds
    proxied = false; # Cloudflare proxy (orange cloud)

    interval = "30s"; # Update every 30 seconds
    # Other examples:
    # interval = "5min";     # Update every 5 minutes
    # interval = "1h";       # Update every hour
  };
}
