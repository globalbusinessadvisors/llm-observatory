# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Setup script for LLM Observatory Python SDK."""

from setuptools import setup, find_packages
from pathlib import Path

# Read README for long description
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text(encoding="utf-8") if readme_file.exists() else ""

setup(
    name="llm-observatory",
    version="0.1.0",
    author="LLM Observatory Contributors",
    author_email="info@llm-observatory.io",
    description="High-performance observability SDK for LLM applications",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/llm-observatory/llm-observatory",
    project_urls={
        "Bug Tracker": "https://github.com/llm-observatory/llm-observatory/issues",
        "Documentation": "https://docs.llm-observatory.io",
        "Source Code": "https://github.com/llm-observatory/llm-observatory",
    },
    packages=find_packages(exclude=["tests", "tests.*", "examples", "examples.*"]),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Monitoring",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
    python_requires=">=3.8",
    install_requires=[
        # OpenTelemetry core
        "opentelemetry-api>=1.20.0",
        "opentelemetry-sdk>=1.20.0",
        "opentelemetry-exporter-otlp-proto-grpc>=1.20.0",
        "opentelemetry-semantic-conventions>=0.41b0",

        # Optional dependencies for specific providers
        # These are marked as optional and users install what they need
    ],
    extras_require={
        "openai": [
            "openai>=1.0.0",
        ],
        "anthropic": [
            "anthropic>=0.18.0",
        ],
        "all": [
            "openai>=1.0.0",
            "anthropic>=0.18.0",
        ],
        "dev": [
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
            "pytest-cov>=4.0.0",
            "black>=23.0.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
            "isort>=5.12.0",
        ],
        "docs": [
            "sphinx>=6.0.0",
            "sphinx-rtd-theme>=1.2.0",
            "sphinx-autodoc-typehints>=1.23.0",
        ],
    },
    keywords=[
        "llm",
        "observability",
        "opentelemetry",
        "monitoring",
        "tracing",
        "openai",
        "anthropic",
        "claude",
        "gpt",
        "ai",
        "machine-learning",
    ],
    license="Apache-2.0",
    zip_safe=False,
)
