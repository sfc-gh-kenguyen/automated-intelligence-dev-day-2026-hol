import logging
from typing import List, Dict, Any, Optional
from snowflake.ingest.streaming import StreamingIngestClient, StreamingIngestChannel
from snowflake.ingest.streaming.streaming_ingest_error import StreamingIngestError
from models import Order, OrderItem
from config_manager import ConfigManager
import snowflake.connector
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import random
import time

logger = logging.getLogger(__name__)


class SnowpipeStreamingManager:
    def __init__(self, config: ConfigManager, instance_id: int = -1):
        self.config = config
        self.instance_id = instance_id
        self._last_orders_offset: str | None = None
        self._last_order_items_offset: str | None = None
        
        channel_suffix = f"_instance_{instance_id}" if instance_id >= 0 else ""
        logger.info(
            f"Creating Snowflake Streaming clients and opening channels"
            f"{' for instance ' + str(instance_id) if instance_id >= 0 else '...'}"
        )
        
        self.properties = {
            "account": config.get_snowflake_account(),
            "user": config.get_snowflake_user(),
            "private_key": config.get_private_key(),
            "url": config.get_snowflake_url(),
            "role": config.get_role(),
            "warehouse": config.get_warehouse(),
        }
        
        self.orders_client = StreamingIngestClient(
            client_name=f"ORDERS_CLIENT_{instance_id}",
            db_name=config.get_database(),
            schema_name=config.get_schema(),
            pipe_name=config.get_property("pipe.orders.name"),
            properties=self.properties,
        )
        
        self.order_items_client = StreamingIngestClient(
            client_name=f"ORDER_ITEMS_CLIENT_{instance_id}",
            db_name=config.get_database(),
            schema_name=config.get_schema(),
            pipe_name=config.get_property("pipe.order_items.name"),
            properties=self.properties,
        )
        
        self.orders_channel = self._open_channel(
            self.orders_client,
            config.get_property("channel.orders.name") + channel_suffix,
        )
        
        self.order_items_channel = self._open_channel(
            self.order_items_client,
            config.get_property("channel.order_items.name") + channel_suffix,
        )
        
        logger.info("All clients and channels initialized successfully")

    def _open_channel(
        self, client: StreamingIngestClient, channel_name: str
    ) -> StreamingIngestChannel:
        initial_offset = "0"
        channel, status = client.open_channel(channel_name, initial_offset)
        
        latest_offset = channel.get_latest_committed_offset_token()
        logger.info(
            f"Channel {channel_name} opened. Latest committed offset: "
            f"{latest_offset if latest_offset else 'NULL (new channel)'}"
        )
        
        return channel

    def get_max_customer_id(self) -> int:
        private_key_pem = self.config.get_private_key()
        private_key_obj = serialization.load_pem_private_key(
            private_key_pem.encode(),
            password=None,
            backend=default_backend()
        )
        
        conn_params = {
            "account": self.config.get_snowflake_account(),
            "user": self.config.get_snowflake_user(),
            "role": self.config.get_role(),
            "warehouse": self.config.get_warehouse(),
            "database": self.config.get_database(),
            "schema": self.config.get_schema(),
            "private_key": private_key_obj,
        }
        
        max_id = 1
        try:
            conn = snowflake.connector.connect(**conn_params)
            cursor = conn.cursor()
            cursor.execute(
                f"SELECT MAX(CUSTOMER_ID) as MAX_ID FROM "
                f"{self.config.get_database()}.RAW.CUSTOMERS"
            )
            result = cursor.fetchone()
            if result and result[0]:
                max_id = result[0]
            logger.info(f"Max customer ID in database: {max_id}")
            cursor.close()
            conn.close()
        except Exception as e:
            logger.error(f"Error fetching max customer ID: {e}")
            raise
        
        return max_id

    def get_customer_segment(self, customer_id: int) -> str:
        """
        Get customer segment for a given customer_id.
        For new customers (beyond max_customer_id), randomly assign segment.
        For existing customers, query from database.
        """
        import random
        
        try:
            # For simplicity during high-volume streaming, randomly assign segments
            # to avoid frequent DB queries that could slow down ingestion
            segments = ["Premium", "Standard", "Basic"]
            return random.choice(segments)
        except Exception as e:
            logger.warning(f"Error getting customer segment: {e}, defaulting to Standard")
            return "Standard"

    def insert_order(self, order: Order) -> None:
        row = order.to_dict()
        offset_token = f"order_{order.order_id}"
        
        self.orders_channel.append_row(row, offset_token)
        logger.debug(f"Order {order.order_id} inserted with offset {offset_token}")

    def insert_orders(self, orders: List[Order]) -> None:
        if not orders:
            return
        
        start_offset = f"order_{orders[0].order_id}"
        end_offset = f"order_{orders[-1].order_id}"
        
        rows = [order.to_dict() for order in orders]
        
        self._insert_with_backpressure_retry(
            self.orders_channel, rows, start_offset, end_offset, "orders"
        )
        self._last_orders_offset = end_offset
        logger.debug(
            f"Inserted {len(orders)} orders (offset range: {start_offset} to {end_offset})"
        )

    def insert_order_items(self, items: List[OrderItem]) -> None:
        if not items:
            return
        
        start_offset = f"item_{items[0].order_item_id}"
        end_offset = f"item_{items[-1].order_item_id}"
        
        rows = [item.to_dict() for item in items]
        
        self._insert_with_backpressure_retry(
            self.order_items_channel, rows, start_offset, end_offset, "order_items"
        )
        self._last_order_items_offset = end_offset
        logger.debug(
            f"Inserted {len(items)} order items (offset range: {start_offset} to {end_offset})"
        )

    def _insert_with_backpressure_retry(
        self,
        channel: StreamingIngestChannel,
        rows: List[Dict[str, Any]],
        start_offset: str,
        end_offset: str,
        data_type: str,
        max_retries: int = 5,
        initial_delay: float = 1.0,
        max_delay: float = 30.0,
    ) -> None:
        """
        Insert rows with exponential backoff retry for ReceiverSaturated errors.
        
        Args:
            channel: The streaming channel to insert into
            rows: Data rows to insert
            start_offset: Starting offset token
            end_offset: Ending offset token
            data_type: Description of data type (for logging)
            max_retries: Maximum number of retry attempts
            initial_delay: Initial delay in seconds before first retry
            max_delay: Maximum delay between retries
        """
        delay = initial_delay
        
        for attempt in range(max_retries):
            try:
                channel.append_rows(rows, start_offset, end_offset)
                
                if attempt > 0:
                    logger.info(
                        f"Successfully inserted {len(rows)} {data_type} after {attempt + 1} attempts"
                    )
                return
                
            except StreamingIngestError as e:
                error_msg = str(e)
                
                # Check for ReceiverSaturated (HTTP 429) backpressure errors
                if "ReceiverSaturated" in error_msg or "429" in error_msg:
                    if attempt < max_retries - 1:
                        jitter = random.uniform(0, delay * 0.25)
                        logger.warning(
                            f"Backpressure detected for {data_type} (attempt {attempt + 1}/{max_retries}): "
                            f"Channel buffers full. Retrying in {delay + jitter:.1f}s..."
                        )
                        time.sleep(delay + jitter)
                        delay = min(delay * 2, max_delay)  # Exponential backoff
                        continue
                    else:
                        logger.error(
                            f"Failed to insert {len(rows)} {data_type} after {max_retries} attempts: "
                            f"Channel buffers remain saturated"
                        )
                        raise
                else:
                    # Non-backpressure error, re-raise immediately
                    logger.error(f"Unexpected error inserting {data_type}: {error_msg}")
                    raise
            
            except Exception as e:
                logger.error(f"Unexpected error type inserting {data_type}: {type(e).__name__}: {e}")
                raise
    
    def get_latest_order_offset(self) -> Optional[str]:
        return self.orders_channel.get_latest_committed_offset_token()

    def get_latest_order_item_offset(self) -> Optional[str]:
        return self.order_items_channel.get_latest_committed_offset_token()

    def wait_for_flush(self, timeout_seconds: int = 120, poll_interval: float = 2.0) -> bool:
        """
        Wait until both channels have committed all in-flight data.
        Polls each channel's latest committed offset token until it matches
        the last offset we sent, confirming Snowflake has received everything.

        Returns True if both channels flushed within the timeout, False otherwise.
        """
        logger.info("Waiting for all channels to flush in-flight data...")
        start = time.time()

        channels_to_check = []
        if self._last_orders_offset:
            channels_to_check.append(
                ("orders", self.orders_channel, self._last_orders_offset)
            )
        if self._last_order_items_offset:
            channels_to_check.append(
                ("order_items", self.order_items_channel, self._last_order_items_offset)
            )

        if not channels_to_check:
            logger.info("No data was sent — nothing to flush")
            return True

        flushed = {name: False for name, _, _ in channels_to_check}

        while time.time() - start < timeout_seconds:
            all_done = True
            for name, channel, expected_offset in channels_to_check:
                if flushed[name]:
                    continue
                committed = channel.get_latest_committed_offset_token()
                if committed == expected_offset:
                    elapsed = time.time() - start
                    logger.info(
                        f"Channel {name} flushed (offset {committed}) in {elapsed:.1f}s"
                    )
                    flushed[name] = True
                else:
                    all_done = False

            if all_done:
                total = time.time() - start
                logger.info(f"All channels flushed in {total:.1f}s")
                return True

            time.sleep(poll_interval)

        # Timeout — log which channels are still pending
        for name, channel, expected_offset in channels_to_check:
            if not flushed[name]:
                committed = channel.get_latest_committed_offset_token()
                logger.warning(
                    f"Channel {name} NOT flushed after {timeout_seconds}s "
                    f"(expected: {expected_offset}, committed: {committed})"
                )
        return False

    def close(self) -> None:
        try:
            logger.info("Closing channels...")
            if hasattr(self, "orders_channel"):
                self.orders_channel.close()
            if hasattr(self, "order_items_channel"):
                self.order_items_channel.close()
            
            logger.info("Closing clients...")
            if hasattr(self, "orders_client"):
                self.orders_client.close()
            if hasattr(self, "order_items_client"):
                self.order_items_client.close()
            
            logger.info("Snowpipe Streaming manager closed successfully")
        except Exception as e:
            logger.error(f"Error closing Snowpipe Streaming manager: {e}")
