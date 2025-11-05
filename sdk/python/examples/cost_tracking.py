#!/usr/bin/env python3
# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Cost tracking example.

This example shows how to use the CostCalculator to estimate and
track LLM costs across different models.
"""

from llm_observatory.cost import CostCalculator


def main():
    # Create cost calculator
    calculator = CostCalculator()

    # Example token usage
    prompt_tokens = 1000
    completion_tokens = 500

    print("Cost Comparison for 1000 prompt + 500 completion tokens:\n")

    # Compare costs across different models
    models = [
        "gpt-4",
        "gpt-4-turbo",
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-3.5-turbo",
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307",
        "gemini-1.5-pro",
        "gemini-1.5-flash",
    ]

    results = []
    for model in models:
        cost = calculator.calculate_cost(model, prompt_tokens, completion_tokens)
        if cost is not None:
            results.append((model, cost))

    # Sort by cost
    results.sort(key=lambda x: x[1])

    # Display results
    for model, cost in results:
        print(f"{model:40s} ${cost:.6f}")

    # Calculate cost breakdown for a specific model
    print("\n\nDetailed breakdown for GPT-4:")
    breakdown = calculator.calculate_cost_breakdown(
        "gpt-4",
        prompt_tokens,
        completion_tokens
    )
    if breakdown:
        prompt_cost, completion_cost, total_cost = breakdown
        print(f"  Prompt cost:     ${prompt_cost:.6f}")
        print(f"  Completion cost: ${completion_cost:.6f}")
        print(f"  Total cost:      ${total_cost:.6f}")

    # Estimate cost at scale
    print("\n\nCost at scale (1 million requests):")
    monthly_requests = 1_000_000
    for model in ["gpt-4o", "gpt-4o-mini", "claude-3-haiku-20240307"]:
        cost_per_request = calculator.calculate_cost(model, prompt_tokens, completion_tokens)
        if cost_per_request:
            monthly_cost = cost_per_request * monthly_requests
            print(f"  {model:40s} ${monthly_cost:,.2f}/month")


if __name__ == "__main__":
    main()
