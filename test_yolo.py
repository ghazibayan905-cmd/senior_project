import cv2
from ultralytics import YOLO

print('🚀 starting YOLOv8 camera demo')

model = YOLO('yolov8n.pt')
print('✅ model loaded')

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    raise RuntimeError('❌ cannot open camera')

print('✅ camera opened. press ESC to exit.')

while True:
    ret, frame = cap.read()
    if not ret:
        print('❌ failed to read frame')
        break

    results = model(frame, device='cpu')  # أو device='cuda' إذا عندك GPU
    r = results[0]

    for box in r.boxes:
        x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
        conf = float(box.conf[0])
        cls = int(box.cls[0])
        name = model.names.get(cls, str(cls))
        label = f"{name} {conf:.2f}"
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(frame, label, (x1, y1 - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

    cv2.imshow('YOLOv8 camera', frame)

    key = cv2.waitKey(1)
    if key == 27:  # ESC
        print('🛑 exit requested')
        break

cap.release()
cv2.destroyAllWindows()
print('✅ done')