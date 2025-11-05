#!/usr/bin/env python3
# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
OpenAI streaming example with instrumentation.

This example shows how streaming responses are automatically captured
and traced, including time-to-first-token (TTFT) metrics.
"""

import os
from openai import OpenAI
from llm_observatory import LLMObservatory, instrument_openai


def main():
    # Initialize observatory
    observatory = LLMObservatory(
        service_name="openai-streaming-example",
        otlp_endpoint="http://localhost:4317",
    )

    # Create and instrument OpenAI client
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    instrument_openai(client)

    print("Starting streaming request...")

    # Make a streaming chat completion request
    stream = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "user", "content": "Write a short poem about observability."}
        ],
        stream=True,  # Enable streaming
        max_tokens=200,
    )

    # Process the stream
    print("Response: ", end="", flush=True)
    for chunk in stream:
        if chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="", flush=True)
    print("\n")

    # Streaming telemetry automatically captures:
    # - Time to first token (TTFT)
    # - Individual chunk events
    # - Total streaming time
    # - All standard metrics (tokens, cost, etc.)

    observatory.shutdown()


if __name__ == "__main__":
    main()
