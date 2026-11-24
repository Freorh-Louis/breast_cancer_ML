from pathlib import Path

import tensorflow as tf


IDC_IMAGE_PATH = "breast_cancer_ML/breast-cancer/IDC/9081_idx5_x2701_y1351_class1.png"
NON_IDC_IMAGE_PATH = "breast_cancer_ML/breast-cancer/non-IDC/9081_idx5_x801_y1401_class0.png"

IMAGE_SIZE = (50, 50)
CLASS_NAMES = ("IDC", "non-IDC")
MODEL_PATH = Path(__file__).resolve().with_name("models.keras")


image_path = Path(IDC_IMAGE_PATH)  # Change to IDC_IMAGE_PATH to test IDC image

if not image_path.is_file():
    raise FileNotFoundError(f"Image file not found: {image_path}")
if not MODEL_PATH.is_file():
    raise FileNotFoundError(f"Model file not found: {MODEL_PATH}")

model = tf.keras.models.load_model(MODEL_PATH, compile=False)

image = tf.keras.utils.load_img(
    image_path,
    color_mode="rgb",
    target_size=IMAGE_SIZE,
    interpolation="bilinear",
)
image_array = tf.keras.utils.img_to_array(image)
batch = tf.expand_dims(image_array, axis=0)

# The model includes Rescaling, so pixels should remain in [0, 255].
logits = model(batch, training=False)

if logits.shape.rank != 2 or logits.shape[-1] != len(CLASS_NAMES):
    raise ValueError(
        "Expected two class logits; "
        f"received output shape {logits.shape}."
    )

probabilities = tf.nn.softmax(logits[0], axis=-1).numpy()
predicted_index = int(tf.argmax(probabilities).numpy())

print(f"Prediction: {CLASS_NAMES[predicted_index]}")
for class_name, probability in zip(CLASS_NAMES, probabilities):
    print(f"{class_name}: {probability:.1%}")

