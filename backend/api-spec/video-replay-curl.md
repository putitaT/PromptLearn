# ทดลอง Video Replay API ด้วย curl

ใช้คำสั่งจาก root ของ repo โดยเปิด Go backend ที่ `127.0.0.1:8080` ลง schema กับ demo seed และตั้งค่า `REPLAY_TRANSCRIBER=openai` ตาม [วิธีรันเดโมคลิปย้อนหลัง](../README.md#รันเดโมคลิปย้อนหลัง) ต้องมี `curl` กับ `jq` ทดสอบ API ได้ด้วย Go backend โดยตรง ค่าเริ่มต้นใช้คลิปใน `backend/examples/` กำหนด `PROMPTLEARN_VIDEO` เพื่อเลือกไฟล์อื่นได้

## 1. ครูอัปโหลด MP4

```bash
set -o pipefail
promptlearn_url=${PROMPTLEARN_URL:-http://127.0.0.1:8080}

recording_id=$(curl --fail-with-body --silent --show-error \
  "$promptlearn_url/api/demo/recordings" \
  -H 'X-Demo-Role: teacher' \
  -F "video=@${PROMPTLEARN_VIDEO:-backend/examples/thai-lesson.mp4};type=video/mp4" \
  | jq -er '.recordingId')

printf 'recordingId=%s\n' "$recording_id"
```

Backend แยกเสียงจาก MP4 แบ่งที่จังหวะหยุดพูด แล้วส่งเสียงแต่ละช่วงให้ `gpt-transcribe` โดยใช้เวลาจากคลิปต้นฉบับกำหนด `startMs` และ `endMs` คำขอจะรอจนบันทึกคลิปและ transcript สำเร็จ จากนั้น API ตอบ `201 Created` พร้อม `recordingId` ของฉบับร่าง เส้นย้อนหลัง `/video` ตอบ `404` จนกว่าจะเผยแพร่

## 2. ครูพรีวิวฉบับร่าง

```bash
curl --fail-with-body --silent --show-error \
  -H 'X-Demo-Role: teacher' \
  "$promptlearn_url/api/demo/recordings/$recording_id/preview" -o draft-preview.mp4
```

ครูได้รับ `200 OK` พร้อมไฟล์ MP4 ก่อนเผยแพร่ คำขอจากบทบาทนักเรียนหรือคำขอที่ไม่มี header บทบาทจะได้ `403 Forbidden` ส่วน URL ย้อนหลังของนักเรียนยังได้ `404` ขณะที่คลิปเป็นฉบับร่าง

## 3. ครูเผยแพร่คลิป

```bash
jq -n --arg id "$recording_id" '{recordingId: $id}' \
  | curl --fail-with-body --silent --show-error \
      -X PUT "$promptlearn_url/api/demo/publication" \
      -H 'X-Demo-Role: teacher' \
      -H 'Content-Type: application/json' \
      --data-binary @- \
  | jq .
```

API ตอบ `200 OK` พร้อม `recordingId` ของคลิปที่เผยแพร่ ใช้ `X-Demo-Role: teacher` สำหรับการอัปโหลด พรีวิว และเผยแพร่ในโหมดเดโม

## 4. นักเรียนเรียกข้อมูลย้อนหลังและดาวน์โหลด MP4

```bash
replay_json=$(curl --fail-with-body --silent --show-error \
  "$promptlearn_url/api/demo/replay")

printf '%s\n' "$replay_json" \
  | jq '{published, recordingId, durationMs, videoUrl, transcript}'

video_path=$(printf '%s\n' "$replay_json" | jq -er '.videoUrl')
curl --fail-with-body --silent --show-error \
  "$promptlearn_url$video_path" -o replay.mp4
```

เมื่อมีคลิปที่เผยแพร่แล้ว API คืน `published: true` พร้อม URL แบบ relative และ transcript ที่ใช้หน่วยมิลลิวินาที ถ้าคาบยังไม่เคยเผยแพร่ API ตอบ `200 OK` พร้อม `{"published":false}` ฝั่งนักเรียนเรียกดูได้โดยไม่ต้องส่ง header บทบาท

## 5. ตรวจ HTTP Range สำหรับการเลื่อนวิดีโอ

```bash
curl --fail-with-body --silent --show-error \
  -H 'Range: bytes=0-1023' \
  -D - -o /dev/null \
  "$promptlearn_url$video_path"
```

ควรได้ `206 Partial Content` พร้อม `Content-Range` ของช่วงไบต์ที่ขอ ดู [OpenAPI](openapi.yaml) หรือ [HTML API Reference](index.html#uploadReplayRecording) สำหรับรายละเอียดแต่ละ endpoint
