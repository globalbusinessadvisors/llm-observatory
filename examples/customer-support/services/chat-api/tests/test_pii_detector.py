"""Tests for PII detection and redaction."""
import pytest
from pathlib import Path
import tempfile

from pii_detector import PIIDetector
from config import settings


class TestPIIDetector:
    """Tests for PII detector."""

    def setup_method(self):
        """Set up test fixtures."""
        # Use temporary file for audit log
        self.temp_dir = tempfile.mkdtemp()
        settings.pii_audit_log_path = str(Path(self.temp_dir) / "audit.log")
        self.detector = PIIDetector()

    def test_detect_credit_card(self):
        """Test credit card detection."""
        text = "My credit card is 4532-1234-5678-9010"
        result = self.detector.detect_and_redact(text, audit=False)

        assert result.detected
        assert "credit_card" in result.pii_types
        assert "4532" not in result.redacted_text
        assert "*" in result.redacted_text

    def test_detect_ssn(self):
        """Test SSN detection."""
        text = "My SSN is 123-45-6789"
        result = self.detector.detect_and_redact(text, audit=False)

        assert result.detected
        assert "ssn" in result.pii_types
        assert "123-45-6789" not in result.redacted_text

    def test_detect_email(self):
        """Test email detection."""
        text = "Contact me at john.doe@example.com"
        result = self.detector.detect_and_redact(text, audit=False)

        assert result.detected
        assert "email" in result.pii_types
        assert "john.doe@example.com" not in result.redacted_text

    def test_detect_phone(self):
        """Test phone number detection."""
        text = "Call me at (555) 123-4567"
        result = self.detector.detect_and_redact(text, audit=False)

        assert result.detected
        assert "phone" in result.pii_types
        assert "555" not in result.redacted_text or "123" not in result.redacted_text

    def test_detect_multiple_pii(self):
        """Test detection of multiple PII types."""
        text = "My email is test@example.com and my SSN is 123-45-6789"
        result = self.detector.detect_and_redact(text, audit=False)

        assert result.detected
        assert "email" in result.pii_types
        assert "ssn" in result.pii_types
        assert len(result.locations) == 2

    def test_no_pii(self):
        """Test text without PII."""
        text = "This is a normal message without any sensitive information"
        result = self.detector.detect_and_redact(text, audit=False)

        assert not result.detected
        assert len(result.pii_types) == 0
        assert result.redacted_text == text

    def test_validate_redaction(self):
        """Test redaction validation."""
        original = "My email is test@example.com"
        result = self.detector.detect_and_redact(original, audit=False)

        is_valid = self.detector.validate_redaction(original, result.redacted_text)
        assert is_valid

    def test_mask_for_display_credit_card(self):
        """Test partial masking for credit card."""
        card = "4532123456789010"
        masked = self.detector.mask_for_display(card, "credit_card")

        assert masked.endswith("9010")
        assert "*" in masked

    def test_mask_for_display_email(self):
        """Test partial masking for email."""
        email = "john@example.com"
        masked = self.detector.mask_for_display(email, "email")

        assert "@example.com" in masked
        assert "john" not in masked or "*" in masked

    def test_ip_address_detection(self):
        """Test IP address detection."""
        text = "Server IP is 192.168.1.1"
        result = self.detector.detect_and_redact(text, audit=False)

        assert result.detected
        assert "ip_address" in result.pii_types

    def test_redaction_preserves_length(self):
        """Test that redaction preserves text structure."""
        text = "Email: test@example.com and SSN: 123-45-6789"
        result = self.detector.detect_and_redact(text, audit=False)

        # Length should be the same
        assert len(result.redacted_text) == len(text)

    def test_audit_log_writing(self):
        """Test audit log is written when PII detected."""
        text = "My SSN is 123-45-6789"
        result = self.detector.detect_and_redact(text, audit=True)

        # Check audit log file was created
        audit_path = Path(self.detector.audit_log_path)
        assert audit_path.exists()

        # Read audit log
        with open(audit_path, "r") as f:
            content = f.read()
            assert "ssn" in content.lower()
