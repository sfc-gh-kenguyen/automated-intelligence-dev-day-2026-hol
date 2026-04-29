"""
Tests for exponential backoff + jitter in both retry layers:
  - Inner: SnowpipeStreamingManager._insert_with_backpressure_retry
  - Outer: AutomatedIntelligenceStreaming.generate_and_stream_orders

Runs without the snowflake-ingest SDK installed by stubbing the module tree.
"""

import sys
import os
import types
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub the snowflake.ingest.* module tree so src/ imports resolve without the SDK
# ---------------------------------------------------------------------------
_snowflake = types.ModuleType("snowflake")
_snowflake.__path__ = []
_ingest = types.ModuleType("snowflake.ingest")
_ingest.__path__ = []
_streaming = types.ModuleType("snowflake.ingest.streaming")
_streaming.__path__ = []
_error_mod = types.ModuleType("snowflake.ingest.streaming.streaming_ingest_error")


class StreamingIngestError(Exception):
    """Stub matching the real SDK exception."""
    pass


_error_mod.StreamingIngestError = StreamingIngestError
_streaming.StreamingIngestClient = MagicMock
_streaming.StreamingIngestChannel = MagicMock
_streaming.streaming_ingest_error = _error_mod

for mod_name, mod_obj in [
    ("snowflake", _snowflake),
    ("snowflake.ingest", _ingest),
    ("snowflake.ingest.streaming", _streaming),
    ("snowflake.ingest.streaming.streaming_ingest_error", _error_mod),
]:
    sys.modules.setdefault(mod_name, mod_obj)

# Stub snowflake.connector (used by snowpipe_streaming_manager)
_connector = types.ModuleType("snowflake.connector")
_connector.connect = MagicMock()
sys.modules.setdefault("snowflake.connector", _connector)

# Stub cryptography modules (used by snowpipe_streaming_manager)
for name in [
    "cryptography", "cryptography.hazmat", "cryptography.hazmat.primitives",
    "cryptography.hazmat.primitives.serialization", "cryptography.hazmat.backends",
]:
    sys.modules.setdefault(name, types.ModuleType(name))

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

# ---------------------------------------------------------------------------
# Now safe to import the source modules
# ---------------------------------------------------------------------------
from snowpipe_streaming_manager import SnowpipeStreamingManager
from automated_intelligence_streaming import AutomatedIntelligenceStreaming


class TestInnerBackpressureRetry(unittest.TestCase):
    """Tests for _insert_with_backpressure_retry in SnowpipeStreamingManager."""

    def _make_manager(self):
        """Create a SnowpipeStreamingManager with mocked __init__."""
        with patch.object(SnowpipeStreamingManager, "__init__", lambda self, *a, **kw: None):
            return SnowpipeStreamingManager.__new__(SnowpipeStreamingManager)

    @patch("snowpipe_streaming_manager.time.sleep")
    @patch("snowpipe_streaming_manager.random.uniform", return_value=0.0)
    def test_exponential_delay_sequence(self, mock_uniform, mock_sleep):
        """Verify delays double each retry: 1s, 2s, 4s, 8s."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.side_effect = [
            StreamingIngestError("ReceiverSaturated"),
            StreamingIngestError("ReceiverSaturated"),
            StreamingIngestError("ReceiverSaturated"),
            StreamingIngestError("ReceiverSaturated"),
            None,
        ]

        mgr._insert_with_backpressure_retry(
            channel, [{"a": 1}], "s0", "e0", "test", max_retries=5, initial_delay=1.0
        )

        sleep_values = [c.args[0] for c in mock_sleep.call_args_list]
        self.assertEqual(sleep_values, [1.0, 2.0, 4.0, 8.0])

    @patch("snowpipe_streaming_manager.time.sleep")
    @patch("snowpipe_streaming_manager.random.uniform", return_value=0.0)
    def test_delay_capped_at_max(self, mock_uniform, mock_sleep):
        """Verify delay never exceeds max_delay."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.side_effect = [
            StreamingIngestError("429"),
            StreamingIngestError("429"),
            StreamingIngestError("429"),
            StreamingIngestError("429"),
            None,
        ]

        mgr._insert_with_backpressure_retry(
            channel, [{"a": 1}], "s0", "e0", "test",
            max_retries=5, initial_delay=4.0, max_delay=10.0
        )

        sleep_values = [c.args[0] for c in mock_sleep.call_args_list]
        self.assertEqual(sleep_values, [4.0, 8.0, 10.0, 10.0])

    @patch("snowpipe_streaming_manager.time.sleep")
    @patch("snowpipe_streaming_manager.random.uniform", return_value=0.15)
    def test_jitter_applied(self, mock_uniform, mock_sleep):
        """Verify jitter is added to each sleep call."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.side_effect = [
            StreamingIngestError("ReceiverSaturated"),
            None,
        ]

        mgr._insert_with_backpressure_retry(
            channel, [{"a": 1}], "s0", "e0", "test", max_retries=2, initial_delay=1.0
        )

        mock_sleep.assert_called_once_with(1.15)

    @patch("snowpipe_streaming_manager.time.sleep")
    def test_jitter_range(self, mock_sleep):
        """Verify random.uniform is called with (0, delay * 0.25)."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.side_effect = [
            StreamingIngestError("ReceiverSaturated"),
            None,
        ]

        with patch("snowpipe_streaming_manager.random.uniform", return_value=0.0) as mock_uniform:
            mgr._insert_with_backpressure_retry(
                channel, [{"a": 1}], "s0", "e0", "test", max_retries=2, initial_delay=2.0
            )
            mock_uniform.assert_called_once_with(0, 0.5)

    @patch("snowpipe_streaming_manager.time.sleep")
    def test_non_backpressure_error_not_retried(self, mock_sleep):
        """Non-backpressure StreamingIngestError should raise immediately."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.side_effect = StreamingIngestError("SchemaEvolution error")

        with self.assertRaises(StreamingIngestError):
            mgr._insert_with_backpressure_retry(
                channel, [{"a": 1}], "s0", "e0", "test", max_retries=3
            )

        mock_sleep.assert_not_called()
        self.assertEqual(channel.append_rows.call_count, 1)

    @patch("snowpipe_streaming_manager.time.sleep")
    def test_success_on_first_attempt_no_sleep(self, mock_sleep):
        """Successful first attempt should not sleep at all."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.return_value = None

        mgr._insert_with_backpressure_retry(
            channel, [{"a": 1}], "s0", "e0", "test", max_retries=5
        )

        mock_sleep.assert_not_called()
        self.assertEqual(channel.append_rows.call_count, 1)

    @patch("snowpipe_streaming_manager.time.sleep")
    @patch("snowpipe_streaming_manager.random.uniform", return_value=0.0)
    def test_exhausted_retries_raises(self, mock_uniform, mock_sleep):
        """Should raise after exhausting all retry attempts."""
        mgr = self._make_manager()
        channel = MagicMock()
        channel.append_rows.side_effect = StreamingIngestError("ReceiverSaturated")

        with self.assertRaises(StreamingIngestError):
            mgr._insert_with_backpressure_retry(
                channel, [{"a": 1}], "s0", "e0", "test", max_retries=3
            )

        self.assertEqual(channel.append_rows.call_count, 3)


class TestOuterRetry(unittest.TestCase):
    """Tests for the outer retry in generate_and_stream_orders."""

    def _make_app(self):
        """Create an AutomatedIntelligenceStreaming with mocked dependencies."""
        mock_config = MagicMock()
        mock_config.get_int_property.return_value = 100

        mock_manager = MagicMock()
        mock_manager.get_max_customer_id.return_value = 1000

        app = AutomatedIntelligenceStreaming(mock_config, mock_manager)
        return app, mock_manager

    @patch("automated_intelligence_streaming.time.sleep")
    @patch("automated_intelligence_streaming.random.uniform", return_value=0.0)
    def test_outer_exponential_backoff(self, mock_uniform, mock_sleep):
        """Verify outer retry uses exponential backoff, not linear."""
        app, mock_manager = self._make_app()
        mock_manager.insert_orders.side_effect = [
            StreamingIngestError("ReceiverSaturated"),
            StreamingIngestError("ReceiverSaturated"),
            None,
        ]
        mock_manager.insert_order_items.return_value = None

        app.generate_and_stream_orders(1)

        backoff_sleeps = [
            c.args[0] for c in mock_sleep.call_args_list
            if c.args[0] not in (0.1,)
        ]
        # retry 0: min(2^0, 16) = 1, retry 1: min(2^1, 16) = 2
        self.assertEqual(backoff_sleeps, [1.0, 2.0])

    @patch("automated_intelligence_streaming.time.sleep")
    @patch("automated_intelligence_streaming.random.uniform", return_value=0.2)
    def test_outer_jitter_applied(self, mock_uniform, mock_sleep):
        """Verify jitter is added to outer retry sleeps."""
        app, mock_manager = self._make_app()
        mock_manager.insert_orders.side_effect = [
            StreamingIngestError("ReceiverSaturated"),
            None,
        ]
        mock_manager.insert_order_items.return_value = None

        app.generate_and_stream_orders(1)

        backoff_sleeps = [
            c.args[0] for c in mock_sleep.call_args_list
            if c.args[0] not in (0.1,)
        ]
        # delay=1.0 + jitter=0.2 = 1.2
        self.assertAlmostEqual(backoff_sleeps[0], 1.2)

    @patch("automated_intelligence_streaming.time.sleep")
    def test_outer_only_catches_streaming_errors(self, mock_sleep):
        """Non-StreamingIngestError should propagate immediately, no retry."""
        app, mock_manager = self._make_app()
        mock_manager.insert_orders.side_effect = ValueError("bad schema")

        with self.assertRaises(ValueError):
            app.generate_and_stream_orders(1)

        self.assertEqual(mock_manager.insert_orders.call_count, 1)

    @patch("automated_intelligence_streaming.time.sleep")
    @patch("automated_intelligence_streaming.random.uniform", return_value=0.0)
    def test_outer_delay_capped_at_16(self, mock_uniform, mock_sleep):
        """Outer retry delay should cap at 16 seconds."""
        app, mock_manager = self._make_app()
        mock_manager.insert_orders.side_effect = StreamingIngestError("ReceiverSaturated")

        with self.assertRaises(StreamingIngestError):
            app.generate_and_stream_orders(1)

        backoff_sleeps = [
            c.args[0] for c in mock_sleep.call_args_list
            if c.args[0] not in (0.1,)
        ]
        for s in backoff_sleeps:
            self.assertLessEqual(s, 16 + 16 * 0.25)


if __name__ == "__main__":
    unittest.main()
