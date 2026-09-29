<div align="center">

# 🧼 سجاد تك | SajjadTech

**نظام إداري، مالي، وتشغيلي متكامل ومخصص لمغاسل السجاد والمفروشات**  
*Integrated ERP & POS Solution for Carpet & Furniture Laundries*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Drift](https://img.shields.io/badge/Database-Drift%20%2F%20SQLite-00599C?logo=sqlite&logoColor=white)](https://drift.simonbinder.eu/)
[![Firebase](https://img.shields.io/badge/Cloud-Firebase%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-green.svg)](#)

---

</div>

## 📖 نبذة عن المشروع (Overview)

**سجاد تك (SajjadTech)** هو تطبيق حديث تم بناؤه باستخدام **Flutter** بهيكلية متقدمة تجمع بين الأداء العالي ومبدأ **العمل بدون إنترنت أولاً (Offline-First)**، حيث يتيح لأصحاب وموظفي مغاسل السجاد إدارة جميع العمليات اليومية بكفاءة فائقة (فواتير، عملاء، أسعار، حالات الغسيل، ديون، تقارير، ورسائل تواصل عبر واتساب) حتى في حال انقطاع شبكة الإنترنت تماماً، مع المزامنة التلقائية الثنائية مع السحابة فور عودة الاتصال.

---

## ✨ المميزات الرئيسية (Key Features)

### 1. ⚡ العمل بدون اتصال والمزامنة السحابية (Offline-First & Cloud Sync)
* **قاعدة بيانات محلية سريعة:** استخدام مكتبة `Drift (SQLite)` لضمان استمرارية العمل وتسجيل الفواتير بدون توقف.
* **مزامنة ذكية ثنائية الاتجاه:** مزامنة تلقائية مع `Cloud Firestore` لحفظ نسخة احتياطية سحابية لجميع الفواتير والعملاء وتفاصيل الأصناف.

### 2. 📋 دورة حياة الفواتير والطلبات (Order Workflow)
* **حساب الأسعار التلقائي والمرن:** دعم تسعير السجاد بالحبة أو بالمتر المربع (مع حساب الطول × العرض والمساحة تلقائياً).
* **تتبع دقيق لمراحل العمل:**
  * 📥 **مستلم (Received):** استلام السجاد، توثيق المقاسات، والمدفوع مقدماً.
  * ✨ **جاهز للاستلام (Ready):** إشعار العميل بانتهاء الغسيل والتجفيف والتغليف.
  * 🚚 **تم التسليم والتحصيل (Delivered):** تسليم السجاد وتصفية الحساب أو ترحيله كدين.
* **تنبيهات المواعيد العاجلة:** شريط ذكي في شاشة الطلبات يفرز الفواتير الحرجة والقريبة من موعد التسليم لتجنب التأخير.

### 3. 💵 الإدارة المالية والديون (Debt & Flexible Payments)
* **التسليم بالآجل:** إمكانية تسليم السجاد للزبون مع تسجيل المبلغ المتبقي كدين معلق على حسابه.
* **السداد الجزئي الذكي:** نافذة تفاعلية تتيح دفع أي جزء من المبلغ المتبقي أو تسديده كاملاً بضغطة زر وتحديث الرصيد فوراً.

### 4. 💬 إشعارات الواتساب التلقائية (WhatsApp Integration)
* إرسال رسائل آلية مصاغة باحترافية باللغة العربية إلى واتساب العميل عند:
  * تأكيد الاستلام وتفاصيل الفاتورة.
  * إشعار جاهزية السجاد للاستلام.
  * إشعار التسليم وتوضيح أي مبالغ متبقية عليه.

### 5. 📊 التقارير والإحصائيات والطباعة (Reports & PDF)
* لوحة تحكم تفاعلية توضح الدخل النقدي اليومي، الطلبات النشطة، وإحصائيات العمل.
* تصدير وطباعة تقارير وفواتير بصيغة **PDF** بتنسيق عربي كامل واتجاه من اليمين لليسار (RTL).

### 6. 🔒 نظام حصر الحساب بجهاز واحد (Single-Device Session Lock)
* حظر تسجيل الدخول المتزامن من أكثر من جهاز لنفس المغسلة عبر بصمة المعرّف الفريد للجهاز (`Device Session UUID`).
* حماية الاشتراكات ومنع مشاركة الحساب بين عدة فروع دون ترخيص مستقل.

---

## 🏗️ الهيكلية البرمجية (Architecture & Tech Stack)

تم بناء التطبيق باتباع نمط **MVVM (Model-View-ViewModel)** لتنظيم الأكواد وفصل واجهات المستخدم عن المنطق التجاري:

```
lib/
├── core/
│   ├── database/          # Drift / SQLite Database & Migrations
│   ├── services/          # Firebase, SyncService, WhatsAppService
│   ├── theme/             # App Colors, Styles, Typography
│   └── widgets/           # Global reusable widgets (Drawer, Nav, Banners)
│
├── features/
│   ├── auth/              # تسجيل الدخول، الجلسات، وحصر الأجهزة
│   ├── carpet_types/      # تسعير السجاد (بالمتر والحبة)
│   ├── customers/         # إدارة سجل العملاء وأرقام الهواتف
│   ├── dashboard/         # لوحة التحكم والإحصائيات السريعة
│   ├── orders/            # إدارة الفواتير، تفاصيل القطع، وتتبع الحالات
│   └── reports/           # التقارير المالية والطباعة
│
├── firebase_options.dart  # إعدادات الفايربيس
└── main.dart              # نقطة انطلاق التطبيق
```

### 🛠️ التقنيات والمكتبات المستخدمة:
* **Framework:** [Flutter](https://flutter.dev) (Dart SDK ^3.x)
* **State Management:** [Provider](https://pub.dev/packages/provider)
* **Local Database:** [Drift](https://pub.dev/packages/drift) (SQLite3 Engine)
* **Cloud & Auth:** [Firebase Auth](https://pub.dev/packages/firebase_auth) & [Cloud Firestore](https://pub.dev/packages/cloud_firestore)
* **Printing & PDF:** [pdf](https://pub.dev/packages/pdf) & [printing](https://pub.dev/packages/printing)
* **UI & Typography:** [Google Fonts (Cairo)](https://pub.dev/packages/google_fonts)
* **Local Storage:** [shared_preferences](https://pub.dev/packages/shared_preferences)
* **Deep Linking / URLs:** [url_launcher](https://pub.dev/packages/url_launcher)

---

## 🚀 كيفية التثبيت والتشغيل (Getting Started)

### المتطلبات المسبقة (Prerequisites):
* تثبيت [Flutter SDK](https://docs.flutter.dev/get-started/install) (الإصدار 3.10 أو أحدث).
* تثبيت بيئة التطوير (Android Studio أو VS Code).
* تهيئة حساب [Firebase Console](https://console.firebase.google.com/) للمشروع.

### خطوات التثبيت:

1. **استنساخ المستودع (Clone the repository):**
   ```bash
   git clone https://github.com/Mhmdbnhmzah/SajjadTech.git
   cd SajjadTech
   ```

2. **تثبيت الحزم والمكتبات (Get Dependencies):**
   ```bash
   flutter pub get
   ```

3. **توليد ملفات قاعدة البيانات ومساعدات الكود (Code Generation):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **تشغيل التطبيق في وضع التطوير (Run Debug):**
   ```bash
   flutter run
   ```

---

## 📦 بناء النسخة النهائية للإنتاج (Production Build)

* **بناء ملف تثبيت أندرويد (Release APK):**
  ```bash
  flutter build apk --release
  ```
  *المسار الناتج:* `build/app/outputs/flutter-apk/app-release.apk`

* **بناء حزمة متجر جوجل بلاي (App Bundle):**
  ```bash
  flutter build appbundle --release
  ```
  *المسار الناتج:* `build/app/outputs/bundle/release/app-release.aab`

---

## 📄 الترخيص (License)
جميع الحقوق محفوظة © 2026 لصالح مشروع **سجاد تك (SajjadTech)**.  
*All rights reserved.*
