# XGBoost model trainer for product recommendation
# Co-authored with CoCo
import logging
import time
from dataclasses import dataclass
from typing import Tuple

import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

from config import TrainingConfig

logger = logging.getLogger(__name__)


@dataclass
class TrainingResult:
    model: xgb.XGBClassifier
    X_train: pd.DataFrame
    X_test: pd.DataFrame
    y_train: pd.Series
    y_test: pd.Series
    training_time: float
    used_gpu: bool
    customer_encoder: LabelEncoder
    product_encoder: LabelEncoder


def _detect_gpu() -> bool:
    try:
        import cupy
        return True
    except ImportError:
        pass
    try:
        probe = xgb.XGBClassifier(device="cuda", tree_method="hist", n_estimators=1, verbosity=0)
        probe.fit([[0]], [0])
        return True
    except xgb.core.XGBoostError:
        return False


def prepare_features(pdf: pd.DataFrame, config: TrainingConfig) -> Tuple[pd.DataFrame, pd.Series, LabelEncoder, LabelEncoder]:
    customer_encoder = LabelEncoder()
    product_encoder = LabelEncoder()

    pdf["CUSTOMER_ID_ENCODED"] = customer_encoder.fit_transform(pdf["CUSTOMER_ID"])
    pdf["PRODUCT_ID_ENCODED"] = product_encoder.fit_transform(pdf["PRODUCT_ID"])

    X = pdf[config.feature_columns]
    y = pdf[config.label_column]
    return X, y, customer_encoder, product_encoder


def train_model(pdf: pd.DataFrame, config: TrainingConfig) -> TrainingResult:
    X, y, customer_encoder, product_encoder = prepare_features(pdf, config)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=config.test_size, random_state=config.random_state, stratify=y
    )
    logger.info(f"Split: {len(X_train):,} train / {len(X_test):,} test")

    neg_count = (y_train == 0).sum()
    pos_count = (y_train == 1).sum()
    scale_pos_weight = neg_count / pos_count if pos_count > 0 else 1.0
    logger.info(f"Class balance — negative: {neg_count:,}, positive: {pos_count:,}, scale_pos_weight: {scale_pos_weight:.2f}")

    gpu_available = _detect_gpu()
    device = "cuda" if gpu_available else "cpu"
    logger.info(f"Training with device={device} ({'GPU' if gpu_available else 'CPU'})")

    params = config.to_xgb_params()
    params["tree_method"] = "hist"
    params["device"] = device
    params["scale_pos_weight"] = scale_pos_weight

    model = xgb.XGBClassifier(**params)

    start = time.time()
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        verbose=200,
    )
    training_time = time.time() - start

    logger.info(f"Training complete in {training_time:.2f}s ({config.n_estimators / training_time:.0f} trees/s)")

    return TrainingResult(
        model=model,
        X_train=X_train,
        X_test=X_test,
        y_train=y_train,
        y_test=y_test,
        training_time=training_time,
        used_gpu=gpu_available,
        customer_encoder=customer_encoder,
        product_encoder=product_encoder,
    )
