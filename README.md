# Notepad for Mac

עורך טקסט פשוט בסגנון Notepad של Windows 11, כתוב ב-Swift/AppKit נייטיבי (ללא Electron, ללא תלויות), עם טאבים אמיתיים של macOS.

## בנייה

דרוש Xcode או Command Line Tools (`xcode-select --install`), macOS 12 ומעלה.

```bash
cd Notepad
chmod +x build.sh
./build.sh            # יוצר build/Notepad.app
./build.sh --install  # וגם מעתיק ל-/Applications
```

בפעם הראשונה macOS עשוי לחסום את האפליקציה (חתימה מקומית בלבד): קליק ימני על האפליקציה ← Open.

## מה יש

| | |
|---|---|
| **טאבים** | ⌘N / ⌘T טאב חדש, כפתור ＋ בסרגל הטאבים, ⇧⌘N חלון חדש, גרירת טאבים בין חלונות, ⌃⇥ / ⌥⌘→ מעבר בין טאבים, ⌘1–⌘9, Merge All Windows, ⌘W סגירת טאב, ⇧⌘W סגירת חלון |
| **קובץ** | פתיחה, שמירה, Save As, Save All (⌥⌘S), Open Recent, Revert, הדפסה ו-Page Setup |
| **עריכה** | Undo/Redo, Find (⌘F), Replace (⌥⌘F), Find Next/Previous (⌘G / ⇧⌘G), Go To Line (⌘L), Time/Date (F5) |
| **פורמט** | Word Wrap, בחירת גופן (⌃⌘T), כיוון ימין-לשמאל (⌃⌘R) |
| **תצוגה** | זום (⌘+ / ⌘− / ⌘0), שורת מצב, מסך מלא |
| **שורת מצב** | `Ln, Col` · מספר תווים · זום · סוג שורה (CRLF/LF/CR) · קידוד — אפשר לשנות את שני האחרונים בלחיצה |
| **קידודים** | זיהוי אוטומטי של UTF-8 / UTF-8 BOM / UTF-16 LE/BE, וקבצי ANSI ישנים (Windows-1255 עברית / Windows-1252). File ▸ Reopen with Encoding לפתיחה מחדש בקידוד אחר |

מצב כהה, עברית ו-RTL, גלגלת/טרקפד ושחזור חלונות אחרי הפעלה מחדש — עובדים דרך המערכת.

## קיצורי ניווט ובחירה בסגנון Windows (גרסה 1.1)

פעילים כברירת מחדל. אפשר לכבות ב‑Edit ▸ Windows Navigation Keys. בכל אחד מהם Shift מוסיף בחירה.

| מקש | פעולה |
|---|---|
| Home / End | תחילת / סוף שורה |
| Ctrl+Home / Ctrl+End (גם ⌘) | תחילת / סוף המסמך |
| Ctrl+← / Ctrl+→ | מילה קודמת / הבאה (לפי Windows: לתחילת המילה הבאה; בפסקה בעברית החיצים מתהפכים) |
| Page Up / Page Down | העברת הסמן עמוד למעלה / למטה |
| Ctrl+Backspace / Ctrl+Delete | מחיקת מילה קודמת / הבאה |
| Ctrl+A | בחירת הכול |

במקלדת Mac: ‏fn+← = Home, ‏fn+→ = End, ‏fn+↑ = Page Up, ‏fn+↓ = Page Down. גם קיצורי ה‑Mac הרגילים ממשיכים לעבוד.

**חשוב:** macOS תופס כברירת מחדל את Ctrl+← / Ctrl+→ למעבר בין שולחנות עבודה. כדי שהם יגיעו לאפליקציה צריך לכבות ב‑System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Mission Control את ‎“Move left a space” ו‑“Move right a space”.

## מבנה

```
Sources/
  main.swift                   נקודת כניסה
  AppDelegate.swift            הגדרות גלובליות ופעולות ברמת האפליקציה
  MainMenu.swift               סרגל התפריטים
  Document.swift               NSDocument – קריאה/כתיבה/הדפסה, טאב אחד לכל מסמך
  EditorWindowController.swift חלון/טאב: NSTextView, זום, Go To, RTL
  EditorTextView.swift         קיצורי ניווט ובחירה בסגנון Windows
  StatusBarView.swift          שורת המצב
  TextFormat.swift             קידודים וסוגי שורות
Tools/make_icon.swift          מצייר את האייקון בזמן הבנייה
```
