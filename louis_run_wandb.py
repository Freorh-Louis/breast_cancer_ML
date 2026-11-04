import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt
import seaborn as sns
import wandb


IMG_HEIGHT = 50
IMG_WIDTH = 50
NUM_CLASSES = 2
VALIDATION_SPLIT = 0.2

# Start a run, tracking hyperparameters
wandb.init(
    # set the wandb project where this run will be logged
    project="breast-cancer-ML",
    name="louis_run_16",

    # track hyperparameters and run metadata with wandb.config
    config={
        "conv_filters": [64, 64, 128],
        "conv_kernel_size": 3,
        "activation_conv": "leaky_relu",
        "layer_1": 128,
        "activation_1": "relu",
        "dropout_1": 0,
        "optimizer": "adam",
        "learning_rate": 0.001,
        "loss": "SparseCategoricalCrossentropy",
        "metric": "accuracy",
        "epoch": 14,
        "batch_size": 64,
        "seed": 42,
        "normalization": "Rescaling(1.0 / 255)",
    }
)

config = wandb.config

train_ds = tf.keras.utils.image_dataset_from_directory(
    "breast_cancer_ML/breast-cancer",
    batch_size=config.batch_size,
    image_size=(IMG_HEIGHT, IMG_WIDTH),
    seed=config.seed,
    validation_split=VALIDATION_SPLIT,
    subset="training"
)

validation_ds = tf.keras.utils.image_dataset_from_directory(
    "breast_cancer_ML/breast-cancer",
    batch_size=config.batch_size,
    image_size=(IMG_HEIGHT, IMG_WIDTH),
    seed=config.seed,
    validation_split=VALIDATION_SPLIT,
    subset="validation"
)

model = tf.keras.Sequential(
    [
        tf.keras.layers.Rescaling(1.0 / 255),
        tf.keras.layers.Conv2D(config.conv_filters[0], config.conv_kernel_size, activation=config.activation_conv),
        tf.keras.layers.MaxPooling2D(),
        tf.keras.layers.Conv2D(config.conv_filters[1], config.conv_kernel_size, activation=config.activation_conv),
        tf.keras.layers.MaxPooling2D(),
        tf.keras.layers.Conv2D(config.conv_filters[2], config.conv_kernel_size, activation=config.activation_conv),
        tf.keras.layers.MaxPooling2D(),
        tf.keras.layers.Flatten(),
        tf.keras.layers.Dense(config.layer_1, activation=config.activation_1),
        tf.keras.layers.Dense(NUM_CLASSES),
    ]
)

model.compile(
    optimizer=config.optimizer,
    loss=tf.losses.SparseCategoricalCrossentropy(from_logits=True),
    metrics=[config.metric],
)

history = model.fit(
    train_ds,
    validation_data=validation_ds,
    epochs=config.epoch,
    callbacks=[
        wandb.keras.WandbMetricsLogger(log_freq=5),
        wandb.keras.WandbModelCheckpoint("models.keras")
    ]
)