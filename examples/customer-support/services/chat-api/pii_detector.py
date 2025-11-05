"""PII detection and redaction module."""
import re
import logging
from typing import List, Dict, Any, Tuple
from datetime import datetime
from pathlib import Path

from models import PIIDetection
from config import settings


logger = logging.getLogger(__name__)


class PIIDetector:
    """Detects and redacts PII from text."""

    # Regex patterns for different PII types
    PATTERNS = {
        "credit_card": r"\b(?:\d{4}[-\s]?){3}\d{4}\b",
        "ssn": r"\b\d{3}-\d{2}-\d{4}\b",
        "email": r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b",
        "phone": r"\b(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\b",
        "ip_address": r"\b(?:\d{1,3}\.){3}\d{1,3}\b",
        "date_of_birth": r"\b(?:0[1-9]|1[0-2])[/-](?:0[1-9]|[12][0-9]|3[01])[/-](?:19|20)\d{2}\b",
        "passport": r"\b[A-Z]{1,2}\d{6,9}\b",
        "drivers_license": r"\b[A-Z]{1,2}\d{5,8}\b",
        "bank_account": r"\b\d{8,17}\b",
    }

    def __init__(self):
        """Initialize PII detector."""
        self.redaction_char = settings.pii_redaction_char
        self.audit_log_path = Path(settings.pii_audit_log_path)
        self.audit_log_path.parent.mkdir(parents=True, exist_ok=True)

    def detect_and_redact(self, text: str, audit: bool = True) -> PIIDetection:
        """Detect and redact PII from text.

        Args:
            text: Input text to scan
            audit: Whether to log detected PII to audit log

        Returns:
            PIIDetection with redacted text and detection details
        """
        detected_pii = []
        locations = []
        redacted_text = text

        for pii_type, pattern in self.PATTERNS.items():
            matches = list(re.finditer(pattern, text))
            if matches:
                detected_pii.append(pii_type)

                for match in matches:
                    locations.append(
                        {
                            "type": pii_type,
                            "start": match.start(),
                            "end": match.end(),
                            "value": match.group(),
                        }
                    )

        # Redact PII in reverse order to maintain position indices
        for location in sorted(locations, key=lambda x: x["start"], reverse=True):
            start = location["start"]
            end = location["end"]
            length = end - start
            redaction = self.redaction_char * length
            redacted_text = redacted_text[:start] + redaction + redacted_text[end:]

        result = PIIDetection(
            detected=len(detected_pii) > 0,
            redacted_text=redacted_text,
            pii_types=detected_pii,
            locations=locations,
        )

        # Audit log if PII detected
        if result.detected and audit:
            self._audit_log(locations)

        return result

    def _audit_log(self, locations: List[Dict[str, Any]]) -> None:
        """Write PII detection to audit log.

        Args:
            locations: List of detected PII locations
        """
        try:
            with open(self.audit_log_path, "a") as f:
                log_entry = {
                    "timestamp": datetime.utcnow().isoformat(),
                    "detected_types": list(set(loc["type"] for loc in locations)),
                    "count": len(locations),
                }
                f.write(f"{log_entry}\n")
                logger.info(f"PII detection logged: {log_entry}")
        except Exception as e:
            logger.error(f"Failed to write PII audit log: {e}")

    def mask_for_display(self, text: str, pii_type: str) -> str:
        """Partially mask PII for display purposes.

        Args:
            text: Text containing PII
            pii_type: Type of PII to mask

        Returns:
            Partially masked text (e.g., last 4 digits visible)
        """
        if pii_type == "credit_card":
            # Show last 4 digits
            return self.redaction_char * (len(text) - 4) + text[-4:]
        elif pii_type == "ssn":
            # Show last 4 digits
            parts = text.split("-")
            if len(parts) == 3:
                return "***-**-" + parts[-1]
        elif pii_type == "email":
            # Show domain
            parts = text.split("@")
            if len(parts) == 2:
                return self.redaction_char * len(parts[0]) + "@" + parts[1]
        elif pii_type == "phone":
            # Show last 4 digits
            digits = re.sub(r"[^\d]", "", text)
            return self.redaction_char * (len(digits) - 4) + digits[-4:]

        # Default: mask everything
        return self.redaction_char * len(text)

    def validate_redaction(self, original: str, redacted: str) -> bool:
        """Validate that redaction was successful.

        Args:
            original: Original text
            redacted: Redacted text

        Returns:
            True if no PII patterns remain in redacted text
        """
        for pattern in self.PATTERNS.values():
            if re.search(pattern, redacted):
                return False
        return True
