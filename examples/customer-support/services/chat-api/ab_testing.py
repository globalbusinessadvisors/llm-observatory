"""A/B testing framework for experimentation."""
import hashlib
import logging
from typing import Dict, Optional, List
from datetime import datetime
from collections import defaultdict

import numpy as np
from scipy import stats

from models import Experiment, ExperimentVariant, ExperimentMetrics
from config import settings


logger = logging.getLogger(__name__)


class ABTestingManager:
    """Manages A/B testing experiments."""

    def __init__(self):
        """Initialize A/B testing manager."""
        self.experiments: Dict[str, Experiment] = {}
        self.metrics: Dict[str, Dict[str, ExperimentMetrics]] = defaultdict(dict)
        self.salt = settings.ab_test_salt

    def create_experiment(self, experiment: Experiment) -> bool:
        """Create a new experiment.

        Args:
            experiment: Experiment configuration

        Returns:
            True if created successfully
        """
        # Validate traffic split
        total_traffic = sum(experiment.traffic_split.values())
        if not (0.99 <= total_traffic <= 1.01):
            logger.error(f"Invalid traffic split: {total_traffic}")
            return False

        # Validate variants match traffic split
        variant_ids = {v.variant_id for v in experiment.variants}
        split_ids = set(experiment.traffic_split.keys())

        if variant_ids != split_ids:
            logger.error("Variant IDs don't match traffic split keys")
            return False

        self.experiments[experiment.experiment_id] = experiment

        # Initialize metrics for each variant
        for variant in experiment.variants:
            self.metrics[experiment.experiment_id][variant.variant_id] = (
                ExperimentMetrics(variant_id=variant.variant_id)
            )

        logger.info(f"Created experiment: {experiment.experiment_id}")
        return True

    def assign_variant(
        self, experiment_id: str, user_id: str
    ) -> Optional[ExperimentVariant]:
        """Deterministically assign user to a variant.

        Args:
            experiment_id: Experiment identifier
            user_id: User identifier

        Returns:
            Assigned ExperimentVariant or None if experiment not found
        """
        if experiment_id not in self.experiments:
            logger.warning(f"Experiment not found: {experiment_id}")
            return None

        experiment = self.experiments[experiment_id]

        if not experiment.is_active:
            logger.info(f"Experiment {experiment_id} is not active")
            return None

        # Check date range
        now = datetime.utcnow()
        if experiment.end_date and now > experiment.end_date:
            logger.info(f"Experiment {experiment_id} has ended")
            return None

        # Deterministic assignment using hash
        hash_input = f"{experiment_id}:{user_id}:{self.salt}"
        hash_value = hashlib.sha256(hash_input.encode()).hexdigest()
        hash_int = int(hash_value[:16], 16)
        random_value = (hash_int % 10000) / 10000.0  # 0.0 to 1.0

        # Assign based on traffic split
        cumulative = 0.0
        for variant in experiment.variants:
            cumulative += experiment.traffic_split[variant.variant_id]
            if random_value < cumulative:
                logger.debug(
                    f"User {user_id} assigned to variant {variant.variant_id} "
                    f"in experiment {experiment_id}"
                )
                return variant

        # Fallback to first variant
        return experiment.variants[0]

    def record_metrics(
        self,
        experiment_id: str,
        variant_id: str,
        tokens: int,
        cost: float,
        latency_ms: float,
        error: bool = False,
    ):
        """Record metrics for a variant.

        Args:
            experiment_id: Experiment identifier
            variant_id: Variant identifier
            tokens: Token count
            cost: Cost in USD
            latency_ms: Latency in milliseconds
            error: Whether request resulted in error
        """
        if experiment_id not in self.metrics:
            logger.warning(f"No metrics found for experiment: {experiment_id}")
            return

        if variant_id not in self.metrics[experiment_id]:
            logger.warning(
                f"No metrics found for variant {variant_id} "
                f"in experiment {experiment_id}"
            )
            return

        metrics = self.metrics[experiment_id][variant_id]

        # Update running averages
        n = metrics.total_requests
        metrics.total_requests += 1
        metrics.total_tokens += tokens
        metrics.total_cost += cost

        # Update average latency (running average)
        metrics.avg_latency_ms = (metrics.avg_latency_ms * n + latency_ms) / (n + 1)

        # Update error rate (running average)
        error_count = metrics.error_rate * n + (1 if error else 0)
        metrics.error_rate = error_count / (n + 1)

    def record_satisfaction(
        self, experiment_id: str, variant_id: str, score: float
    ):
        """Record user satisfaction score.

        Args:
            experiment_id: Experiment identifier
            variant_id: Variant identifier
            score: Satisfaction score (0.0 to 1.0)
        """
        if experiment_id not in self.metrics:
            return

        if variant_id not in self.metrics[experiment_id]:
            return

        metrics = self.metrics[experiment_id][variant_id]

        # Update running average
        if metrics.user_satisfaction is None:
            metrics.user_satisfaction = score
        else:
            n = metrics.total_requests
            metrics.user_satisfaction = (
                metrics.user_satisfaction * (n - 1) + score
            ) / n

    def get_experiment_results(self, experiment_id: str) -> Dict:
        """Get results for an experiment.

        Args:
            experiment_id: Experiment identifier

        Returns:
            Dictionary with experiment results
        """
        if experiment_id not in self.experiments:
            return {"error": "Experiment not found"}

        experiment = self.experiments[experiment_id]
        variant_metrics = self.metrics[experiment_id]

        results = {
            "experiment_id": experiment_id,
            "name": experiment.name,
            "is_active": experiment.is_active,
            "variants": {},
        }

        for variant_id, metrics in variant_metrics.items():
            results["variants"][variant_id] = {
                "variant_id": variant_id,
                "total_requests": metrics.total_requests,
                "total_tokens": metrics.total_tokens,
                "total_cost": metrics.total_cost,
                "avg_latency_ms": metrics.avg_latency_ms,
                "error_rate": metrics.error_rate,
                "user_satisfaction": metrics.user_satisfaction,
                "cost_per_request": (
                    metrics.total_cost / metrics.total_requests
                    if metrics.total_requests > 0
                    else 0
                ),
            }

        # Add statistical significance tests
        results["statistical_analysis"] = self._analyze_significance(experiment_id)

        return results

    def _analyze_significance(self, experiment_id: str) -> Dict:
        """Perform statistical significance tests.

        Args:
            experiment_id: Experiment identifier

        Returns:
            Dictionary with statistical analysis
        """
        if experiment_id not in self.metrics:
            return {}

        variant_metrics = self.metrics[experiment_id]
        variants = list(variant_metrics.keys())

        if len(variants) < 2:
            return {"error": "Need at least 2 variants for comparison"}

        # Compare first variant (control) with others
        control_id = variants[0]
        control = variant_metrics[control_id]

        analyses = {}

        for variant_id in variants[1:]:
            variant = variant_metrics[variant_id]

            # Minimum sample size check
            if control.total_requests < 30 or variant.total_requests < 30:
                analyses[f"{control_id}_vs_{variant_id}"] = {
                    "sufficient_data": False,
                    "message": "Need at least 30 samples per variant",
                }
                continue

            # Compare error rates using proportion z-test
            n1, n2 = control.total_requests, variant.total_requests
            p1, p2 = control.error_rate, variant.error_rate

            # Pooled proportion
            p_pool = (p1 * n1 + p2 * n2) / (n1 + n2)
            se = np.sqrt(p_pool * (1 - p_pool) * (1 / n1 + 1 / n2))

            if se > 0:
                z_score = (p1 - p2) / se
                p_value = 2 * (1 - stats.norm.cdf(abs(z_score)))
            else:
                z_score = 0
                p_value = 1.0

            # Compare latency using t-test (simplified, assumes normal distribution)
            # In production, you'd store individual latencies
            latency_significant = abs(control.avg_latency_ms - variant.avg_latency_ms) > 50

            analyses[f"{control_id}_vs_{variant_id}"] = {
                "sufficient_data": True,
                "error_rate_comparison": {
                    "control_error_rate": p1,
                    "variant_error_rate": p2,
                    "z_score": float(z_score),
                    "p_value": float(p_value),
                    "significant": p_value < 0.05,
                },
                "latency_comparison": {
                    "control_latency_ms": control.avg_latency_ms,
                    "variant_latency_ms": variant.avg_latency_ms,
                    "difference_ms": variant.avg_latency_ms - control.avg_latency_ms,
                    "practically_significant": latency_significant,
                },
                "cost_comparison": {
                    "control_cost_per_request": (
                        control.total_cost / control.total_requests
                        if control.total_requests > 0
                        else 0
                    ),
                    "variant_cost_per_request": (
                        variant.total_cost / variant.total_requests
                        if variant.total_requests > 0
                        else 0
                    ),
                },
            }

        return analyses

    def get_winner(self, experiment_id: str) -> Optional[str]:
        """Determine winning variant based on metrics.

        Args:
            experiment_id: Experiment identifier

        Returns:
            Variant ID of winner or None
        """
        results = self.get_experiment_results(experiment_id)

        if "error" in results:
            return None

        # Simple scoring: lower error rate, lower latency, higher satisfaction
        best_variant = None
        best_score = float("-inf")

        for variant_id, metrics in results["variants"].items():
            # Weighted score (adjust weights as needed)
            score = (
                (1 - metrics["error_rate"]) * 0.4
                + (1 - min(metrics["avg_latency_ms"] / 5000, 1)) * 0.3
                + (metrics.get("user_satisfaction", 0.5) or 0.5) * 0.3
            )

            if score > best_score:
                best_score = score
                best_variant = variant_id

        return best_variant

    def stop_experiment(self, experiment_id: str):
        """Stop an experiment.

        Args:
            experiment_id: Experiment identifier
        """
        if experiment_id in self.experiments:
            self.experiments[experiment_id].is_active = False
            logger.info(f"Stopped experiment: {experiment_id}")

    def list_experiments(self) -> List[Dict]:
        """List all experiments with their status.

        Returns:
            List of experiment summaries
        """
        summaries = []

        for exp_id, experiment in self.experiments.items():
            total_requests = sum(
                m.total_requests for m in self.metrics[exp_id].values()
            )

            summaries.append(
                {
                    "experiment_id": exp_id,
                    "name": experiment.name,
                    "is_active": experiment.is_active,
                    "num_variants": len(experiment.variants),
                    "total_requests": total_requests,
                    "start_date": experiment.start_date.isoformat(),
                    "end_date": (
                        experiment.end_date.isoformat() if experiment.end_date else None
                    ),
                }
            )

        return summaries
