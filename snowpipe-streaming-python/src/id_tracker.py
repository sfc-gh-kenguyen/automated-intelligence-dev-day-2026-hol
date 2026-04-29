import logging
from threading import Lock
from typing import Optional
from snowpipe_streaming_manager import SnowpipeStreamingManager

logger = logging.getLogger(__name__)


class IDTracker:
    def __init__(self, manager: SnowpipeStreamingManager):
        self.manager = manager
        
        self.order_id_counter = self._parse_offset_id(
            manager.get_latest_order_offset(), "order_", 0
        )
        
        self.order_item_id_counter = self._parse_offset_id(
            manager.get_latest_order_item_offset(), "item_", 0
        )
        
        self.order_lock = Lock()
        self.order_item_lock = Lock()
        
        logger.info(
            f"ID Tracker initialized - Order: {self.order_id_counter}, "
            f"OrderItem: {self.order_item_id_counter}"
        )

    def _parse_offset_id(
        self, offset_token: Optional[str], prefix: str, default_value: int
    ) -> int:
        if offset_token is None or offset_token == "NULL" or offset_token == "":
            return default_value
        
        try:
            if offset_token.startswith(prefix):
                return int(offset_token[len(prefix):])
        except (ValueError, AttributeError) as e:
            logger.warning(f"Failed to parse offset token: {offset_token}")
        
        return default_value

    def get_next_order_id(self) -> int:
        with self.order_lock:
            self.order_id_counter += 1
            return self.order_id_counter

    def get_next_order_item_id(self, count: int) -> int:
        with self.order_item_lock:
            self.order_item_id_counter += 1
            start_id = self.order_item_id_counter
            self.order_item_id_counter += count - 1
            return start_id
