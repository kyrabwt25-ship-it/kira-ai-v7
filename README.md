# KIRA AI

منصة تعليمية عربية تعمل على الهاتف والكمبيوتر. المشروع الحالي يستخدم FastAPI لخدمة الواجهة وواجهات API، وSupabase للمصادقة وقاعدة البيانات، وAnthropic لتوليد الإجابات. الواجهة RTL ومتجاوبة، وتشمل الحسابات، المحادثة النصية والصور، الباقات، الدفع اليدوي أو عبر webhook، حفظ سجل المحادثات، لوحة المشرف، رفع المناهج والإعلانات.

## المتطلبات

يحتاج التشغيل إلى Python 3.12 أو أحدث، ومشروع Supabase، ومفتاح مزود النموذج. لا تضع أي مفتاح في GitHub. استخدم `.env` محليًا أو Secret/Environment Variables داخل Render.

## تشغيل محلي

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
cp .env.example .env           # Windows: copy .env.example .env
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

افتح `http://127.0.0.1:8000`. فحص الصحة متاح في `http://127.0.0.1:8000/api/health`، ويجب أن يعيد `ok: true` بعد إضافة متغيرات Supabase المطلوبة.

## إعداد Supabase

في Supabase افتح **SQL Editor** وشغّل `schema.sql` كاملًا. هذا هو الملف الموحد القابل لإعادة التشغيل؛ الملفان `schema2.sql` و`schema3.sql` موجودان للتوافق مع النسخ القديمة فقط ولا يلزم تشغيلهما في تثبيت جديد.

من **Authentication → Providers** فعّل Email، واختر إن كنت تريد تأكيد البريد، ثم اضبط **URL Configuration** على رابط التطبيق المنشور. إذا فعلت Google OAuth، أضف callback URL الخاص بـ Supabase في إعدادات Google ومزود OAuth.

بعد إنشاء حساب المشرف وتأكيد بريده، نفذ في SQL Editor أمرًا مثل التالي مع استبدال البريد ببريدك الحقيقي:

```sql
update profiles
set role = 'admin'
where lower(email) = lower('you@example.com');
```

لا يوجد بريد مشرف ثابت داخل الكود أو قاعدة البيانات. صلاحية لوحة المشرف تعتمد على `role=admin` وعلى كون البريد مؤكدًا، لذلك لا يكفي ادعاء المستخدم داخل المحادثة.

## متغيرات البيئة

انسخ `.env.example` إلى `.env` واملأ `SUPABASE_URL` و`SUPABASE_ANON_KEY` و`SUPABASE_SERVICE_KEY` و`ANTHROPIC_API_KEY`. مفتاح `SUPABASE_SERVICE_KEY` سر خادمي لا يصل إلى المتصفح ولا يجب نشره. غيّر `TOP_MODEL` و`FALLBACK_MODEL` إلى أسماء نماذج متاحة فعلًا في حساب مزودك، ويمكن تعديل نموذج الباقة من لوحة المشرف.

إعدادات الدفع اختيارية. الدفع اليدوي يعرض `MANUAL_PAY_NOTE` و`VCASH_NUMBER`، بينما `PAYMENT_URL_TEMPLATE` يفتح صفحة البوابة. يمكن للبوابة استدعاء:

```text
POST https://your-domain.example/api/webhook/payment
X-Signature: HMAC-SHA256(raw-body, PAYMENT_WEBHOOK_SECRET)
{"payment_id":"...","status":"paid"}
```

## لوحة المشرف

بعد تسجيل دخول المشرف افتح `/admin.html`. من اللوحة يمكن تعديل شخصية المساعد وتعليمات الأسلوب، تشغيل وضع الصيانة، تغيير الباقات والحدود والأسعار والنماذج، إدارة المستخدمين والحظر والترقية، تأكيد الدفع اليدوي، رفع كتب PDF/TXT/MD وفهرستها، ونشر إعلان للمستخدمين.

يمكن للمشرف تخصيص شخصية KIRA، لكن التعليمات الأساسية تمنع اختلاق هوية مطور أو ادعاء معلومة غير مؤكدة. لا يمكن إعداد المساعد ليقدم إجابة مضللة عن مطوره على أنها حقيقة؛ يمكن بدلًا من ذلك ضبط رد مهني شفاف مثل عدم مشاركة تفاصيل البنية الداخلية.

## النشر على Render

1. أنشئ مستودع GitHub خاصًا وارفع محتويات مجلد `kira` فقط.
2. في Render اختر **New → Blueprint** واربط المستودع؛ سيقرأ `render.yaml` ويستخدم أمر التشغيل الموجود فيه.
3. أضف القيم السرية المطلوبة في Environment Variables داخل Render. لا تضعها في `render.yaml` نفسه.
4. بعد النشر، ضع رابط Render في Supabase Authentication URL Configuration.
5. افتح `/api/health` وتأكد من أن `ok` تساوي `true`، ثم اختبر إنشاء حساب وتسجيل الدخول وفتح `/admin.html` بحساب المشرف.

الخدمة لا تحتاج إلى إعداد منفصل للهاتف: المتصفح المتجاوب يعمل على Android وiPhone والكمبيوتر. للحصول على تطبيق متجر أصلي، يلزم مشروع Mobile منفصل؛ هذا المستودع هو Web App responsive.

## GitHub بأمان

قبل الرفع تأكد من أن `.env` و`.venv` و`__pycache__` غير متتبعة:

```bash
git init
git add .
git status
git commit -m "Prepare KIRA AI for production"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/kira-ai.git
git push -u origin main
```

إذا لم يكن GitHub connector مفعّلًا في Manus، أنشئ المستودع أو فعّل الموصل من إعدادات التكامل ثم نفذ الدفع من بيئتك. لا ترسل رموز الوصول أو مفاتيح Supabase داخل المحادثة.

## الاختبارات

```bash
python -m py_compile main.py
python -m pytest -q
```

اختبارات المشروع لا تتصل بقاعدة الإنتاج ولا تعدل بيانات المستخدمين. قبل التشغيل الفعلي راجع إعدادات حدود الاستخدام، أسماء النماذج المتاحة، وسياسة الاحتفاظ بسجل المحادثات الخاصة بمستخدميك.
