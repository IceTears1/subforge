import re
import logging

logger = logging.getLogger(__name__)

# Region detection patterns
REGION_PATTERNS = {
    "HK": [r"香港", r"hong\s*kong", r"\bhk\b"],
    "TW": [r"台湾", r"台灣", r"\btw\b", r"taiwan"],
    "JP": [r"日本", r"\bjp\b", r"japan", r"东京", r"大阪"],
    "SG": [r"新加坡", r"\bsg\b", r"singapore"],
    "US": [r"美国", r"\bus\b", r"美[国国]", r"united\s*states", r"los\s*angeles", r"new\s*york", r"silicon\s*valley"],
    "KR": [r"韩国", r"\bkr\b", r"korea", r"首尔"],
    "UK": [r"英国", r"\buk\b", r"united\s*kingdom", r"london"],
    "DE": [r"德国", r"\bde\b", r"germany", r"frankfurt"],
    "FR": [r"法国", r"\bfr\b", r"france", r"paris"],
    "CA": [r"加拿大", r"\bca\b", r"canada"],
    "AU": [r"澳大利亚", r"\bau\b", r"australia", r"sydney"],
    "IN": [r"印度", r"\bin\b", r"india", r"mumbai"],
    "RU": [r"俄罗斯", r"\bru\b", r"russia", r"moscow"],
    "BR": [r"巴西", r"\bbr\b", r"brazil"],
    "NL": [r"荷兰", r"\bnl\b", r"netherlands", r"amsterdam"],
}


def detect_region(server: str) -> str:
    """Detect region from server address"""
    server_lower = server.lower()
    for region, patterns in REGION_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, server_lower, re.IGNORECASE):
                return region
    return "OTHER"
