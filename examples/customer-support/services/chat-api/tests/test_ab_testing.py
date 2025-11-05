"""Tests for A/B testing framework."""
import pytest
from datetime import datetime, timedelta

from ab_testing import ABTestingManager
from models import Experiment, ExperimentVariant


class TestABTesting:
    """Tests for A/B testing manager."""

    def setup_method(self):
        """Set up test fixtures."""
        self.manager = ABTestingManager()

    def create_test_experiment(self) -> Experiment:
        """Create a test experiment."""
        variants = [
            ExperimentVariant(
                variant_id="control",
                name="Control",
                provider="openai",
                model="gpt-4",
                temperature=0.7,
            ),
            ExperimentVariant(
                variant_id="variant_a",
                name="Variant A",
                provider="anthropic",
                model="claude-3-sonnet-20240229",
                temperature=0.5,
            ),
        ]

        return Experiment(
            experiment_id="test_exp_1",
            name="Test Experiment",
            description="Testing different providers",
            variants=variants,
            traffic_split={"control": 0.5, "variant_a": 0.5},
            start_date=datetime.utcnow(),
            is_active=True,
        )

    def test_create_experiment(self):
        """Test experiment creation."""
        experiment = self.create_test_experiment()
        success = self.manager.create_experiment(experiment)

        assert success
        assert experiment.experiment_id in self.manager.experiments

    def test_create_experiment_invalid_split(self):
        """Test experiment creation with invalid traffic split."""
        experiment = self.create_test_experiment()
        experiment.traffic_split = {"control": 0.3, "variant_a": 0.5}  # Doesn't sum to 1

        success = self.manager.create_experiment(experiment)
        assert not success

    def test_variant_assignment_deterministic(self):
        """Test that variant assignment is deterministic."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        user_id = "user_123"

        # Assign multiple times
        variant1 = self.manager.assign_variant(experiment.experiment_id, user_id)
        variant2 = self.manager.assign_variant(experiment.experiment_id, user_id)
        variant3 = self.manager.assign_variant(experiment.experiment_id, user_id)

        # Should always get same variant
        assert variant1.variant_id == variant2.variant_id
        assert variant2.variant_id == variant3.variant_id

    def test_variant_assignment_distribution(self):
        """Test that variant assignment follows traffic split."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Assign many users
        assignments = {"control": 0, "variant_a": 0}
        num_users = 1000

        for i in range(num_users):
            variant = self.manager.assign_variant(experiment.experiment_id, f"user_{i}")
            assignments[variant.variant_id] += 1

        # Check distribution is roughly 50/50 (allow 10% deviation)
        control_ratio = assignments["control"] / num_users
        assert 0.4 <= control_ratio <= 0.6

    def test_record_metrics(self):
        """Test recording metrics."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Record some metrics
        self.manager.record_metrics(
            experiment_id=experiment.experiment_id,
            variant_id="control",
            tokens=100,
            cost=0.01,
            latency_ms=500,
            error=False,
        )

        metrics = self.manager.metrics[experiment.experiment_id]["control"]
        assert metrics.total_requests == 1
        assert metrics.total_tokens == 100
        assert metrics.total_cost == 0.01
        assert metrics.avg_latency_ms == 500
        assert metrics.error_rate == 0

    def test_record_multiple_metrics(self):
        """Test recording multiple metrics and averages."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Record multiple requests
        for i in range(5):
            self.manager.record_metrics(
                experiment_id=experiment.experiment_id,
                variant_id="control",
                tokens=100,
                cost=0.01,
                latency_ms=500 + i * 100,
                error=False,
            )

        metrics = self.manager.metrics[experiment.experiment_id]["control"]
        assert metrics.total_requests == 5
        assert metrics.total_tokens == 500
        assert metrics.avg_latency_ms == 700  # Average of 500, 600, 700, 800, 900

    def test_record_satisfaction(self):
        """Test recording satisfaction scores."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Record request first
        self.manager.record_metrics(
            experiment_id=experiment.experiment_id,
            variant_id="control",
            tokens=100,
            cost=0.01,
            latency_ms=500,
            error=False,
        )

        # Record satisfaction
        self.manager.record_satisfaction(
            experiment_id=experiment.experiment_id,
            variant_id="control",
            score=0.8,
        )

        metrics = self.manager.metrics[experiment.experiment_id]["control"]
        assert metrics.user_satisfaction == 0.8

    def test_get_experiment_results(self):
        """Test getting experiment results."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Record some data
        self.manager.record_metrics(
            experiment.experiment_id, "control", 100, 0.01, 500, False
        )
        self.manager.record_metrics(
            experiment.experiment_id, "variant_a", 120, 0.015, 450, False
        )

        results = self.manager.get_experiment_results(experiment.experiment_id)

        assert results["experiment_id"] == experiment.experiment_id
        assert "variants" in results
        assert "control" in results["variants"]
        assert "variant_a" in results["variants"]

    def test_statistical_analysis(self):
        """Test statistical significance analysis."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Record enough data for statistical analysis
        for i in range(50):
            self.manager.record_metrics(
                experiment.experiment_id, "control", 100, 0.01, 500, error=(i % 10 == 0)
            )
            self.manager.record_metrics(
                experiment.experiment_id, "variant_a", 120, 0.015, 450, error=(i % 20 == 0)
            )

        results = self.manager.get_experiment_results(experiment.experiment_id)

        assert "statistical_analysis" in results
        analysis = results["statistical_analysis"]
        assert "control_vs_variant_a" in analysis
        assert analysis["control_vs_variant_a"]["sufficient_data"]

    def test_get_winner(self):
        """Test determining winner."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        # Record data making variant_a clearly better
        for i in range(30):
            self.manager.record_metrics(
                experiment.experiment_id, "control", 100, 0.01, 800, error=True
            )
            self.manager.record_metrics(
                experiment.experiment_id, "variant_a", 100, 0.01, 400, error=False
            )

        winner = self.manager.get_winner(experiment.experiment_id)
        assert winner == "variant_a"

    def test_stop_experiment(self):
        """Test stopping experiment."""
        experiment = self.create_test_experiment()
        self.manager.create_experiment(experiment)

        assert experiment.is_active

        self.manager.stop_experiment(experiment.experiment_id)
        assert not self.manager.experiments[experiment.experiment_id].is_active

    def test_list_experiments(self):
        """Test listing experiments."""
        experiment1 = self.create_test_experiment()
        experiment2 = self.create_test_experiment()
        experiment2.experiment_id = "test_exp_2"

        self.manager.create_experiment(experiment1)
        self.manager.create_experiment(experiment2)

        experiments = self.manager.list_experiments()
        assert len(experiments) == 2

    def test_inactive_experiment_no_assignment(self):
        """Test that inactive experiments don't assign variants."""
        experiment = self.create_test_experiment()
        experiment.is_active = False
        self.manager.create_experiment(experiment)

        variant = self.manager.assign_variant(experiment.experiment_id, "user_123")
        assert variant is None
