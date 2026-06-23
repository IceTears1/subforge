import re
import ipaddress
import logging
from urllib.parse import urlparse

logger = logging.getLogger(__name__)

# Private/reserved IP ranges that should not be accessed
PRIVATE_NETWORKS = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),  # link-local / cloud metadata
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),  # IPv6 private
    ipaddress.ip_network("fe80::/10"),  # IPv6 link-local
]


def is_safe_url(url: str) -> bool:
    """
    Validate that a URL is safe to fetch (no SSRF).
    Blocks private IPs, localhost, cloud metadata endpoints, etc.
    """
    try:
        parsed = urlparse(url)
    except Exception:
        return False

    # Only allow http/https
    if parsed.scheme not in ("http", "https"):
        logger.warning(f"SSRF blocked: invalid scheme '{parsed.scheme}' in {url}")
        return False

    hostname = parsed.hostname
    if not hostname:
        logger.warning(f"SSRF blocked: no hostname in {url}")
        return False

    # Block common metadata endpoints by hostname
    metadata_hosts = {
        "169.254.169.254",  # AWS/GCP/Azure metadata
        "metadata.google.internal",  # GCP metadata
        "instance-data",  # EC2 metadata (older)
        "100.100.100.200",  # Alibaba Cloud metadata
    }
    if hostname in metadata_hosts:
        logger.warning(f"SSRF blocked: metadata endpoint '{hostname}' in {url}")
        return False

    # Check if hostname resolves to a private IP
    try:
        ip = ipaddress.ip_address(hostname)
        for network in PRIVATE_NETWORKS:
            if ip in network:
                logger.warning(f"SSRF blocked: private IP '{hostname}' in {url}")
                return False
    except ValueError:
        # hostname is not an IP literal - check for localhost variants
        local_hosts = {"localhost", "0.0.0.0", "::", "local", "localdomain", "broadcasthost"}
        if hostname.lower() in local_hosts:
            logger.warning(f"SSRF blocked: local hostname '{hostname}' in {url}")
            return False

    return True


def sanitize_url_for_log(url: str) -> str:
    """Remove credentials from URL for safe logging"""
    try:
        parsed = urlparse(url)
        if parsed.password or parsed.username:
            # Rebuild without credentials
            netloc = parsed.hostname or ""
            if parsed.port:
                netloc += f":{parsed.port}"
            return parsed._replace(netloc=netloc).geturl()
    except Exception:
        pass
    return url
