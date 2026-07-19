# Wall Dash

দুই খেলোয়াড়ের সহজ Quoridor-স্টাইল বোর্ড গেম — Flutter দিয়ে বানানো।

## রুলস

- 9x9 গ্রিড, দুই খেলোয়াড় বিপরীত পাশ থেকে শুরু করে (নীল উপর থেকে, লাল নিচ থেকে)
- **লক্ষ্য**: নিজের বল অপর পাশে (বিপক্ষের শুরুর সারিতে) নিয়ে গেলে জয়
- **প্রতি চালে একটাই কাজ করা যাবে**:
  - বল এক ঘর সরানো (উপর/নিচ/ডান/বাম), অথবা বিপক্ষের বল সংলগ্ন থাকলে জাম্প করা
  - অথবা একটা wall বসানো (Unlimited সংখ্যক, প্রতিটা wall ২ ঘর লম্বা)
- Wall এমনভাবে বসানো যাবে না যাতে কোনো খেলোয়াড়ের জন্য পথ সম্পূর্ণ বন্ধ হয়ে যায় (স্বয়ংক্রিয়ভাবে BFS দিয়ে চেক হয়)

## চালানোর নিয়ম (Termux/mobile workflow)

```bash
flutter pub get
flutter run
```

## GitHub-এ push করে APK বানানো (recommended for phone install)

এই প্রজেক্টে `.github/workflows/build.yml` আছে — GitHub-এ push করলেই automatic APK build হয়ে যাবে (আপনার ফোনে Android SDK লাগবে না)।

```bash
cd wall_dash
git init
git add .
git commit -m "Initial commit: Wall Dash game"
git branch -M main
git remote add origin https://github.com/<your-username>/wall_dash.git
git push -u origin main
```

তারপর:
1. GitHub repo-তে যান → **Actions** ট্যাব
2. "Build APK" workflow রান হচ্ছে দেখবেন (২-৪ মিনিট লাগে)
3. রান শেষ হলে সেটার ভেতরে **Artifacts** সেকশনে `wall-dash-apk` নামে zip পাবেন
4. ডাউনলোড করে ফোনে extract করে `app-release.apk` install করুন (Unknown sources enable করা লাগতে পারে)

> এই APK debug key দিয়ে সাইন করা (CI-তে সহজে build করার জন্য) — নিজের ফোনে টেস্ট করার জন্য পুরোপুরি ঠিক আছে, কিন্তু Play Store-এ publish করতে চাইলে আলাদা release signing key লাগবে।

## Vercel-এ web version deploy করা (ঐচ্ছিক, ব্রাউজারে খেলার জন্য)

```bash
flutter build web
```

এটা `build/web` ফোল্ডারে static site বানাবে। Vercel-এ new project import করার সময় **Build Command** ও **Output Directory** ম্যানুয়ালি সেট করতে হবে যেহেতু এটা Next.js না:
- Build Command: (খালি রাখুন বা `echo skip`, কারণ build GitHub Actions-এ আলাদাভাবে করাই ভালো)
- Output Directory: `build/web`

সহজ উপায়: GitHub Actions-এ আরেকটা step যোগ করে `build/web` কে একটা আলাদা branch/artifact হিসেবে push করে সেটা Vercel দিয়ে deploy করা। প্রয়োজন হলে বলুন, এই workflow-ও বানিয়ে দেবো।

## ফাইল স্ট্রাকচার

```
lib/
  main.dart          -> App entry point
  home_screen.dart    -> মোড সিলেকশন (2P / vs AI)
  game_screen.dart    -> মূল গেম স্ক্রিন, turn management
  board_widget.dart   -> CustomPainter দিয়ে বোর্ড আঁকা + tap handling
  game_logic.dart     -> কোর রুলস: move validation, wall validation, BFS pathfinding
  ai_player.dart      -> সিম্পল heuristic AI (BFS shortest path + blocking wall)
```

## পরবর্তীতে যা যোগ করা যায়

- Wall সংখ্যা সীমিত করা (যেমন ১০টা করে) — `game_logic.dart`-এ `p1WallsPlaced`/`p2WallsPlaced` চেক যোগ করলেই হবে
- AI-কে আরও শক্তিশালী করা (minimax/alpha-beta)
- Online multiplayer (Firebase Firestore দিয়ে, যেহেতু আগের প্রজেক্টগুলোতে Firebase ব্যবহার হয়েছে)
- Undo বাটন
- Sound effects এবং animations
