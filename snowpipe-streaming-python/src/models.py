from typing import Dict, Any


class Customer:
    def __init__(
        self,
        customer_id: int,
        first_name: str,
        last_name: str,
        email: str,
        phone: str,
        address: str,
        city: str,
        state: str,
        zip_code: str,
        registration_date: str,
        customer_segment: str,
    ):
        self.customer_id = customer_id
        self.first_name = first_name
        self.last_name = last_name
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.zip_code = zip_code
        self.registration_date = registration_date
        self.customer_segment = customer_segment

    def to_dict(self) -> Dict[str, Any]:
        return {
            "CUSTOMER_ID": self.customer_id,
            "FIRST_NAME": self.first_name,
            "LAST_NAME": self.last_name,
            "EMAIL": self.email,
            "PHONE": self.phone,
            "ADDRESS": self.address,
            "CITY": self.city,
            "STATE": self.state,
            "ZIP_CODE": self.zip_code,
            "REGISTRATION_DATE": self.registration_date,
            "CUSTOMER_SEGMENT": self.customer_segment,
        }


class Order:
    def __init__(
        self,
        order_id: str,
        customer_id: int,
        order_date: str,
        order_status: str,
        total_amount: float,
        discount_percent: float,
        shipping_cost: float,
    ):
        self.order_id = order_id
        self.customer_id = customer_id
        self.order_date = order_date
        self.order_status = order_status
        self.total_amount = total_amount
        self.discount_percent = discount_percent
        self.shipping_cost = shipping_cost

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ORDER_ID": self.order_id,
            "CUSTOMER_ID": self.customer_id,
            "ORDER_DATE": self.order_date,
            "ORDER_STATUS": self.order_status,
            "TOTAL_AMOUNT": self.total_amount,
            "DISCOUNT_PERCENT": self.discount_percent,
            "SHIPPING_COST": self.shipping_cost,
        }


class OrderItem:
    def __init__(
        self,
        order_item_id: str,
        order_id: str,
        product_id: int,
        product_name: str,
        product_category: str,
        quantity: int,
        unit_price: float,
        line_total: float,
    ):
        self.order_item_id = order_item_id
        self.order_id = order_id
        self.product_id = product_id
        self.product_name = product_name
        self.product_category = product_category
        self.quantity = quantity
        self.unit_price = unit_price
        self.line_total = line_total

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ORDER_ITEM_ID": self.order_item_id,
            "ORDER_ID": self.order_id,
            "PRODUCT_ID": self.product_id,
            "PRODUCT_NAME": self.product_name,
            "PRODUCT_CATEGORY": self.product_category,
            "QUANTITY": self.quantity,
            "UNIT_PRICE": self.unit_price,
            "LINE_TOTAL": self.line_total,
        }
