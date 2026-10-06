# Flutter Web ERP — MVP

## فكرة المشروع

أريد بناء نظام **ERP MVP باستخدام Flutter Web**.

هذا المشروع سيكون نسخة أولية تعمل **Local فقط**، بدون Backend أو Cloud Database في المرحلة الحالية.

الهدف هو بناء ERP عملي وقابل للتطوير لاحقًا.

النظام يجب أن يكون مناسبًا للاستخدام على **Desktop/Web**، وليس مجرد Mobile App يعمل على المتصفح.

---

## قاعدة البيانات

استخدم قاعدة بيانات Local تعمل داخل Flutter Web وتشبه تجربة SQLite / sqflite في Flutter Android.

استخدم:

```yaml
sqflite_common_ffi_web: ^1.2.0
```

ويجب تجهيزها باستخدام:

```bash
dart run sqflite_common_ffi_web:setup
```

قاعدة البيانات في هذه المرحلة Local داخل المتصفح.

**لا تستخدم Firebase أو Supabase أو REST API أو أي Backend حاليًا.**

يجب أن تبقى البيانات موجودة بعد Browser Refresh.

---

# مراحل المشروع

## Phase 0 — Foundation

تجهيز مشروع Flutter Web والـERP الأساسي.

يشمل:

* إعداد المشروع.
* التصميم الأساسي.
* Theme.
* Navigation.
* Responsive Desktop/Web layout.
* Local SQLite database.
* التجهيز الأساسي للـERP.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 1 — Authentication

إنشاء نظام تسجيل الدخول للـMVP.

يشمل:

* Login.
* Logout.
* Local users.
* Session persistence.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 2 — Roles & Permissions

إضافة نظام المستخدمين والصلاحيات.

يشمل Roles مثل:

* Admin.
* Manager.
* Sales.
* Inventory.

والصلاحيات المناسبة لكل Role.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 3 — Inventory

إنشاء نظام المخزون.

يشمل:

* Products.
* Categories.
* Units.
* Stock.
* Stock adjustments.
* Inventory movements.
* Search.
* Filtering.
* Sorting.
* Pagination.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 4 — Sales

إنشاء نظام المبيعات.

يشمل:

* Customers.
* Sales.
* Products داخل الفاتورة.
* Quantities.
* Prices.
* Discounts.
* Totals.
* Sale status.
* Cancellation.
* تحديث المخزون بعد البيع.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 5 — Purchases

إنشاء نظام المشتريات.

يشمل:

* Suppliers.
* Purchases.
* Products داخل المشتريات.
* Quantities.
* Costs.
* Discounts.
* Totals.
* Purchase status.
* Cancellation.
* تحديث المخزون بعد الشراء.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 6 — Dashboard & Reports

إنشاء Dashboard وتقارير تعتمد على البيانات الحقيقية من النظام.

يشمل:

* Sales statistics.
* Purchases statistics.
* Inventory statistics.
* Low-stock products.
* Recent transactions.
* Basic reports.
* Filters حسب الحاجة.

لا تستخدم بيانات وهمية في الـDashboard.

بعد الانتهاء **توقف وانتظر موافقتي**.

---

## Phase 7 — Improvements 

مرحلة اختيارية للتحسينات النهائية.

يمكن أن تشمل:

* تحسين UX.
* تحسين الأداء.
* Advanced reports.
* Export.
* Notifications.




بعد كل Improvement **توقف وانتظر موافقتي**.

---

# قاعدة العمل الأساسية

**نفّذ Phase واحدة فقط في كل مرة.**

بعد إنهاء الـPhase:

* اختبرها.
* تأكد أنها تعمل.
* تأكد أن المراحل السابقة ما زالت تعمل.
* أخبرني باختصار بما تم.
* أعطني خطوات بسيطة لتجربتها.
* **توقف.**

لا تنتقل إلى Phase جديدة إلا بعد أن أطلب منك ذلك صراحة.

# الهدف النهائي

بناء **ERP MVP حقيقي باستخدام Flutter Web + Local SQLite**، يبدأ بسيطًا وقابلًا للتطوير لاحقًا إلى نظام كامل بقاعدة بيانات وBackend عند الحاجة.
