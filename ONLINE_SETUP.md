# অনলাইন মাল্টিপ্লেয়ার সেটআপ

কোড রেডি, কিন্তু চালু করার আগে এই ৪টা ধাপ লাগবে।

## ১. FlutterFire CLI দিয়ে আসল config জেনারেট করুন

`lib/firebase_options.dart` এখন placeholder — এটা আসল ফাইল দিয়ে replace করতে হবে।
আপনার লোকাল মেশিনে (যেখানে flutter/dart ইনস্টল আছে):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

এটা চালালে আপনার existing Firebase project বেছে নিতে বলবে, তারপর Android/iOS/Web
এর জন্য `lib/firebase_options.dart` এবং `android/app/google-services.json` (ও দরকার
হলে iOS ফাইল) নিজে থেকেই বসিয়ে দেবে। এই কমান্ড লোকালি চালিয়ে জেনারেট হওয়া
ফাইলগুলো GitHub-এ commit করে দিন।

## ২. Firebase Console-এ Anonymous Auth চালু করুন

Firebase Console → আপনার প্রজেক্ট → Authentication → Sign-in method →
**Anonymous** টগল অন করুন।

## ৩. Firestore Database চালু করুন (যদি আগে না করা থাকে)

Firebase Console → Firestore Database → Create database (production mode)।

## ৪. Security Rules পাবলিশ করুন

এই রিপোর মধ্যেই `firestore.rules` ফাইল আছে। Firebase Console → Firestore →
Rules ট্যাবে গিয়ে এই ফাইলের কনটেন্ট পেস্ট করে Publish করুন। এটা ছাড়া
matchmaking/room লেখাই কাজ করবে না (permission denied)।

## ৫. Composite index (প্রথমবার Quick Match চালালে লাগবে)

`matchmaking_queue` কালেকশনে `status` (==) + `createdAt` (orderBy) দিয়ে
কুয়েরি হয়। প্রথমবার Quick Match ট্রাই করলে Firestore একটা error দেবে যাতে
একটা লিংক থাকবে — সেই লিংকে ক্লিক করলেই index অটো তৈরি হয়ে যাবে
(কয়েক মিনিট লাগে বিল্ড হতে)। এটা এক-বারের কাজ।

---

উপরের ধাপগুলো শেষ হলে অ্যাপে "Play Online" থেকে Quick Match / Create Room /
Join with Code — তিনটাই কাজ করবে।
