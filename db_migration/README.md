# PromptLearn database

[schema.sql](./schema.sql) เป็น initial migration สำหรับ PostgreSQL 14 ขึ้นไป และ [ERD.md](./ERD.md) แสดงความสัมพันธ์ตาม frontend flow ทั้งสามส่วน

## สร้างฐานข้อมูล

รันจาก root ของ PromptLearn บนฐานข้อมูลที่ยังไม่มี schema `promptlearn` โดยใช้การตั้งค่าการเชื่อมต่อของ PostgreSQL ในเครื่อง

```sh
createdb promptlearn_dev
psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/schema.sql
psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/course_syllabus.sql
psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/assignment_review.sql
```

Migration ทำงานใน transaction เดียว ตัวอย่าง query ใช้ชื่อแบบ `promptlearn.course_offerings` ตั้งค่าการเชื่อมต่อของ backend ให้เข้าถึง schema นี้ตามสิทธิ์ของบริการ

## การบันทึก Course Syllabus

[Course Syllabus migration](course_syllabus.sql) เพิ่ม `syllabus_unit_outcomes` สำหรับการเลือกตัวชี้วัดรายหน่วย และ `syllabus_versions.api_preview` สำหรับเก็บ snapshot ที่ API อ่านกลับ รายการโครงสร้างด้านล่างและ snapshot บันทึกใน transaction เดียวกัน

| ขั้น | ข้อมูลที่บันทึก |
|---|---|
| บันทึกร่าง | `courses`, `syllabus_versions`, `learning_outcomes`, `syllabus_units`, `syllabus_lessons`, `planned_periods` และ `grading_plan_items` |
| เผยแพร่รายห้อง | จับคู่ภาคเรียนและห้องผ่าน `academic_terms`, `class_sections` และ `course_offerings` จากนั้นบันทึก `weekly_timetable_slots`, `lesson_sessions`, `assessment_events` และ `offering_syllabus_publications` |

ระบบแก้ไขร่างเดิมจนเผยแพร่ หลังเผยแพร่ การแก้ไขจะเปิดร่างฉบับใหม่ และผู้เรียนยังเห็นฉบับที่เผยแพร่ล่าสุด การเผยแพร่ฉบับใหม่เปลี่ยน publication พร้อมกับตารางรายห้องใน transaction เดียว เมื่อการสอนของฉบับก่อนเริ่มแล้ว API ตอบ `409 teaching_started` เพื่อรักษาคาบเดิมและข้อมูลที่อ้างถึงคาบนั้น

สำหรับเดโม ให้รัน `db_migration/demo_seed.sql` แล้วตั้ง `COURSE_SYLLABUS_DATABASE_URL` ให้ backend ใช้ฐาน dev ระบบใช้โรงเรียนและครูตัวอย่างจาก seed เทอมที่โรงเรียนกำหนดต้องครอบคลุมช่วงวันสอน ระบบสร้างเทอมเดโมตามปีการศึกษา พ.ศ. เมื่อยังไม่มีเทอมนั้น และขยายช่วงวันได้เมื่อเผยแพร่วิชาเพิ่มเติม ค่าเครดิตตั้งต้นเป็น 0 เพราะ request ปัจจุบันยังไม่มีฟิลด์เครดิต หมวดคะแนนที่มีคำว่า `final` ใช้กลุ่มปลายภาค

HTML สร้างจากข้อมูลที่บันทึกเมื่อตอบ API การเก็บไฟล์ส่งออกใน S3 จะเป็นส่วนของการเชื่อม storage ภายหลัง

## ประวัติจาก Check my work

[Assignment Review migration](assignment_review.sql) เพิ่ม `assignment_work_reviews` เพื่อเก็บหนึ่งผลตรวจต่อหนึ่ง revision รวมสถานะ `correct`, `needs_revision` และ `unreadable` ใช้ไฟล์นี้เพิ่มกับฐานที่รัน initial schema แล้วได้

- นักเรียนและงานต้นทางอ้างผ่าน `assignment_work_reviews → response_revisions → item_responses → submissions`
- แต่ละขั้นที่ให้แก้มี `response_annotations` เก็บบล็อกและพิกัด OCR และ `learning_feedback` เก็บคำถามชี้แนะพร้อมรหัส `misconceptions` เมื่อระบุจุดที่เข้าใจคลาดเคลื่อนได้ ถ้างานถูกหรืออ่านไม่ชัด จะมี feedback สรุปพร้อมสถานะของรอบนั้น
- ข้อที่ผูกกับผลการเรียนรู้เพียงข้อเดียวจะได้ `learning_feedback.outcome_id` สำหรับสรุปรายหัวข้อ ถ้ามีหลายข้อ ยังใช้ความสัมพันธ์ใน `assessment_item_outcomes` เพื่อตรวจบริบทได้
- ใช้ `submissions.student_id` และ `misconceptions.code` สรุปตามคน และนำ `learning_feedback.id` ไปอ้างใน `practice_set_sources` เมื่อสร้างงานฝึกเฉพาะบุคคล ใช้ `assignment_work_reviews.engine` แยกข้อมูลจาก mock ขณะวิเคราะห์

สำหรับเดโม PostgreSQL ให้เติมข้อมูลตัวอย่างหลังรัน migration ทั้งสองไฟล์

```sh
psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/demo_seed.sql
psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/assignment_review_demo_seed.sql
```

ตั้ง `ASSIGNMENT_REVIEW_DATABASE_URL` ให้ backend ชี้ฐานเดโม จากนั้นเรียกรายการของ `hw-3-1` ด้วยรหัส `q1`, `q2`, `q3` และ `q5` จาก Flutter หรือทดสอบตัวอย่างเดิม `hw-3-2/q4` หากฐานเดโมเคย seed ไว้แล้ว ให้รัน `assignment_review_demo_seed.sql` อีกครั้งเพื่อเพิ่ม HW 3.1 ฉบับที่ 3 ซึ่งใช้โจทย์สมการในข้อ 4 (รหัส `q5`) ประวัติของฉบับก่อนหน้ายังอยู่ในฐานเดิม ระบบใช้บัญชีนักเรียนตัวอย่างที่กำหนดฝั่ง server การตรวจแต่ละครั้งเขียน revision, ผลตรวจ และ feedback ใน transaction เดียว คะแนนทางการยังอยู่ใน flow เผยแพร่คะแนน

เมื่อ Submit ครบ 4 ข้อ Go จะบันทึกรายงานคะแนนระหว่างเรียนไว้ใน `assignment_submission_reports` พร้อมรหัสผลตรวจ ข้อความ OCR และจุดที่ต้องทบทวนของแต่ละข้อ ฐานเดโมเดิมสามารถรัน `assignment_review.sql` ซ้ำเพื่อเพิ่มตารางนี้

## การตัดสินใจตาม frontend flow

| Flow | วิธีเก็บข้อมูล |
|---|---|
| Basics & timetable | `course_offerings` เชื่อมวิชากับห้องประจำเทอม `weekly_timetable_slots` เก็บคาบประจำรายห้อง ส่วน `school_calendar_events` ใช้ตัดวันหยุดหรือกันช่วงสอบ ช่องเวลาใช้เวลาท้องถิ่นของโรงเรียนและคาบจริงใช้ `timestamptz` |
| Standards & sources | ตารางกลางเก็บตัวชี้วัดพร้อมฉบับหลักสูตร `learning_outcomes` ใช้ได้กับตัวชี้วัดมาตรฐานและเกณฑ์ที่ครูเขียนเอง `outcome_chapter_matches` เก็บคู่ที่ AI เสนอหรือครูยืนยัน |
| Units & periods | ลำดับคือ unit → lesson → planned period → session หัวข้อหนึ่งมีได้หลายคาบตามแผน คาบปฐมนิเทศหรือคาบสำรองอยู่ในลำดับเดียวกันได้ การเลื่อนเวลาคาบจริงแก้เวลาโดยรักษา session ID เดิม |
| Review & publish | ร่าง syllabus กับฉบับที่แต่ละห้องเห็นแยกกันผ่าน `offering_syllabus_publications` มี active publication ได้หนึ่งฉบับต่อห้อง แผนรายคาบมีฉบับและเก็บ IBL, 5E, CPA, Flipped หรือแบบที่ครูเขียนเอง |
| Score split & schedule | `grading_plan_items` เก็บน้ำหนักรวม 100 และแบ่งระหว่างเทอมกับปลายภาค `assessment_events` วางวันสอบและขอบเขตหน่วยได้ก่อนมีโจทย์ งานคิดเกรดโยงหมวดผ่าน `assignment_grading_items` |
| สอนและเช็กชื่อ | `lesson_sessions` เก็บตัวเลือกบันทึก สตรีม และติดตามการตอบ `attendance_windows` เก็บช่วงเปิด เกณฑ์สาย และรัศมี `attendance_records` เก็บผลและผู้แก้รายการ โดยไม่มีคอลัมน์พิกัดนักเรียน |
| Replay & reflection | `lesson_publications` คุมสิ่งที่ห้องเห็น แยกจากสถานะใน `background_jobs` บทคลิปและโจทย์อ้าง offset หน่วยมิลลิวินาที `replay_progress.watched_ms` เก็บ union ของช่วงที่ดู AI อ้างถึง transcript segment ฉบับที่ใช้จริง และ `session_events` ใช้สรุปจังหวะคาบ |
| สร้างและตรวจแบบประเมิน | `assessment_versions` ตรึงโจทย์และ rubric ให้กับงานแต่ละห้อง `question_imports` เก็บรูปโจทย์และผล OCR รอตรวจ เกณฑ์ให้คะแนนรองรับระดับ Full / Partial / None และเก็บผลตรวจ AI แยกจากคะแนนที่เผยแพร่ |
| Guided practice & analytics | คำตอบที่ตรวจหลายครั้งเก็บเป็น `response_revisions` การวงวิธีทำอ้างฉบับและหน้าผ่าน `response_annotations` ใช้รหัส `misconceptions` เดียวกันสรุปข้อผิดข้าม quiz และ homework สำหรับโจทย์เฉพาะบุคคลให้สร้าง assessment version ของชุดโจทย์นั้นและมอบหมายแบบ `selected_students` พร้อมอ้างถึง feedback ต้นทาง |

ภาพรวมคะแนนรายข้อ สัดส่วนเวลาเรียน ความคืบหน้ารายหัวข้อ และ practice streak คำนวณจากคาบจริง การส่งงาน ผลตรวจ และเหตุการณ์ที่บันทึกไว้ หน้า analytics สามารถเพิ่ม query หรือ view เมื่อสูตรของแต่ละ metric ตกลงแล้ว

## กติกาที่ backend ต้องบังคับ

- **สิทธิ์** ตรวจโรงเรียน ห้อง บทบาท และเจ้าของคำตอบก่อนอ่านหรือแก้ไขทุกครั้ง รวมถึง foreign key ไปยัง asset หรือแหล่งอ้างอิงข้ามส่วน แจก signed URL หลังตรวจสิทธิ์เท่านั้น ผู้ปกครองเข้าถึงได้เมื่อมี verified link และครูเปิดการแชร์ Schema นี้ยังไม่มี RLS หรือการตั้ง role สำหรับ production
- **ฉบับและการเผยแพร่** autosave ใช้ร่างเดิม และการแก้เนื้อหาที่เผยแพร่แล้วให้สร้างฉบับใหม่ ใน transaction เดียวให้ตรวจความครบถ้วน ปิด publication เดิม และเปิดฉบับใหม่สำหรับห้องที่เลือก คาบที่เริ่มแล้วเก็บฉบับเดิมไว้ ตรวจว่าคลิปและ transcript พร้อมก่อนเผยแพร่และแจ้งเตือนเมื่อวันในตารางที่เผยแพร่เปลี่ยน
- **ตารางและคะแนน** ตรวจช่วงวันเทอม ความขัดแย้งของคาบ จำนวนคาบ และคะแนนรวม 100 ก่อน publish ตรวจคะแนน rubric แต่ละระดับและคะแนนรวมเทียบเพดานโจทย์ กรณี assessment event มีคาบจริงให้อ่านวันจากคาบนั้น ส่วนวันสอบนอกคาบอ่านจาก event คิดคะแนนรวมหมวดจากคะแนนที่เผยแพร่และแยกสถานะยังไม่ตรวจออกจากคะแนนศูนย์
- **การสอบและการตรวจ** ตรวจเวลาส่ง จำนวนครั้ง บทบาทผู้เรียน และสิทธิ์ผู้รับงาน เก็บลำดับสลับข้อเมื่อเริ่มทำ ส่งงานพร้อมตรึง revision ที่ส่งใน transaction เดียว แสดงคำใบ้เฉพาะงานที่อนุญาต เก็บ answer key และ rubric ฝั่งครู และเผยแพร่คะแนนจากผลตรวจที่ยอมรับแล้ว
- **คลิปและความเป็นส่วนตัว** ตรวจช่วงเวลาว่าอยู่ในคลิป เก็บช่วงที่ดูด้วย union อะตอมมิกเพื่อกันการนับซ้ำ ใช้พิกัดนักเรียนชั่วคราวตอนตรวจเช็กชื่อ รวมถึงงดบันทึกใน payload ของคิวหรือ request log ส่วนไฟล์สื่อและภาพคำตอบใช้ object storage และเก็บ metadata ใน `assets`
- **งานเบื้องหลัง** ให้ worker claim งานและรองรับ retry โดยใช้ `idempotency_key` กันการสร้างงานซ้ำ `payload` เก็บรหัสแถวที่เกี่ยวข้อง เช่น ไฟล์นำเข้าตาราง คาบ หรือคลิป ส่วนผลลัพธ์ถาวรเขียนลงตารางของ flow นั้น

## ตรวจการเชื่อมต่อจาก Go

ตั้ง `DATABASE_URL` ใน environment เป็น PostgreSQL connection string แล้วรันจากโฟลเดอร์ `backend`

```sh
go run ./cmd/dbcheck
```

คำสั่งนี้ตรวจการเชื่อมต่อภายใน 5 วินาที ใช้ได้ทั้งก่อนและหลังรัน migration
ส่วน backend ที่ต้องใช้ฐานข้อมูลในอนาคตสามารถเรียก `internal/database.OpenPostgres`
และปิด pool เมื่อเลิกใช้
